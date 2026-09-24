--  Phase 7 checks: Escape. See PLAN.md's phased plan and "Case
--  mapping"/escaping design notes, and RopeTest.Mod's CheckEscaped
--  (~/Repos/Oberon/Ropes/RopeTest.Mod), which this is sourced
--  from -- Ropes.Mod's Escaped renamed Escape (see ropes.ads's doc
--  comment). One extra check beyond RopeTest.Mod's own scenarios
--  exercises the \NNN three-digit-decimal-code form for a
--  non-printable character outside the five two-character escapes,
--  which none of RopeTest.Mod's own scenarios happen to cover.

with Ada.Characters.Latin_1;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Escape is

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
   Check (To_String (Escape (From_String ("say ""hi"""))) = "say \""hi\""", "Escape: double quote");
   Check (To_String (Escape (From_Character ('a') & Ada.Characters.Latin_1.HT)) = "a\t", "Escape: tab");
   Check (To_String (Escape (From_Character ('\'))) = "\\", "Escape: backslash");
   Check (Is_Empty (Escape (Null_Rope)), "Escape of Null_Rope is Null_Rope");

   Check
     (To_String (Escape (From_Character (Ada.Characters.Latin_1.NUL))) = "\000",
      "Escape: a non-printable character outside the five two-character escapes uses \\NNN");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Escape;
