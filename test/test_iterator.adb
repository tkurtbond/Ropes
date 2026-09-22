--  Phase 5 checks: Cursor and the Iterable aspect ("for Ch of
--  Some_Rope loop"). See PLAN.md's phased plan and Testing approach,
--  and RopeTest.Mod's CheckIterator
--  (~/Repos/Oberon/oberon-tools/RopeTest.Mod). Rope.Mod's Iterator is
--  a heap-allocated object with arbitrary-position Peek/Goto/Move/
--  Decr/Source methods; Ropes's Cursor only supports the Iterable
--  aspect's forward-only First/Next/Has_Element/Element shape (see
--  ropes.ads's Cursor doc comment), so CheckIterator's Peek/Goto/
--  Move/Decr/Source cases don't translate -- there is nothing to
--  translate them to. What does translate: NewIterator's initial
--  position, Get/Incr stepping (including across the leaf boundary
--  that was the whole point of CheckIterator's two-leaf test rope),
--  and the "walking forward matches Fetch at every position" loop,
--  which is the real correctness test for the leaf-caching Locate
--  logic (ropes.adb's Locate_Leaf/First/Next).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Real_Time;    use Ada.Real_Time;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Iterator is

   Passed, Failed : Natural := 0;

   procedure Check (Cond : Boolean; Name : String) is
   begin
      if Cond then
         Put_Line ("ok   - " & Name);
         Passed := Passed + 1;
      else
         Put_Line ("FAIL - " & Name);
         Failed := Failed + 1;
      end if;
   end Check;

   function Cycled_Char (I : Natural) return Character is (Character'Val (Character'Pos ('a') + I mod 26));

begin
   --  --- "for Ch of R loop" over a Null_Rope: zero iterations ---

   declare
      Count : Natural := 0;
   begin
      for Ch of Null_Rope loop
         Count := Count + 1;
      end loop;
      Check (Count = 0, "for Ch of Null_Rope loop visits nothing");
   end;

   --  --- "for Ch of R loop" round-trips a short rope ---

   declare
      R    : constant Rope := From_String ("hello");
      Buf  : String (1 .. 5);
      Next : Positive      := 1;
   begin
      for Ch of R loop
         Buf (Next) := Ch;
         Next       := Next + 1;
      end loop;
      Check (Next = 6 and then Buf = "hello", "for Ch of R loop visits every character in order");
   end;

   --  --- Two leaves, crossing the boundary (Rope.Mod's own test rope
   --  shape: a 16-character first leaf -- Short_Leaf_Length -- so
   --  position 16 is its last 1-based index and 17 crosses into the
   --  second leaf) ---

   declare
      R : constant Rope := From_String ("0123456789012345") & From_String ("abcdefghij");
      --  Length 26: "0"(1) .. "5"(16) | "a"(17) .. "j"(26).

      C : Cursor := First (R);
   begin
      Check (Has_Element (R, C), "First: Has_Element is True at the start of a non-empty rope");
      Check (Element (R, C) = '0', "Element at First: first character");

      C := Next (R, C);
      Check (Element (R, C) = '1', "Next moves forward one character");

      --  Walk to position 16, the first leaf's last character.
      for I in 1 .. 14 loop
         C := Next (R, C);
      end loop;
      Check (Element (R, C) = '5', "Element at the last character of the first leaf");

      C := Next (R, C);
      Check (Element (R, C) = 'a', "Element just after crossing into the second leaf");

      --  Walk to the very last character.
      for I in 1 .. 9 loop
         C := Next (R, C);
      end loop;
      Check (Element (R, C) = 'j', "Element at the last character of the rope");
      Check (Has_Element (R, C), "Has_Element is still True at the last character");

      C := Next (R, C);
      Check (not Has_Element (R, C), "Has_Element is False one past the last character");
   end;

   --  --- Walking forward with First/Next matches Element (Index) at
   --  every position -- RopeTest.Mod's own strongest CheckIterator
   --  assertion, here against Element (Rope, Positive) instead of
   --  Fetch, since that is Ropes's public equivalent ---

   declare
      R  : constant Rope := From_String ("0123456789012345") & From_String ("abcdefghij");
      C  : Cursor        := First (R);
      Ok : Boolean       := True;
      I  : Positive      := 1;
   begin
      while Has_Element (R, C) loop
         if Element (R, C) /= Element (R, I) then
            Ok := False;
         end if;
         C := Next (R, C);
         I := I + 1;
      end loop;
      Check (Ok and then I = Length (R) + 1, "Walking forward with First/Next matches Element (Rope, Positive) everywhere");
   end;

   --  --- Amortized O(1) stepping: a full traversal of a rope ten
   --  times larger takes well under ten times as long times a log
   --  factor -- a generous, non-brittle bound (PLAN.md's Phase 5 goal
   --  is confirming traversal is linear in length, not length *
   --  log(length); Max_Depth is under 60, so even an O(n log n)
   --  traversal would not plausibly need more than this bound) ---

   declare
      function Build (N : Positive) return Rope is
         R : Rope := Null_Rope;
      begin
         for I in 1 .. N loop
            R := R & From_String ([Cycled_Char (I)]);
         end loop;
         return R;
      end Build;

      function Traverse_Time (R : Rope) return Time_Span is
         Start : constant Time := Clock;
         Sum   : Natural       := 0;
      begin
         for Ch of R loop
            Sum := Sum + Character'Pos (Ch);
         end loop;
         return Clock - Start;
      end Traverse_Time;

      Small_R : constant Rope := Build (50_000);
      Big_R   : constant Rope := Build (500_000);

      Small_Time : constant Time_Span := Traverse_Time (Small_R);
      Big_Time   : constant Time_Span := Traverse_Time (Big_R);
   begin
      Check (Big_Time < 25 * Small_Time, "Traversal of a 10x-larger rope takes well under 10x * a generous log factor as long");
   end;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Iterator;
