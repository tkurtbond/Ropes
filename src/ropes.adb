with Ada.Strings;
with Ada.Unchecked_Deallocation;

package body Ropes is

   --  Rope.Mod's ShortLeafLength: Cat merges two flat leaves into one
   --  instead of adding a Concat node when their combined length is
   --  at most this. Tunable; not derived from anything but taste.
   Short_Leaf_Length : constant := 16;

   procedure Free_Node is new Ada.Unchecked_Deallocation (Node, Node_Access);

   ------------------------------------------------------------------
   --  Node-level reference counting.
   --
   --  This is plain, hand-rolled refcounting on Node.Ref_Count -- it
   --  does not go through Ada.Finalization at all (Node is not a
   --  controlled type; only the outer Rope_Ref is). The contract
   --  every node-constructing function below follows: a function that
   --  *returns* a Node_Access hands back one fresh owned reference
   --  (the returned node's Ref_Count already accounts for it); a
   --  Node_Access *parameter* is borrowed and must not be touched by
   --  the callee unless it explicitly takes ownership (documented at
   --  each call site below, e.g. New_Concat's Incr_Ref of its own
   --  Left/Right).
   ------------------------------------------------------------------

   procedure Incr_Ref (N : Node_Access) is
   begin
      if N /= null then
         N.Ref_Count := N.Ref_Count + 1;
      end if;
   end Incr_Ref;

   --  Decrements N's reference count, recursively freeing it (and, on
   --  a Concat node, dropping its own references to Left/Right in
   --  turn) once the count reaches 0. N is always set to null before
   --  the possible free, not after, so a second call on an
   --  already-decremented handle -- e.g. Rope_Ref.Finalize running
   --  twice on the same object, which the RM permits -- is a safe
   --  no-op rather than a double-decrement.
   procedure Decr_Ref (N : in out Node_Access) is
      Freed : Node_Access := N;
   begin
      if Freed = null then
         return;
      end if;
      N               := null;
      Freed.Ref_Count := Freed.Ref_Count - 1;
      if Freed.Ref_Count = 0 then
         case Freed.Kind is
            when Concat_Kind =>
               Decr_Ref (Freed.Left);
               Decr_Ref (Freed.Right);

            when Leaf_Kind =>
               null;
         end case;
         Free_Node (Freed);
      end if;
   end Decr_Ref;

   overriding procedure Adjust (R : in out Rope_Ref) is
   begin
      Incr_Ref (R.Data);
   end Adjust;

   overriding procedure Finalize (R : in out Rope_Ref) is
   begin
      Decr_Ref (R.Data);
   end Finalize;

   ------------------------------------------------------------------
   --  Node construction.
   ------------------------------------------------------------------

   function Data_Of (Source : Rope) return Node_Access is (Source.Ref.Data);

   --  The one place a freshly-owned Node_Access becomes a Rope value,
   --  via a direct aggregate (not a copy of an intermediate Rope
   --  object) so that no extra Adjust fires beyond what Data's own
   --  Ref_Count already accounts for -- same pattern, same reasoning,
   --  as alibfyaml's own Libfyaml.Nodes.Wrap (see PLAN.md).
   function Wrap (Data : Node_Access) return Rope is (Ref => (Ada.Finalization.Controlled with Data => Data));

   --  Precondition: S'Length > 0 (every call site below guards this).
   function New_Leaf (S : String) return Node_Access is
      Result : Node_Access;
   begin
      Result       := new Node (Kind => Leaf_Kind, Len => S'Length);
      Result.Chars := S;
      return Result;
   end New_Leaf;

   --  Left and Right must both be non-null. Takes its own reference
   --  to each (Incr_Ref) -- the caller's own references, if any, are
   --  untouched. Raises Ada.Strings.Length_Error instead of silently
   --  wrapping on overflow, unlike Rope.Mod's AddLen, which HALTs
   --  because voc's LONGINT wraps silently and Ada's does not need
   --  the same workaround -- see PLAN.md.
   function New_Concat (Left, Right : Node_Access) return Node_Access is
      Result : Node_Access;
   begin
      if Left.Len > Positive'Last - Right.Len then
         raise Ada.Strings.Length_Error;
      end if;
      Result       := new Node (Kind => Concat_Kind, Len => Left.Len + Right.Len);
      Result.Depth := Natural'Max (Left.Depth, Right.Depth) + 1;
      Result.Left  := Left;
      Result.Right := Right;
      Incr_Ref (Left);
      Incr_Ref (Right);
      return Result;
   end New_Concat;

   --  Plain concatenation: the short-leaf merge special cases from
   --  the paper (Rope.Mod's SimpleCat), with no depth check and no
   --  rebalancing -- that is Phase 2's job, layered on top of this.
   --  Left and Right are borrowed; the result is a fresh owned
   --  reference.
   function New_Simple_Cat (Left, Right : Node_Access) return Node_Access is
   begin
      if Left = null then
         Incr_Ref (Right);
         return Right;
      end if;
      if Right = null then
         Incr_Ref (Left);
         return Left;
      end if;

      if Left.Kind = Leaf_Kind and then Right.Kind = Leaf_Kind and then Left.Len <= Short_Leaf_Length
        and then Right.Len <= Short_Leaf_Length and then Left.Len + Right.Len <= Short_Leaf_Length
      then
         return New_Leaf (Left.Chars & Right.Chars);
      end if;

      if Left.Kind = Concat_Kind and then Right.Kind = Leaf_Kind and then Left.Right.Kind = Leaf_Kind
        and then Left.Right.Len <= Short_Leaf_Length and then Right.Len <= Short_Leaf_Length
        and then Left.Right.Len + Right.Len <= Short_Leaf_Length
      then
         declare
            Merged : Node_Access := New_Leaf (Left.Right.Chars & Right.Chars);
            Result : Node_Access;
         begin
            Result := New_Concat (Left.Left, Merged);
            Decr_Ref (Merged);  --  New_Concat took its own reference to Merged.
            return Result;
         end;
      end if;

      return New_Concat (Left, Right);
   end New_Simple_Cat;

   ------------------------------------------------------------------
   --  Balancing: Rope.Mod's Fibonacci-forest rebalance (itself ported
   --  from cord's cordbscs.c), triggered from "&" whenever a
   --  concatenation's result gets too deep. See PLAN.md's "Balancing"
   --  section. Every Node_Access parameter below follows the same
   --  borrowed/owned contract documented at the top of this file.
   ------------------------------------------------------------------

   --  Grows the same Fibonacci-like sequence as Min_Length below (A =
   --  Min_Length (D - 1), B = Min_Length (D)) until the next term
   --  would exceed Natural'Last, and returns the last index
   --  successfully computed -- Rope.Mod's InitMinLength/MaxDepth, but
   --  sized to Standard.Natural's actual range instead of a hardcoded
   --  44 assuming a 32-bit LONGINT.
   function Compute_Max_Depth return Natural is
      A : Natural := 1;  --  Min_Length (0)
      B : Natural := 2;  --  Min_Length (1)
      D : Natural := 1;
   begin
      loop
         exit when A > Natural'Last - B;  --  A + B would overflow
         declare
            Next : constant Natural := A + B;
         begin
            A := B;
            B := Next;
            D := D + 1;
         end;
      end loop;
      return D;
   end Compute_Max_Depth;

   Max_Depth : constant Natural := Compute_Max_Depth;

   subtype Depth_Range is Natural range 0 .. Max_Depth;
   type Min_Length_Array is array (Depth_Range) of Positive;
   type Node_Array is array (Depth_Range) of Node_Access;
   type Length_Array is array (Depth_Range) of Natural;

   --  Min_Length (D) is the least total length a rope balanced (per
   --  the paper's definition: Length (R) >= Min_Length (Depth (R)))
   --  at depth D may have.
   function Compute_Min_Length return Min_Length_Array is
      Result : Min_Length_Array;
   begin
      Result (0) := 1;
      Result (1) := 2;  --  Max_Depth >= 1 always -- see Compute_Max_Depth.
      for D in 2 .. Max_Depth loop
         Result (D) := Result (D - 1) + Result (D - 2);
      end loop;
      return Result;
   end Compute_Min_Length;

   Min_Length : constant Min_Length_Array := Compute_Min_Length;

   --  Inserts the leaf or already-balanced subtree X (of known length
   --  X_Len) into Forest, maintaining the invariant that Forest (I),
   --  if not null, has depth <= I and length >= Min_Length (I), and
   --  that concatenating the occupied slots (see Concat_Forest)
   --  reproduces what has been inserted so far, left to right. X is
   --  borrowed.
   procedure Balance_Insert (X : Node_Access; X_Len : Positive; Forest : in out Node_Array; Forest_Len : in out Length_Array) is
      I       : Natural     := 0;
      Sum     : Node_Access := null;
      Sum_Len : Natural     := 0;

      --  Folds Forest slot Slot (of known length Slot_Len) into Sum,
      --  then clears the slot -- Slot's ownership moves into Sum (or
      --  is dropped, if New_Simple_Cat only needed to read it).
      procedure Absorb (Slot : in out Node_Access; Slot_Len : Natural) is
         New_Sum : constant Node_Access := New_Simple_Cat (Slot, Sum);
      begin
         Decr_Ref (Sum);
         Decr_Ref (Slot);
         Slot    := null;
         Sum     := New_Sum;
         Sum_Len := Sum_Len + Slot_Len;
      end Absorb;
   begin
      while I < Max_Depth and then X_Len > Min_Length (I + 1) loop
         if Forest (I) /= null then
            Absorb (Forest (I), Forest_Len (I));
         end if;
         I := I + 1;
      end loop;

      declare
         New_Sum : constant Node_Access := New_Simple_Cat (Sum, X);
      begin
         Decr_Ref (Sum);
         Sum := New_Sum;
      end;
      Sum_Len := Sum_Len + X_Len;

      while I <= Max_Depth and then Sum_Len >= Min_Length (I) loop
         if Forest (I) /= null then
            Absorb (Forest (I), Forest_Len (I));
         end if;
         I := I + 1;
      end loop;

      --  I > 0 here: Sum_Len >= X_Len >= 1 = Min_Length (0), so the
      --  loop just above always runs at least once.
      I              := I - 1;
      Forest (I)     := Sum;
      Forest_Len (I) := Sum_Len;
   end Balance_Insert;

   --  Walks X left to right, inserting each leaf into Forest. A
   --  Concat node that is already balanced for its own depth is
   --  treated as atomic (inserted whole) instead of being torn apart;
   --  only genuinely unbalanced Concat nodes are recursed into. X is
   --  borrowed throughout.
   procedure Balance_Walk (X : Node_Access; Forest : in out Node_Array; Forest_Len : in out Length_Array) is
   begin
      if X = null then
         return;
      end if;
      if X.Kind = Concat_Kind and then not (X.Depth < Max_Depth and then X.Len >= Min_Length (X.Depth)) then
         Balance_Walk (X.Left, Forest, Forest_Len);
         Balance_Walk (X.Right, Forest, Forest_Len);
      else
         Balance_Insert (X, X.Len, Forest, Forest_Len);
      end if;
   end Balance_Walk;

   --  Reassembles Forest into one rope: slots low to high, each
   --  prepended to what has been assembled from the lower slots so
   --  far. Forest is left all-null; every slot's ownership is
   --  transferred into the returned tree (or dropped, by the interior
   --  Decr_Ref calls below).
   function Concat_Forest (Forest : in out Node_Array) return Node_Access is
      Result : Node_Access := null;
   begin
      for I in Forest'Range loop
         if Forest (I) /= null then
            declare
               New_Result : constant Node_Access := New_Simple_Cat (Forest (I), Result);
            begin
               Decr_Ref (Result);
               Decr_Ref (Forest (I));
               Forest (I) := null;
               Result     := New_Result;
            end;
         end if;
      end loop;
      return Result;
   end Concat_Forest;

   --  Rebalances X into a rope with the same content but Depth
   --  bounded well below Max_Depth. X is borrowed; the result is a
   --  fresh owned reference.
   function Balance (X : Node_Access) return Node_Access is
      Forest     : Node_Array   := [others => null];
      Forest_Len : Length_Array := [others => 0];
   begin
      if X = null then
         return null;
      end if;
      Balance_Walk (X, Forest, Forest_Len);
      return Concat_Forest (Forest);
   end Balance;

   ------------------------------------------------------------------
   --  Node-level helpers shared by several public operations below.
   ------------------------------------------------------------------

   --  N must be non-null and I in 1 .. N.Len.
   function Fetch (N : Node_Access; I : Positive) return Character is
   begin
      case N.Kind is
         when Leaf_Kind =>
            return N.Chars (I);

         when Concat_Kind =>
            if I <= N.Left.Len then
               return Fetch (N.Left, I);
            else
               return Fetch (N.Right, I - N.Left.Len);
            end if;
      end case;
   end Fetch;

   --  Rope.Mod's SubstrHelper: the (0-based) slice N (Start .. Start +
   --  Len - 1). Precondition: N /= null, Len > 0, Start + Len <=
   --  N.Len. N is borrowed; the result is a fresh owned reference --
   --  sharing N itself (via Incr_Ref, no copy) when the requested
   --  range is the whole of N, at any node kind (Rope.Mod only takes
   --  this shortcut for a Concat node, always copying a Leaf even for
   --  its own full range; sharing it too is a strict improvement, not
   --  a scope change, since a Rope leaf is just as immutable).
   function Node_Slice (N : Node_Access; Start, Len : Natural) return Node_Access is
   begin
      if Start = 0 and then Len = N.Len then
         Incr_Ref (N);
         return N;
      end if;
      case N.Kind is
         when Leaf_Kind =>
            return New_Leaf (N.Chars (N.Chars'First + Start .. N.Chars'First + Start + Len - 1));

         when Concat_Kind =>
            if Start >= N.Left.Len then
               return Node_Slice (N.Right, Start - N.Left.Len, Len);
            elsif Start + Len <= N.Left.Len then
               return Node_Slice (N.Left, Start, Len);
            else
               declare
                  Left_Part  : Node_Access          := Node_Slice (N.Left, Start, N.Left.Len - Start);
                  Right_Part : Node_Access          := Node_Slice (N.Right, 0, Start + Len - N.Left.Len);
                  Result     : constant Node_Access := New_Simple_Cat (Left_Part, Right_Part);
               begin
                  Decr_Ref (Left_Part);
                  Decr_Ref (Right_Part);
                  return Result;
               end;
            end if;
      end case;
   end Node_Slice;

   --  Rope.Mod's Compare: <0, 0 or >0, like strcmp -- lexicographic by
   --  character, then by length. Left and Right are borrowed
   --  (possibly null).
   function Compare (Left, Right : Node_Access) return Integer is
      L_Len : constant Natural := (if Left = null then 0 else Left.Len);
      R_Len : constant Natural := (if Right = null then 0 else Right.Len);
   begin
      for I in 1 .. Natural'Min (L_Len, R_Len) loop
         declare
            LC : constant Character := Fetch (Left, I);
            RC : constant Character := Fetch (Right, I);
         begin
            if LC /= RC then
               if LC < RC then
                  return -1;
               else
                  return 1;
               end if;
            end if;
         end;
      end loop;
      if L_Len = R_Len then
         return 0;
      elsif L_Len < R_Len then
         return -1;
      else
         return 1;
      end if;
   end Compare;

   ------------------------------------------------------------------
   --  Public API.
   ------------------------------------------------------------------

   function Length (Source : Rope) return Natural is
      D : constant Node_Access := Data_Of (Source);
   begin
      if D = null then
         return 0;
      end if;
      return D.Len;
   end Length;

   function Is_Empty (Source : Rope) return Boolean is (Data_Of (Source) = null);

   function "&" (Left, Right : Rope) return Rope is
      Result : Node_Access := New_Simple_Cat (Data_Of (Left), Data_Of (Right));
   begin
      if Result /= null and then Result.Depth >= Max_Depth then
         declare
            Balanced : constant Node_Access := Balance (Result);
         begin
            Decr_Ref (Result);
            Result := Balanced;
         end;
      end if;
      return Wrap (Result);
   end "&";

   function From_String (Source : String) return Rope is
   begin
      if Source'Length = 0 then
         return Null_Rope;
      end if;
      return Wrap (New_Leaf (Source));
   end From_String;

   function To_String (Source : Rope) return String is
      Result : String (1 .. Length (Source));
      Next   : Positive := 1;

      procedure Copy (N : Node_Access) is
      begin
         if N = null then
            return;
         end if;
         case N.Kind is
            when Leaf_Kind =>
               Result (Next .. Next + N.Len - 1) := N.Chars;
               Next                              := Next + N.Len;

            when Concat_Kind =>
               Copy (N.Left);
               Copy (N.Right);
         end case;
      end Copy;
   begin
      Copy (Data_Of (Source));
      return Result;
   end To_String;

   function Element (Source : Rope; Index : Positive) return Character is
      D : constant Node_Access := Data_Of (Source);
   begin
      if D = null or else Index > D.Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Fetch (D, Index);
   end Element;

   function Slice (Source : Rope; Low : Positive; High : Natural) return Rope is
      D   : constant Node_Access := Data_Of (Source);
      Len : constant Natural     := (if D = null then 0 else D.Len);
   begin
      if Low - 1 > Len or else High > Len then
         raise Ada.Strings.Index_Error;
      end if;
      if High < Low then
         return Null_Rope;
      end if;
      return Wrap (Node_Slice (D, Low - 1, High - Low + 1));
   end Slice;

   function Insert (Source : Rope; Before : Positive; New_Item : Rope) return Rope is
      Len : constant Natural := Length (Source);
   begin
      if Before - 1 > Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Slice (Source, 1, Before - 1) & New_Item & Slice (Source, Before, Len);
   end Insert;

   function Delete (Source : Rope; From : Positive; Through : Natural) return Rope is
      Len : constant Natural := Length (Source);
   begin
      if From > Through then
         return Source;
      end if;
      if From - 1 > Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Slice (Source, 1, From - 1) & Slice (Source, Natural'Min (Through, Len) + 1, Len);
   end Delete;

   function "=" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) = 0);

   function "<" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) < 0);

   function "<=" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) <= 0);

   function ">" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) > 0);

   function ">=" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) >= 0);

end Ropes;
