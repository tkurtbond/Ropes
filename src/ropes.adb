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

   function "&" (Left, Right : Rope) return Rope is (Wrap (New_Simple_Cat (Data_Of (Left), Data_Of (Right))));

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

      D : constant Node_Access := Data_Of (Source);
   begin
      if D = null or else Index > D.Len then
         raise Ada.Strings.Index_Error;
      end if;
      return Fetch (D, Index);
   end Element;

end Ropes;
