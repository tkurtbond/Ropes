--  Phase 3 checks: the five comparison operators. See PLAN.md's
--  phased plan and Testing approach, and RopeTest.Mod's
--  CheckCompareFindRepeat (~/Repos/Oberon/oberon-tools/RopeTest.Mod)
--  -- just its Compare/Equal cases; Find and Repeat are later phases.
--  Translated from Rope.Mod's -1/0/1 Compare and boolean Equal to the
--  five standard operators (see ropes.ads); a couple of extra "<="/
--  ">=" reflexivity checks are added since Rope.Mod itself never
--  exercised those two directly (only Compare/Equal existed there).

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

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Compare;
