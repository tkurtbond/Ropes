with Ada.Characters.Handling;
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

   --  Rope.Mod's Iterator.Locate, minus its leaf-cache short-circuit
   --  (callers -- First/Next below -- check that themselves, since
   --  only they have the old Cursor's cache to check against): the
   --  leaf node covering the 1-based position I of the subtree rooted
   --  at N, and that leaf's own 1-based starting index within the
   --  *whole* rope N was originally called with (Base accumulates the
   --  count of characters skipped over so far, the same way Fetch's
   --  own descent skips N.Left.Len without tracking it). Precondition:
   --  N /= null, I in 1 .. N.Len.
   procedure Locate_Leaf (N : Node_Access; I : Positive; Base : Natural; Leaf : out Node_Access; Leaf_Start : out Positive) is
   begin
      case N.Kind is
         when Leaf_Kind =>
            Leaf       := N;
            Leaf_Start := Base + 1;

         when Concat_Kind =>
            if I <= N.Left.Len then
               Locate_Leaf (N.Left, I, Base, Leaf, Leaf_Start);
            else
               Locate_Leaf (N.Right, I - N.Left.Len, Base + N.Left.Len, Leaf, Leaf_Start);
            end if;
      end case;
   end Locate_Leaf;

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

   --  Copies N's characters Start + 1 .. Start + Len (a 0-based offset
   --  and a length, like Node_Slice's) into Target (T .. T + Len - 1),
   --  advancing T past them. Precondition: Len > 0 and Start + Len <=
   --  N.Len, and the target range lies within Target. Descends only into
   --  the subtrees overlapping the range and copies straight out of each
   --  leaf, so it is O(Len + depth), like Node_Slice but with no new
   --  nodes built -- Rope.Mod's BlitHelper.
   procedure Node_Copy (N : Node_Access; Start, Len : Natural; Target : in out String; T : in out Positive) is
   begin
      case N.Kind is
         when Leaf_Kind =>
            Target (T .. T + Len - 1) := N.Chars (N.Chars'First + Start .. N.Chars'First + Start + Len - 1);
            T                         := T + Len;

         when Concat_Kind =>
            if Start < N.Left.Len then
               declare
                  Left_Len : constant Natural := Natural'Min (N.Left.Len - Start, Len);
               begin
                  Node_Copy (N.Left, Start, Left_Len, Target, T);
                  if Len > Left_Len then
                     Node_Copy (N.Right, 0, Len - Left_Len, Target, T);
                  end if;
               end;
            else
               Node_Copy (N.Right, Start - N.Left.Len, Len, Target, T);
            end if;
      end case;
   end Node_Copy;

   --  A walk over a tree's leaves, one leaf per Next_Leaf call, in
   --  amortized O(1) per leaf: a pre-order walk with an explicit stack
   --  of subtrees still to visit. Left to right (Going => Forward:
   --  Right pushed before Left, so Left comes off first), or right to
   --  left (Backward: the mirror image). The stack holds at most one
   --  subtree per level below the root, plus one -- Depth + 1 entries
   --  -- and every concat node's Depth is set by New_Concat, so Size =>
   --  Root.Depth + 1 always suffices. A walk has a leaf left to return
   --  exactly when Top > 0 (every subtree on the stack is non-empty).
   type Node_Stack is array (Positive range <>) of Node_Access;

   type Leaf_Walk (Size : Positive) is record
      Stack : Node_Stack (1 .. Size);
      Top   : Natural               := 0;
      Going : Ada.Strings.Direction := Ada.Strings.Forward;
   end record;

   --  Starts a left-to-right walk over all of Root's leaves.
   procedure Start_Walk (W : in out Leaf_Walk; Root : Node_Access) is
   begin
      W.Stack (1) := Root;
      W.Top       := 1;
      W.Going     := Ada.Strings.Forward;
   end Start_Walk;

   --  Starts a walk in direction Going from the character at 1-based
   --  position Pos of Root: Leaf is the leaf holding it, at Leaf.Chars
   --  (Offset), and Next_Leaf then returns the leaves after (Forward)
   --  or before (Backward) Leaf, in order. One descent from the root,
   --  pushing the subtree on the far side of each step -- the right
   --  one when stepping left, going Forward, and the left one when
   --  stepping right, going Backward -- so O(depth), and within the
   --  same Depth + 1 bound. Precondition: Pos in 1 .. Root.Len.
   procedure Start_Walk_At
     (W      : in out Leaf_Walk; Root : Node_Access; Pos : Positive; Going : Ada.Strings.Direction; Leaf : out Node_Access;
      Offset :    out Positive)
   is
      use type Ada.Strings.Direction;
      N   : Node_Access := Root;
      Rel : Positive    := Pos;  --  Pos, relative to N.
   begin
      W.Top   := 0;
      W.Going := Going;
      while N.Kind = Concat_Kind loop
         if Rel <= N.Left.Len then
            if Going = Ada.Strings.Forward then
               W.Top           := W.Top + 1;
               W.Stack (W.Top) := N.Right;
            end if;
            N := N.Left;
         else
            if Going = Ada.Strings.Backward then
               W.Top           := W.Top + 1;
               W.Stack (W.Top) := N.Left;
            end if;
            Rel := Rel - N.Left.Len;
            N   := N.Right;
         end if;
      end loop;
      Leaf   := N;
      Offset := Rel;
   end Start_Walk_At;

   --  Precondition: the walk has a leaf left to return (W.Top > 0).
   procedure Next_Leaf (W : in out Leaf_Walk; Leaf : out Node_Access) is
      use type Ada.Strings.Direction;
      N : Node_Access;
   begin
      loop
         N     := W.Stack (W.Top);
         W.Top := W.Top - 1;
         exit when N.Kind = Leaf_Kind;
         if W.Going = Ada.Strings.Forward then
            W.Stack (W.Top + 1) := N.Right;
            W.Stack (W.Top + 2) := N.Left;
         else
            W.Stack (W.Top + 1) := N.Left;
            W.Stack (W.Top + 2) := N.Right;
         end if;
         W.Top := W.Top + 2;
      end loop;
      Leaf := N;
   end Next_Leaf;

   --  Rope.Mod's Compare: <0, 0 or >0, like strcmp -- lexicographic by
   --  character, then by length. Left and Right are borrowed
   --  (possibly null).
   --
   --  Linear in the common prefix (since Phase 11): walks both ropes'
   --  leaves in step, a run at a time, where a run is the longest
   --  stretch lying within one leaf of each, and compares each run as a
   --  single String slice (predefined String "=" and "<" are exactly
   --  this character-by-character lexicographic order) -- not a Fetch
   --  from the root per character, which was O(n log n). Identical
   --  trees (one rope copied from the other, sharing its root) compare
   --  equal in O(1).
   function Compare (Left, Right : Node_Access) return Integer is
      L_Len  : constant Natural := (if Left = null then 0 else Left.Len);
      R_Len  : constant Natural := (if Right = null then 0 else Right.Len);
      Common : constant Natural := Natural'Min (L_Len, R_Len);
   begin
      if Left = Right then
         return 0;
      end if;
      if Common > 0 then
         declare
            L_Walk         : Leaf_Walk (Left.Depth + 1);
            R_Walk         : Leaf_Walk (Right.Depth + 1);
            L_Leaf, R_Leaf : Node_Access;
            L_Pos, R_Pos   : Positive := 1;  --  Next character within each leaf.
            Remaining      : Natural  := Common;
         begin
            Start_Walk (L_Walk, Left);
            Start_Walk (R_Walk, Right);
            Next_Leaf (L_Walk, L_Leaf);
            Next_Leaf (R_Walk, R_Leaf);
            while Remaining > 0 loop
               if L_Pos > L_Leaf.Len then
                  Next_Leaf (L_Walk, L_Leaf);
                  L_Pos := 1;
               end if;
               if R_Pos > R_Leaf.Len then
                  Next_Leaf (R_Walk, R_Leaf);
                  R_Pos := 1;
               end if;
               declare
                  Run : constant Positive := Natural'Min (Natural'Min (L_Leaf.Len - L_Pos + 1, R_Leaf.Len - R_Pos + 1), Remaining);
                  L_Run : String renames L_Leaf.Chars (L_Pos .. L_Pos + Run - 1);
                  R_Run : String renames R_Leaf.Chars (R_Pos .. R_Pos + Run - 1);
               begin
                  if L_Run /= R_Run then
                     return (if L_Run < R_Run then -1 else 1);
                  end if;
                  L_Pos     := L_Pos + Run;
                  R_Pos     := R_Pos + Run;
                  Remaining := Remaining - Run;
               end;
            end loop;
         end;
      end if;
      if L_Len = R_Len then
         return 0;
      elsif L_Len < R_Len then
         return -1;
      else
         return 1;
      end if;
   end Compare;

   --  Compare above, with a String for Right: the same run-at-a-time
   --  walk, over Left's leaves only, each run compared with the next
   --  stretch of Right. Offset counts characters of Right already
   --  compared, rather than holding an index into Right, so that a
   --  Right ending at Positive'Last can't overflow it.
   function Compare (Left : Node_Access; Right : String) return Integer is
      L_Len  : constant Natural := (if Left = null then 0 else Left.Len);
      R_Len  : constant Natural := Right'Length;
      Common : constant Natural := Natural'Min (L_Len, R_Len);
   begin
      if Common > 0 then
         declare
            Walk   : Leaf_Walk (Left.Depth + 1);
            Leaf   : Node_Access;
            Offset : Natural := 0;
         begin
            Start_Walk (Walk, Left);
            while Offset < Common loop
               Next_Leaf (Walk, Leaf);
               declare
                  Run   : constant Positive := Natural'Min (Leaf.Len, Common - Offset);
                  L_Run : String renames Leaf.Chars (1 .. Run);
                  R_Run : String renames Right (Right'First + Offset .. Right'First + Offset + (Run - 1));
               begin
                  if L_Run /= R_Run then
                     return (if L_Run < R_Run then -1 else 1);
                  end if;
                  Offset := Offset + Run;
               end;
            end loop;
         end;
      end if;
      if L_Len = R_Len then
         return 0;
      elsif L_Len < R_Len then
         return -1;
      else
         return 1;
      end if;
   end Compare;

   --  Rope.Mod's MapHelper: N with Convert applied to every character,
   --  in increasing index order. Built via New_Concat directly, not
   --  New_Simple_Cat -- the result must have exactly N's own tree
   --  shape (same Depth, no rebalancing needed, per Map/Map_Indexed's
   --  own doc comment), which New_Simple_Cat's short-leaf merge would
   --  perturb. N is borrowed; the result is a fresh owned reference,
   --  or null if N is null.
   function Map_Node (N : Node_Access; Convert : not null access function (Ch : Character) return Character) return Node_Access is
   begin
      if N = null then
         return null;
      end if;
      case N.Kind is
         when Leaf_Kind =>
            declare
               Mapped : String (1 .. N.Len);
            begin
               for I in Mapped'Range loop
                  Mapped (I) := Convert (N.Chars (I));
               end loop;
               return New_Leaf (Mapped);
            end;

         when Concat_Kind =>
            declare
               Left   : Node_Access          := Map_Node (N.Left, Convert);
               Right  : Node_Access          := Map_Node (N.Right, Convert);
               Result : constant Node_Access := New_Concat (Left, Right);
            begin
               Decr_Ref (Left);
               Decr_Ref (Right);
               return Result;
            end;
      end case;
   end Map_Node;

   --  As Map_Node, but Convert is also passed each character's
   --  1-based index in the whole rope -- Rope.Mod's MapiHelper, with
   --  Next_Index threaded through the recursion in place of MapiHelper's
   --  VAR idx parameter (an in out parameter here for the same reason:
   --  it must keep counting across the boundary between N.Left and
   --  N.Right, not restart at each subtree).
   function Map_Indexed_Node
     (N          :        Node_Access; Convert : not null access function (Index : Positive; Ch : Character) return Character;
      Next_Index : in out Positive) return Node_Access
   is
   begin
      if N = null then
         return null;
      end if;
      case N.Kind is
         when Leaf_Kind =>
            declare
               Mapped : String (1 .. N.Len);
            begin
               for I in Mapped'Range loop
                  Mapped (I) := Convert (Next_Index, N.Chars (I));
                  Next_Index := Next_Index + 1;
               end loop;
               return New_Leaf (Mapped);
            end;

         when Concat_Kind =>
            declare
               Left   : Node_Access          := Map_Indexed_Node (N.Left, Convert, Next_Index);
               Right  : Node_Access          := Map_Indexed_Node (N.Right, Convert, Next_Index);
               Result : constant Node_Access := New_Concat (Left, Right);
            begin
               Decr_Ref (Left);
               Decr_Ref (Right);
               return Result;
            end;
      end case;
   end Map_Indexed_Node;

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

   function "&" (Left : Rope; Right : Character) return Rope is (Left & From_Character (Right));
   function "&" (Left : Character; Right : Rope) return Rope is (From_Character (Left) & Right);
   function "&" (Left : Rope; Right : String) return Rope is (Left & From_String (Right));
   function "&" (Left : String; Right : Rope) return Rope is (From_String (Left) & Right);

   function From_String (Source : String) return Rope is
   begin
      if Source'Length = 0 then
         return Null_Rope;
      end if;
      return Wrap (New_Leaf (Source));
   end From_String;

   function From_Character (Source : Character) return Rope is (Wrap (New_Leaf ([Source])));

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

   procedure Process_Chunks (Source : Rope; Process : not null access procedure (Chunk : String)) is
      --  Rope has a controlled part, so it is passed by reference (RM
      --  6.2): were Process to assign to the very variable passed as
      --  Source, the tree could be freed mid-walk. Holding our own
      --  reference for the duration pins it. O(1) -- a refcount bump.
      Hold : constant Rope := Source;

      procedure Walk (N : Node_Access) is
      begin
         if N = null then
            return;
         end if;
         case N.Kind is
            when Leaf_Kind =>
               Process (N.Chars);

            when Concat_Kind =>
               Walk (N.Left);
               Walk (N.Right);
         end case;
      end Walk;
   begin
      Walk (Data_Of (Hold));
   end Process_Chunks;

   function From_Unbounded_String (Source : Ada.Strings.Unbounded.Unbounded_String) return Rope is
     (From_String (Ada.Strings.Unbounded.To_String (Source)));

   function To_Unbounded_String (Source : Rope) return Ada.Strings.Unbounded.Unbounded_String is
     (Ada.Strings.Unbounded.To_Unbounded_String (To_String (Source)));

   function "*" (Left : Natural; Right : Character) return Rope is (Left * From_Character (Right));

   --  Rope.Mod's Repeat: O(log Left) by binary doubling -- Piece :=
   --  Piece & Piece repeatedly, accumulating Result & Piece on each odd
   --  bit of Left (the standard binary-exponentiation shape). Every
   --  doubling shares Piece's existing tree via "&" (which Incr_Refs
   --  both operands, so Piece appearing as both Left and Right of the
   --  same Concat is exactly the acyclic-sharing this is for -- see
   --  AGENTS.md's acyclic-invariant note), never copies its characters,
   --  so even Left in the billions stays cheap -- confirmed by
   --  test_repeat.adb's overflow-guard check, which builds a rope of
   --  length Natural'Last - 1 this way instantly.
   function "*" (Left : Natural; Right : Rope) return Rope is
      Count  : Natural := Left;
      Piece  : Rope    := Right;
      Result : Rope    := Null_Rope;
   begin
      if Is_Empty (Right) then
         return Null_Rope;
      end if;
      while Count > 0 loop
         if Count mod 2 = 1 then
            Result := Result & Piece;
         end if;
         Count := Count / 2;
         if Count > 0 then
            Piece := Piece & Piece;
         end if;
      end loop;
      return Result;
   end "*";

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

   procedure Copy_Slice (Source : Rope; Low : Positive; High : Natural; Target : in out String; Target_Low : Positive) is
      D   : constant Node_Access := Data_Of (Source);
      Len : constant Natural     := (if D = null then 0 else D.Len);
      T   : Positive             := Target_Low;
   begin
      if Low - 1 > Len or else High > Len then
         raise Ada.Strings.Index_Error;
      end if;
      if High < Low then
         return;
      end if;
      --  Written as a subtraction, not Target_Low + (High - Low) >
      --  Target'Last, so that a Target_Low near Positive'Last can't
      --  overflow the check itself.
      if Target_Low < Target'First or else High - Low > Target'Last - Target_Low then
         raise Ada.Strings.Index_Error;
      end if;
      Node_Copy (D, Low - 1, High - Low + 1, Target, T);
   end Copy_Slice;

   function Insert (Source : Rope; Before : Positive; New_Item : Rope) return Rope is
      Len : constant Natural := Length (Source);
   begin
      if Before - 1 > Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Slice (Source, 1, Before - 1) & New_Item & Slice (Source, Before, Len);
   end Insert;

   function Insert (Source : Rope; Before : Positive; New_Item : String) return Rope is
     (Insert (Source, Before, From_String (New_Item)));

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

   function Overwrite (Source : Rope; Position : Positive; New_Item : Rope) return Rope is
      Src_Len : constant Natural := Length (Source);
   begin
      if Position - 1 > Src_Len then
         raise Ada.Strings.Index_Error;
      end if;
      declare
         Tail_Start : constant Positive := Position + Length (New_Item);
      begin
         if Tail_Start <= Src_Len then
            return Slice (Source, 1, Position - 1) & New_Item & Slice (Source, Tail_Start, Src_Len);
         end if;
         return Slice (Source, 1, Position - 1) & New_Item;
      end;
   end Overwrite;

   function Overwrite (Source : Rope; Position : Positive; New_Item : String) return Rope is
     (Overwrite (Source, Position, From_String (New_Item)));

   function Replace_Slice (Source : Rope; Low : Positive; High : Natural; By : Rope) return Rope is
      Len : constant Natural := Length (Source);
   begin
      if Low - 1 > Len then
         raise Ada.Strings.Index_Error;
      end if;
      if High < Low then
         return Insert (Source, Low, By);
      end if;
      return Slice (Source, 1, Low - 1) & By & Slice (Source, Natural'Min (High, Len) + 1, Len);
   end Replace_Slice;

   function Replace_Slice (Source : Rope; Low : Positive; High : Natural; By : String) return Rope is
     (Replace_Slice (Source, Low, High, From_String (By)));

   function Head (Source : Rope; Count : Natural; Pad : Character := Ada.Strings.Space) return Rope is
   begin
      if Count <= Length (Source) then
         return Slice (Source, 1, Count);
      end if;
      return Source & (Count - Length (Source)) * Pad;
   end Head;

   function Tail (Source : Rope; Count : Natural; Pad : Character := Ada.Strings.Space) return Rope is
      Src_Len : constant Natural := Length (Source);
   begin
      if Count <= Src_Len then
         return Slice (Source, Src_Len - Count + 1, Src_Len);
      end if;
      return (Count - Src_Len) * Pad & Source;
   end Tail;

   function "=" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) = 0);

   function "<" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) < 0);

   function "<=" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) <= 0);

   function ">" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) > 0);

   function ">=" (Left, Right : Rope) return Boolean is (Compare (Data_Of (Left), Data_Of (Right)) >= 0);

   --  The String overloads: Compare (Data_Of (String_Side), Other)
   --  orders the rope against the string, so it is negated in sense
   --  when the String is the Left operand.

   function "=" (Left : Rope; Right : String) return Boolean is (Compare (Data_Of (Left), Right) = 0);

   function "=" (Left : String; Right : Rope) return Boolean is (Compare (Data_Of (Right), Left) = 0);

   function "<" (Left : Rope; Right : String) return Boolean is (Compare (Data_Of (Left), Right) < 0);

   function "<" (Left : String; Right : Rope) return Boolean is (Compare (Data_Of (Right), Left) > 0);

   function "<=" (Left : Rope; Right : String) return Boolean is (Compare (Data_Of (Left), Right) <= 0);

   function "<=" (Left : String; Right : Rope) return Boolean is (Compare (Data_Of (Right), Left) >= 0);

   function ">" (Left : Rope; Right : String) return Boolean is (Compare (Data_Of (Left), Right) > 0);

   function ">" (Left : String; Right : Rope) return Boolean is (Compare (Data_Of (Right), Left) < 0);

   function ">=" (Left : Rope; Right : String) return Boolean is (Compare (Data_Of (Left), Right) >= 0);

   function ">=" (Left : String; Right : Rope) return Boolean is (Compare (Data_Of (Right), Left) <= 0);

   ------------------------------------------------------------------
   --  Search.
   --
   --  Every search walks Source's leaves in its own direction with a
   --  Leaf_Walk started at From (Start_Walk_At), scanning each leaf's
   --  Chars in place: O(depth) to reach From's leaf, then O(1) per
   --  character -- not a Fetch from the root per character, which
   --  (until Phase 18) made every search O(n log n) and a pattern
   --  search O(n m log n). A pattern search tests each candidate's
   --  first character (last, going Backward) before comparing the rest,
   --  as a single slice comparison when the candidate lies within one
   --  leaf and a run at a time, on a copy of the walk, when it crosses
   --  into the next ones: O(n m) in the worst case, the same naive
   --  algorithm as GNAT's own Ada.Strings.Search.Index, but close to
   --  O(n) when the pattern's first character is uncommon.
   ------------------------------------------------------------------

   --  The index of the first (Forward: at or after From) or last
   --  (Backward: at or before From) character of the rope S_D for which
   --  Matches is True, or 0. Precondition: S_D /= null and From in 1 ..
   --  S_D.Len.
   generic
      with function Matches (Ch : Character) return Boolean;
   function Scan (S_D : Node_Access; From : Positive; Going : Ada.Strings.Direction) return Natural;

   function Scan (S_D : Node_Access; From : Positive; Going : Ada.Strings.Direction) return Natural is
      W    : Leaf_Walk (S_D.Depth + 1);
      Leaf : Node_Access;
      Off  : Positive;
      Base : Natural;  --  Leaf.Chars (I) is the rope's character Base + I.
   begin
      Start_Walk_At (W, S_D, From, Going, Leaf, Off);
      Base := From - Off;
      case Going is
         when Ada.Strings.Forward =>
            loop
               for I in Off .. Leaf.Len loop
                  if Matches (Leaf.Chars (I)) then
                     return Base + I;
                  end if;
               end loop;
               exit when W.Top = 0;
               Base := Base + Leaf.Len;
               Next_Leaf (W, Leaf);
               Off := 1;
            end loop;

         when Ada.Strings.Backward =>
            loop
               for I in reverse 1 .. Off loop
                  if Matches (Leaf.Chars (I)) then
                     return Base + I;
                  end if;
               end loop;
               exit when W.Top = 0;
               Next_Leaf (W, Leaf);
               Base := Base - Leaf.Len;
               Off  := Leaf.Len;
            end loop;
      end case;
      return 0;
   end Scan;

   --  The From-bounded pattern Index, for a non-empty Pattern with any
   --  bounds: the start of the first occurrence starting at or after
   --  From (Forward), or of the last one lying wholly within 1 .. From
   --  (Backward), or 0. Precondition: S_D /= null, Pattern /= "", and
   --  From <= S_D.Len.
   function Find (S_D : Node_Access; Pattern : String; From : Positive; Going : Ada.Strings.Direction) return Natural is
      S_Len : constant Positive := S_D.Len;
      P_Len : constant Positive := Pattern'Length;
      W     : Leaf_Walk (S_D.Depth + 1);
      Leaf  : Node_Access;
      Off   : Positive;
      Base  : Natural;  --  Leaf.Chars (I) is the rope's character Base + I.

      --  Whether Pattern occurs starting at Leaf.Chars (I), running on
      --  into the leaves after Leaf as needed -- which exist: the caller
      --  only asks when the occurrence would end within the rope.
      function Matches_Forward (I : Positive) return Boolean is
      begin
         if P_Len <= Leaf.Len - I + 1 then
            return Leaf.Chars (I .. I + (P_Len - 1)) = Pattern;
         end if;
         declare
            V_Walk : Leaf_Walk   := W;
            V_Leaf : Node_Access := Leaf;
            V_Off  : Positive    := I;
            K      : Positive    := Pattern'First;  --  Next Pattern character to compare.
            Left   : Natural     := P_Len;          --  Pattern characters still to compare.
         begin
            loop
               declare
                  Run : constant Positive := Natural'Min (V_Leaf.Len - V_Off + 1, Left);
               begin
                  if V_Leaf.Chars (V_Off .. V_Off + (Run - 1)) /= Pattern (K .. K + (Run - 1)) then
                     return False;
                  end if;
                  Left := Left - Run;
                  exit when Left = 0;
                  K := K + Run;
               end;
               Next_Leaf (V_Walk, V_Leaf);
               V_Off := 1;
            end loop;
            return True;
         end;
      end Matches_Forward;

      --  Whether Pattern occurs ending at Leaf.Chars (I), running back
      --  into the leaves before Leaf as needed -- which exist, as above.
      function Matches_Backward (I : Positive) return Boolean is
      begin
         if P_Len <= I then
            return Leaf.Chars (I - (P_Len - 1) .. I) = Pattern;
         end if;
         declare
            V_Walk : Leaf_Walk   := W;
            V_Leaf : Node_Access := Leaf;
            V_Off  : Positive    := I;
            K      : Positive    := Pattern'Last;  --  Next Pattern character to compare.
            Left   : Natural     := P_Len;         --  Pattern characters still to compare.
         begin
            loop
               declare
                  Run : constant Positive := Natural'Min (V_Off, Left);
               begin
                  if V_Leaf.Chars (V_Off - (Run - 1) .. V_Off) /= Pattern (K - (Run - 1) .. K) then
                     return False;
                  end if;
                  Left := Left - Run;
                  exit when Left = 0;
                  K := K - Run;
               end;
               Next_Leaf (V_Walk, V_Leaf);
               V_Off := V_Leaf.Len;
            end loop;
            return True;
         end;
      end Matches_Backward;
   begin
      case Going is
         when Ada.Strings.Forward =>
            --  Occurrences can start at From .. Last_Start.
            if P_Len > S_Len or else From > S_Len - P_Len + 1 then
               return 0;
            end if;
            declare
               First      : constant Character := Pattern (Pattern'First);
               Last_Start : constant Positive  := S_Len - P_Len + 1;
            begin
               Start_Walk_At (W, S_D, From, Going, Leaf, Off);
               Base := From - Off;
               loop
                  declare
                     Hi : constant Positive := Natural'Min (Leaf.Len, Last_Start - Base);
                  begin
                     for I in Off .. Hi loop
                        if Leaf.Chars (I) = First and then Matches_Forward (I) then
                           return Base + I;
                        end if;
                     end loop;
                     exit when Base + Hi = Last_Start;
                  end;
                  Base := Base + Leaf.Len;
                  Next_Leaf (W, Leaf);
                  Off := 1;
               end loop;
            end;

         when Ada.Strings.Backward =>
            --  Occurrences can end at P_Len .. From.
            if From < P_Len then
               return 0;
            end if;
            declare
               Last : constant Character := Pattern (Pattern'Last);
            begin
               Start_Walk_At (W, S_D, From, Going, Leaf, Off);
               Base := From - Off;
               loop
                  declare
                     Lo : constant Positive := Integer'Max (1, P_Len - Base);
                  begin
                     for I in reverse Lo .. Off loop
                        if Leaf.Chars (I) = Last and then Matches_Backward (I) then
                           return Base + I - P_Len + 1;
                        end if;
                     end loop;
                     exit when Base + Lo = P_Len;
                  end;
                  Next_Leaf (W, Leaf);
                  Base := Base - Leaf.Len;
                  Off  := Leaf.Len;
               end loop;
            end;
      end case;
      return 0;
   end Find;

   --  A multi-leaf pattern, flattened for Find: onto the heap rather
   --  than the stack, since a pattern can be as long as any rope.
   type String_Access is access String;

   procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);

   --  Precondition: P_D /= null.
   function Flatten (P_D : Node_Access) return String_Access is
      Result : constant String_Access := new String (1 .. P_D.Len);
      T      : Positive               := 1;
   begin
      Node_Copy (P_D, 0, P_D.Len, Result.all, T);
      return Result;
   end Flatten;

   function Index
     (Source : Rope; Pattern : String; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural
   is
      S_D : constant Node_Access := Data_Of (Source);
   begin
      --  Source's emptiness is checked, and short-circuits, before
      --  Pattern's -- verified against GNAT's a-strsea.adb: the
      --  From-bounded Ada.Strings.Search.Index returns 0 immediately
      --  for an empty Source, even when Pattern is also empty (the
      --  Pattern_Error check lives in the *other*, no-From overload,
      --  reached only once Source is known non-empty). Then From must
      --  be in Source's range, in either direction -- the RM's rule
      --  (A.4.3(56.2/3)), not GNAT's laxer one: see ropes.ads and
      --  PLAN.md's "Search".
      if S_D = null then
         return 0;
      end if;
      if Pattern'Length = 0 then
         raise Ada.Strings.Pattern_Error;
      end if;
      if From > S_D.Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Find (S_D, Pattern, From, Going);
   end Index;

   function Index
     (Source : Rope; Pattern : Rope; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural
   is
      P_D : constant Node_Access := Data_Of (Pattern);
   begin
      if Is_Empty (Source) then
         return 0;
      end if;
      if P_D = null then
         raise Ada.Strings.Pattern_Error;
      end if;
      if From > Length (Source) then
         raise Ada.Strings.Index_Error;
      end if;
      if P_D.Kind = Leaf_Kind then
         return Index (Source, P_D.Chars, From, Going);
      end if;
      declare
         Flat   : String_Access := Flatten (P_D);
         Result : Natural;
      begin
         Result := Index (Source, Flat.all, From, Going);
         Free (Flat);
         return Result;
      exception
         when others =>
            Free (Flat);
            raise;
      end;
   end Index;

   function Index (Source : Rope; Pattern : Rope; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural is
   begin
      --  Pattern's emptiness is checked first here -- the mirror image
      --  of the From-bounded overload above, matching the real
      --  no-From Ada.Strings.Search.Index, whose Pattern_Error check
      --  runs unconditionally, before it ever looks at Source.
      if Is_Empty (Pattern) then
         raise Ada.Strings.Pattern_Error;
      end if;
      if Is_Empty (Source) then
         return 0;
      end if;
      case Going is
         when Ada.Strings.Forward =>
            return Index (Source, Pattern, 1, Going);
         when Ada.Strings.Backward =>
            return Index (Source, Pattern, Length (Source), Going);
      end case;
   end Index;

   function Index (Source : Rope; Pattern : String; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural is
   begin
      --  As the Rope overload just above.
      if Pattern'Length = 0 then
         raise Ada.Strings.Pattern_Error;
      end if;
      if Is_Empty (Source) then
         return 0;
      end if;
      case Going is
         when Ada.Strings.Forward =>
            return Index (Source, Pattern, 1, Going);
         when Ada.Strings.Backward =>
            return Index (Source, Pattern, Length (Source), Going);
      end case;
   end Index;

   function Index
     (Source : Rope; Pattern : Character; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural
   is
      S_D : constant Node_Access := Data_Of (Source);

      function Is_Pattern (Ch : Character) return Boolean is (Ch = Pattern);

      function Scan_For_Pattern is new Scan (Is_Pattern);
   begin
      if S_D = null then
         return 0;
      end if;
      if From > S_D.Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Scan_For_Pattern (S_D, From, Going);
   end Index;

   function Index (Source : Rope; Pattern : Character; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural is
   begin
      if Is_Empty (Source) then
         return 0;
      end if;
      case Going is
         when Ada.Strings.Forward =>
            return Index (Source, Pattern, 1, Going);
         when Ada.Strings.Backward =>
            return Index (Source, Pattern, Length (Source), Going);
      end case;
   end Index;

   function Index
     (Source : Rope; Set : Ada.Strings.Maps.Character_Set; From : Positive; Test : Ada.Strings.Membership := Ada.Strings.Inside;
      Going  : Ada.Strings.Direction := Ada.Strings.Forward) return Natural
   is
      use type Ada.Strings.Membership;

      S_D  : constant Node_Access := Data_Of (Source);
      Want : constant Boolean     := Test = Ada.Strings.Inside;

      function Passes (Ch : Character) return Boolean is (Ada.Strings.Maps.Is_In (Ch, Set) = Want);

      function Scan_For_Set is new Scan (Passes);
   begin
      if S_D = null then
         return 0;
      end if;
      if From > S_D.Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Scan_For_Set (S_D, From, Going);
   end Index;

   function Index
     (Source : Rope; Set : Ada.Strings.Maps.Character_Set; Test : Ada.Strings.Membership := Ada.Strings.Inside;
      Going  : Ada.Strings.Direction := Ada.Strings.Forward) return Natural
   is
   begin
      if Is_Empty (Source) then
         return 0;
      end if;
      case Going is
         when Ada.Strings.Forward =>
            return Index (Source, Set, 1, Test, Going);
         when Ada.Strings.Backward =>
            return Index (Source, Set, Length (Source), Test, Going);
      end case;
   end Index;

   Blank : constant Ada.Strings.Maps.Character_Set := Ada.Strings.Maps.To_Set (Ada.Strings.Space);

   function Index_Non_Blank (Source : Rope; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural is
     (Index (Source, Blank, Ada.Strings.Outside, Going));

   function Index_Non_Blank (Source : Rope; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural is
     (Index (Source, Blank, From, Ada.Strings.Outside, Going));

   --  Two forward scans: one for the token's first character, one for
   --  the first character after it that isn't in the token.
   procedure Find_Token
     (Source :     Rope; Set : Ada.Strings.Maps.Character_Set; From : Positive; Test : Ada.Strings.Membership; First : out Positive;
      Last   : out Natural)
   is
      use type Ada.Strings.Membership;

      Len   : constant Natural := Length (Source);
      Start : Natural;
      After : Natural;
   begin
      if Len /= 0 and then From > Len then
         raise Ada.Strings.Index_Error;
      end if;
      Start := Index (Source, Set, From, Test, Ada.Strings.Forward);
      if Start = 0 then
         First := From;
         Last  := 0;
         return;
      end if;
      After :=
        Index
          (Source, Set, Start, (if Test = Ada.Strings.Inside then Ada.Strings.Outside else Ada.Strings.Inside),
           Ada.Strings.Forward);
      First := Start;
      Last  := (if After = 0 then Len else After - 1);
   end Find_Token;

   procedure Find_Token
     (Source : Rope; Set : Ada.Strings.Maps.Character_Set; Test : Ada.Strings.Membership; First : out Positive; Last : out Natural)
   is
   begin
      Find_Token (Source, Set, 1, Test, First, Last);
   end Find_Token;

   function Count (Source : Rope; Pattern : String) return Natural is
      S_D    : constant Node_Access := Data_Of (Source);
      P_Len  : constant Natural     := Pattern'Length;
      Result : Natural              := 0;
      From   : Positive             := 1;
      Found  : Natural;
   begin
      if P_Len = 0 then
         raise Ada.Strings.Pattern_Error;
      end if;
      if S_D = null then
         return 0;
      end if;
      loop
         Found := Find (S_D, Pattern, From, Ada.Strings.Forward);
         exit when Found = 0;
         Result := Result + 1;
         --  A match reaching the end leaves no room for another; stop
         --  there rather than compute Found + P_Len, which overflows
         --  if that end is Natural'Last.
         exit when Found - 1 + P_Len = S_D.Len;
         From := Found + P_Len;
      end loop;
      return Result;
   end Count;

   function Count (Source : Rope; Pattern : Rope) return Natural is
      P_D : constant Node_Access := Data_Of (Pattern);
   begin
      if P_D = null then
         raise Ada.Strings.Pattern_Error;
      end if;
      if P_D.Kind = Leaf_Kind then
         return Count (Source, P_D.Chars);
      end if;
      declare
         Flat   : String_Access := Flatten (P_D);
         Result : Natural;
      begin
         Result := Count (Source, Flat.all);
         Free (Flat);
         return Result;
      exception
         when others =>
            Free (Flat);
            raise;
      end;
   end Count;

   function Count (Source : Rope; Set : Ada.Strings.Maps.Character_Set) return Natural is
      Result : Natural := 0;

      procedure Count_Chunk (Chunk : String) is
      begin
         for Ch of Chunk loop
            if Ada.Strings.Maps.Is_In (Ch, Set) then
               Result := Result + 1;
            end if;
         end loop;
      end Count_Chunk;
   begin
      Process_Chunks (Source, Count_Chunk'Access);
      return Result;
   end Count;

   function Contains (Source, Pattern : Rope) return Boolean is (Index (Source, Pattern) /= 0);

   function Contains (Source, Pattern : Rope; From : Positive) return Boolean is
     (Index (Source, Pattern, From, Ada.Strings.Forward) /= 0);

   function Contains (Source : Rope; Pattern : Character) return Boolean is (Index (Source, Pattern) /= 0);

   function Contains (Source : Rope; Pattern : Character; From : Positive) return Boolean is
     (Index (Source, Pattern, From, Ada.Strings.Forward) /= 0);

   function Contains (Source : Rope; Pattern : String) return Boolean is (Index (Source, Pattern) /= 0);

   function Contains (Source : Rope; Pattern : String; From : Positive) return Boolean is
     (Index (Source, Pattern, From, Ada.Strings.Forward) /= 0);

   ------------------------------------------------------------------
   --  Splitting.
   --
   --  Rope.Mod's CountPieces/NextPiece, done as one two-pass walk per
   --  overload below (count, then build) instead of a single dynamic
   --  pass, matching Rope.Mod's own two-pass CountPieces + SplitArray
   --  shape. Each overload supplies its own "find the next occurrence
   --  at or after position P" search, Find_Next, on the From-bounded
   --  Index above for its kind of separator (0 for a P past the end,
   --  which Index itself rejects); the walk itself -- advance past the match, repeat, Slice out
   --  what's left over at the end -- is the same shape in all three,
   --  by construction of how Slice's own boundary behavior (empty for
   --  High < Low, valid at Low = Length + 1) already produces the
   --  right empty-piece results at the start, middle, and end without
   --  any special-casing here.
   ------------------------------------------------------------------

   function Split (Source : Rope; Separator : Rope) return Rope_Array is
      Sep_Len : constant Natural := Length (Separator);

      --  The next Separator at or after From, or 0. After a separator
      --  that ends Source, From is Length (Source) + 1, which Index
      --  rejects (the RM's From rule), so that case is 0 here.
      function Find_Next (From : Positive) return Natural is
        (if From > Length (Source) then 0 else Index (Source, Separator, From, Ada.Strings.Forward));
   begin
      if Sep_Len = 0 then
         return [1 => Source];
      end if;
      declare
         Count : Positive := 1;
         Pos   : Positive := 1;
         Found : Natural;
      begin
         loop
            Found := Find_Next (Pos);
            exit when Found = 0;
            Count := Count + 1;
            Pos   := Found + Sep_Len;
         end loop;

         declare
            Result : Rope_Array (1 .. Count);
            Start  : Positive := 1;
         begin
            for I in 1 .. Count - 1 loop
               Found      := Find_Next (Start);
               Result (I) := Slice (Source, Start, Found - 1);
               Start      := Found + Sep_Len;
            end loop;
            Result (Count) := Slice (Source, Start, Length (Source));
            return Result;
         end;
      end;
   end Split;

   function Split (Source : Rope; Separator : String) return Rope_Array is (Split (Source, From_String (Separator)));

   function Split (Source : Rope; Separator : Character) return Rope_Array is
      S_Len : constant Natural := Length (Source);

      --  The next Separator at or after From, or 0 -- including for
      --  From = S_Len + 1, after a separator that ends Source, which
      --  Index rejects (the RM's From rule).
      function Find_Next (From : Positive) return Natural is
        (if From > S_Len then 0 else Index (Source, Separator, From, Ada.Strings.Forward));

      Count : Positive := 1;
      Pos   : Positive := 1;
      Found : Natural;
   begin
      loop
         Found := Find_Next (Pos);
         exit when Found = 0;
         Count := Count + 1;
         Pos   := Found + 1;
      end loop;

      declare
         Result : Rope_Array (1 .. Count);
         Start  : Positive := 1;
      begin
         for I in 1 .. Count - 1 loop
            Found      := Find_Next (Start);
            Result (I) := Slice (Source, Start, Found - 1);
            Start      := Found + 1;
         end loop;
         Result (Count) := Slice (Source, Start, S_Len);
         return Result;
      end;
   end Split;

   function Split (Source : Rope; Separator : Ada.Strings.Maps.Character_Set) return Rope_Array is
      S_Len : constant Natural := Length (Source);

      --  As in the Character Split above.
      function Find_Next (From : Positive) return Natural is
        (if From > S_Len then 0 else Index (Source, Separator, From, Ada.Strings.Inside, Ada.Strings.Forward));

      Count : Positive := 1;
      Pos   : Positive := 1;
      Found : Natural;
   begin
      if Ada.Strings.Maps."=" (Separator, Ada.Strings.Maps.Null_Set) then
         return [1 => Source];
      end if;

      loop
         Found := Find_Next (Pos);
         exit when Found = 0;
         Count := Count + 1;
         Pos   := Found + 1;
      end loop;

      declare
         Result : Rope_Array (1 .. Count);
         Start  : Positive := 1;
      begin
         for I in 1 .. Count - 1 loop
            Found      := Find_Next (Start);
            Result (I) := Slice (Source, Start, Found - 1);
            Start      := Found + 1;
         end loop;
         Result (Count) := Slice (Source, Start, S_Len);
         return Result;
      end;
   end Split;

   ------------------------------------------------------------------
   --  Splitting, Process-callback form: Rope.Mod's own Visitor-based
   --  Split, restored (see PLAN.md's "Deferred / stretch" section) as
   --  a genuine single pass -- unlike the array-returning overloads
   --  above, there is no separate counting pass first, and never more
   --  than one piece alive at a time. Each mirrors its array-returning
   --  counterpart's own "find the next occurrence at or after position
   --  P" search, just walked once instead of twice, and stopping as
   --  soon as either the last piece is visited or Process returns
   --  False -- Rope.Mod's own "WHILE more & ~last DO more :=
   --  visit(NextPiece(...)) END" shape, translated directly.
   ------------------------------------------------------------------

   procedure Split (Source : Rope; Separator : Rope; Process : not null access function (Piece : Rope) return Boolean) is
      Sep_Len : constant Natural := Length (Separator);

      --  As in the array-returning Split above.
      function Find_Next (From : Positive) return Natural is
        (if From > Length (Source) then 0 else Index (Source, Separator, From, Ada.Strings.Forward));

      Start : Positive := 1;
      Found : Natural;
      More  : Boolean;
   begin
      if Sep_Len = 0 then
         More := Process (Source);
         return;
      end if;
      loop
         Found := Find_Next (Start);
         if Found = 0 then
            More := Process (Slice (Source, Start, Length (Source)));
            exit;
         end if;
         More := Process (Slice (Source, Start, Found - 1));
         exit when not More;
         Start := Found + Sep_Len;
      end loop;
   end Split;

   procedure Split (Source : Rope; Separator : String; Process : not null access function (Piece : Rope) return Boolean) is
   begin
      Split (Source, From_String (Separator), Process);
   end Split;

   procedure Split (Source : Rope; Separator : Character; Process : not null access function (Piece : Rope) return Boolean) is
      S_Len : constant Natural := Length (Source);

      --  The next Separator at or after From, or 0 -- including for
      --  From = S_Len + 1, after a separator that ends Source, which
      --  Index rejects (the RM's From rule).
      function Find_Next (From : Positive) return Natural is
        (if From > S_Len then 0 else Index (Source, Separator, From, Ada.Strings.Forward));

      Start : Positive := 1;
      Found : Natural;
      More  : Boolean;
   begin
      loop
         Found := Find_Next (Start);
         if Found = 0 then
            More := Process (Slice (Source, Start, S_Len));
            exit;
         end if;
         More := Process (Slice (Source, Start, Found - 1));
         exit when not More;
         Start := Found + 1;
      end loop;
   end Split;

   procedure Split
     (Source : Rope; Separator : Ada.Strings.Maps.Character_Set; Process : not null access function (Piece : Rope) return Boolean)
   is
      S_Len : constant Natural := Length (Source);

      --  As in the Character Split above.
      function Find_Next (From : Positive) return Natural is
        (if From > S_Len then 0 else Index (Source, Separator, From, Ada.Strings.Inside, Ada.Strings.Forward));

      Start : Positive := 1;
      Found : Natural;
      More  : Boolean;
   begin
      if Ada.Strings.Maps."=" (Separator, Ada.Strings.Maps.Null_Set) then
         More := Process (Source);
         return;
      end if;
      loop
         Found := Find_Next (Start);
         if Found = 0 then
            More := Process (Slice (Source, Start, S_Len));
            exit;
         end if;
         More := Process (Slice (Source, Start, Found - 1));
         exit when not More;
         Start := Found + 1;
      end loop;
   end Split;

   ------------------------------------------------------------------
   --  Iteration: Cursor and the four Iterable-aspect operations. See
   --  ropes.ads's Cursor doc comment and PLAN.md's "Iteration"
   --  section.
   ------------------------------------------------------------------

   function First (Source : Rope) return Cursor is
      D      : constant Node_Access := Data_Of (Source);
      Result : Cursor;
   begin
      Result.Pos := 1;
      if D /= null then
         Locate_Leaf (D, 1, 0, Result.Leaf, Result.Leaf_Start);
      end if;
      return Result;
   end First;

   function Next (Source : Rope; Position : Cursor) return Cursor is
      New_Pos : constant Positive := Position.Pos + 1;
      Result  : Cursor;
   begin
      Result.Pos := New_Pos;
      if Position.Leaf /= null and then New_Pos >= Position.Leaf_Start and then New_Pos < Position.Leaf_Start + Position.Leaf.Len
      then
         --  New_Pos is still covered by the same leaf as Position --
         --  O(1), no descent needed, Rope.Mod's Locate's own
         --  cache-hit shortcut.
         Result.Leaf       := Position.Leaf;
         Result.Leaf_Start := Position.Leaf_Start;
      elsif New_Pos <= Length (Source) then
         --  Crossing into a new leaf (or this is Next's first call
         --  after a Cursor built some other way) -- an O(log n)
         --  descent from the root, same as a cache miss in Rope.Mod's
         --  Locate.
         Locate_Leaf (Data_Of (Source), New_Pos, 0, Result.Leaf, Result.Leaf_Start);
      end if;
      --  Else New_Pos is past the end: Result.Leaf stays null (its
      --  default), matching Has_Element (Source, Result) = False.
      return Result;
   end Next;

   function Has_Element (Source : Rope; Position : Cursor) return Boolean is
     (Position.Leaf /= null and then Position.Pos <= Length (Source));
   --  The Leaf /= null check is defensive, not load-bearing for a
   --  Cursor produced by First/Next (there, Leaf is null exactly when
   --  Pos > Length (Source) already) -- it only matters for a
   --  hand-built Cursor (e.g. a default-initialized one), the same
   --  misuse class Ada.Containers Cursors don't guard against either;
   --  cheap enough to check anyway.

   function Element (Source : Rope; Position : Cursor) return Character is
      pragma Unreferenced (Source);
   begin
      --  Position.Leaf already covers Position.Pos -- First/Next's
      --  invariant -- so this is an O(1) read of the cache, no
      --  Locate_Leaf call needed here at all.
      return Position.Leaf.Chars (Position.Pos - Position.Leaf_Start + 1);
   end Element;

   ------------------------------------------------------------------
   --  Whitespace / trimming, Case mapping. See PLAN.md's "Whitespace
   --  / trimming" and "Case mapping" sections.
   ------------------------------------------------------------------

   function Trim
     (Source : Rope; Left : Ada.Strings.Maps.Character_Set := Whitespace; Right : Ada.Strings.Maps.Character_Set := Whitespace)
      return Rope
   is
      Len   : constant Natural := Length (Source);
      First : Positive         := 1;
      Last  : Natural          := Len;
   begin
      --  First and Last are each found by scanning the *whole* rope
      --  independently -- First forward from position 1 bounded by
      --  Left, Last backward from Len bounded by Right, verified
      --  against GNAT's actual a-strfix.adb rather than assumed (same
      --  discipline as every earlier phase): Ada.Strings.Fixed.Trim's
      --  own Low/High are computed the same independent way, each
      --  scanning the whole original Source, not bounded by the
      --  other's result. That independence still ends up producing
      --  the right "entirely trimmed away" answer here without any
      --  extra special-casing, because Slice's own already-verified
      --  boundary behavior (Phase 3: High < Low, even at the extremes
      --  First = Len + 1 or Last = 0, is Null_Rope, never
      --  Index_Error) already covers every case this can produce.
      while First <= Len and then Ada.Strings.Maps.Is_In (Element (Source, First), Left) loop
         First := First + 1;
      end loop;
      while Last >= 1 and then Ada.Strings.Maps.Is_In (Element (Source, Last), Right) loop
         Last := Last - 1;
      end loop;
      return Slice (Source, First, Last);
   end Trim;

   function Map (Source : Rope; Convert : not null access function (Ch : Character) return Character) return Rope is
     (Wrap (Map_Node (Data_Of (Source), Convert)));

   function Map_Indexed
     (Source : Rope; Convert : not null access function (Index : Positive; Ch : Character) return Character) return Rope
   is
      Next_Index : Positive := 1;
   begin
      return Wrap (Map_Indexed_Node (Data_Of (Source), Convert, Next_Index));
   end Map_Indexed;

   function Translate (Source : Rope; Mapping : Ada.Strings.Maps.Character_Mapping) return Rope is
      function Convert (Ch : Character) return Character is (Ada.Strings.Maps.Value (Mapping, Ch));
   begin
      return Map (Source, Convert'Access);
   end Translate;

   function Translate (Source : Rope; Mapping : Ada.Strings.Maps.Character_Mapping_Function) return Rope is (Map (Source, Mapping));

   function To_Upper (Source : Rope) return Rope is (Map (Source, Ada.Characters.Handling.To_Upper'Access));

   function To_Lower (Source : Rope) return Rope is (Map (Source, Ada.Characters.Handling.To_Lower'Access));

   function Capitalize (Source : Rope) return Rope is
   begin
      if Is_Empty (Source) then
         return Null_Rope;
      end if;
      return From_String ([Ada.Characters.Handling.To_Upper (Element (Source, 1))]) & Slice (Source, 2, Length (Source));
   end Capitalize;

   function Uncapitalize (Source : Rope) return Rope is
   begin
      if Is_Empty (Source) then
         return Null_Rope;
      end if;
      return From_String ([Ada.Characters.Handling.To_Lower (Element (Source, 1))]) & Slice (Source, 2, Length (Source));
   end Uncapitalize;

   --  Rope.Mod's EscapeChar, unrolled into Escape's loop directly
   --  (Rope.Mod's own separate EscapeChar/Escaped pair exists only
   --  because Oberon-2 has no local functions inside a loop; a nested
   --  block here does the same job). Built with "for Ch of Source
   --  loop" -- Phase 5's Cursor/Iterable -- and the new "&" (Rope,
   --  Character) overload above, rather than hand-walking Fetch by
   --  index the way Rope.Mod must.
   function Escape (Source : Rope) return Rope is
      Result : Rope := Null_Rope;
   begin
      for Ch of Source loop
         case Ch is
            when '\' =>
               Result := Result & '\' & '\';

            when '"' =>
               Result := Result & '\' & '"';

            when Ada.Characters.Latin_1.LF =>
               Result := Result & '\' & 'n';

            when Ada.Characters.Latin_1.HT =>
               Result := Result & '\' & 't';

            when Ada.Characters.Latin_1.CR =>
               Result := Result & '\' & 'r';

            when others =>
               if Character'Pos (Ch) < 32 or else Character'Pos (Ch) >= 127 then
                  declare
                     V : constant Natural := Character'Pos (Ch);
                  begin
                     Result :=
                       Result & '\' & Character'Val (Character'Pos ('0') + V / 100) &
                       Character'Val (Character'Pos ('0') + (V / 10) mod 10) & Character'Val (Character'Pos ('0') + V mod 10);
                  end;
               else
                  Result := Result & Ch;
               end if;
         end case;
      end loop;
      return Result;
   end Escape;

end Ropes;
