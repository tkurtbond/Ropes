--  Phase 7 checks: From_Character and the Character/String "&"
--  overloads. See PLAN.md's phased plan and "Construction and
--  concatenation" section. These have no direct RopeTest.Mod
--  counterpart to translate scenarios from -- Oberon-2 has no operator
--  overloading, so Rope.Mod's FromChar is the only piece with a real
--  precedent (RopeTest.Mod's CheckFromCharAndMake); the four "&"
--  overloads are pure Ada idiom (Ada.Strings.Unbounded's own "&"
--  suite), so their checks are original, covering each overload's
--  content and its Null_Rope-operand edge case once each.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Concat_Overloads is

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
   Check (To_String (From_Character ('x')) = "x", "From_Character builds a one-character Rope");
   Check (Length (From_Character ('x')) = 1, "From_Character: length");

   Check (To_String (From_String ("ab") & 'c') = "abc", """&"" (Rope, Character)");
   Check (To_String (Null_Rope & 'c') = "c", """&"" (Rope, Character) with a Null_Rope Left");

   Check (To_String ('a' & From_String ("bc")) = "abc", """&"" (Character, Rope)");
   Check (To_String ('a' & Null_Rope) = "a", """&"" (Character, Rope) with a Null_Rope Right");

   Check (To_String (From_String ("ab") & "cd") = "abcd", """&"" (Rope, String)");
   Check (To_String (Null_Rope & "cd") = "cd", """&"" (Rope, String) with a Null_Rope Left");
   Check (To_String (From_String ("ab") & "") = "ab", """&"" (Rope, String) with an empty String Right");

   Check (To_String ("ab" & From_String ("cd")) = "abcd", """&"" (String, Rope)");
   Check (To_String ("" & From_String ("cd")) = "cd", """&"" (String, Rope) with an empty String Left");
   Check (To_String ("ab" & Null_Rope) = "ab", """&"" (String, Rope) with a Null_Rope Right");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Concat_Overloads;
