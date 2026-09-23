--  Phase 3 checks: the five comparison operators. See PLAN.md's
--  phased plan and Testing approach, and RopeTest.Mod's
--  CheckCompareFindRepeat (~/Repos/Oberon/oberon-tools/RopeTest.Mod)
--  -- just its Compare/Equal cases; Find and Repeat are later phases.
--  Translated from Rope.Mod's -1/0/1 Compare and boolean Equal to the
--  five standard operators (see ropes.ads); a couple of extra "<="/
--  ">=" reflexivity checks are added since Rope.Mod itself never
--  exercised those two directly (only Compare/Equal existed there).
--  Check_Leaf_Boundaries/Check_Large were added at Phase 11, when
--  Compare became a leaf-run walk: the original checks all compare
--  one-leaf ropes, which never exercise the run logic at all.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Compare is

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

   --  Source split into leaves of Size characters each (Size > 16, the
   --  short-leaf merge threshold, so "&" keeps them as separate leaves).
   function Chunked (Source : String; Size : Positive) return Rope is
      Result : Rope;
      I      : Positive := Source'First;
   begin
      while I <= Source'Last loop
         Result := Result & From_String (Source (I .. Natural'Min (I + Size - 1, Source'Last)));
         I      := I + Size;
      end loop;
      return Result;
   end Chunked;

   Base : constant String (1 .. 200) := [for I in 1 .. 200 => Character'Val (Character'Pos ('a') + I mod 26)];

   --  Compare's oracle: Ropes's operators must agree with String's own
   --  on every pair, whatever the two ropes' leaf boundaries are.
   function Agrees (A, B : Rope) return Boolean is
      SA : constant String := To_String (A);
      SB : constant String := To_String (B);
   begin
      return (A = B) = (SA = SB) and then (A < B) = (SA < SB) and then (A > B) = (SA > SB);
   end Agrees;

   procedure Check_Leaf_Boundaries is
      A      : constant Rope := Chunked (Base, 17);
      All_OK : Boolean       := True;
   begin
      Check (A = Chunked (Base, 23) and then Chunked (Base, 23) = A, "Compare: same text, different leaf boundaries, is equal");

      --  One character changed, up or down, at every position: covers a
      --  difference at the first/last character and at, just before, and
      --  just after every leaf boundary of either rope.
      for P in Base'Range loop
         for Delta_Pos in -1 .. 1 loop
            declare
               Changed : String := Base;
            begin
               Changed (P) := Character'Val (Character'Pos (Changed (P)) + Delta_Pos);
               --  Delta_Pos = 0 leaves Changed = Base: the equal case,
               --  checked through the same path.
               All_OK      := All_OK and then Agrees (A, Chunked (Changed, 23)) and then Agrees (Chunked (Changed, 23), A);
            end;
         end loop;
      end loop;
      Check (All_OK, "Compare: a one-character difference at every position agrees with String comparison");

      All_OK := True;
      for L in 0 .. Base'Last loop
         All_OK := All_OK and then Agrees (A, Chunked (Base (1 .. L), 23)) and then Agrees (Chunked (Base (1 .. L), 23), A);
      end loop;
      Check (All_OK, "Compare: every prefix length agrees with String comparison");
   end Check_Leaf_Boundaries;

   --  Twenty million characters each, built with different leaf sizes so
   --  no subtree is shared: "=" used to take ~7 s here (a Fetch from the
   --  root per character); now linear.
   procedure Check_Large is
      Big_1 : constant Rope := 2_000_000 * From_String ("0123456789");
      Big_2 : constant Rope := 1_000_000 * From_String ("01234567890123456789");
      Copy  : constant Rope := Big_1;
   begin
      Check (Big_1 = Big_2, "Compare: two large equal ropes with no shared structure");
      Check (Big_1 < Big_2 & 'x', "Compare: a large rope sorts before itself plus one more character");
      Check (Copy = Big_1, "Compare: a rope equals a copy of itself (shared tree)");
   end Check_Large;

begin
   Check (From_String ("abc") = From_String ("abc"), "Compare: equal ropes");
   Check (From_String ("abc") < From_String ("abd"), "Compare: less-than");
   Check (From_String ("abd") > From_String ("abc"), "Compare: greater-than");
   Check (From_String ("ab") < From_String ("abc"), "Compare: shorter prefix sorts first");
   Check (From_String ("xyz") = From_String ("xyz"), "Equal");
   Check (From_String ("xyz") /= From_String ("xy"), "Not equal (/= derived automatically from =)");

   Check (From_String ("abc") <= From_String ("abc"), "<= is reflexive on equal ropes");
   Check (From_String ("abc") >= From_String ("abc"), ">= is reflexive on equal ropes");
   Check (From_String ("abc") <= From_String ("abd"), "<= on a strictly-less pair");
   Check (From_String ("abd") >= From_String ("abc"), ">= on a strictly-greater pair");
   Check (not (From_String ("abd") <= From_String ("abc")), "not (<= on a strictly-greater pair)");

   Check (Null_Rope = Null_Rope, "Null_Rope = Null_Rope");
   Check (Null_Rope < From_String ("a"), "Null_Rope sorts before any non-empty rope");

   Check_Leaf_Boundaries;
   Check_Large;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Compare;
