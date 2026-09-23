--  Phase 6 checks: Trim. See PLAN.md's phased plan and Testing
--  approach, and RopeTest.Mod's CheckTrim
--  (~/Repos/Oberon/oberon-tools/RopeTest.Mod) -- Rope.Mod's separate
--  TrimLeft/TrimRight/Trim collapse into this package's one Trim
--  function (see ropes.ads's doc comment); TrimLeft/TrimRight
--  translate to Trim called with the untouched side's set as
--  Ada.Strings.Maps.Null_Set. One extra check beyond RopeTest.Mod's
--  own scenarios uses a non-whitespace Character_Set, to exercise
--  that Trim's Left/Right are genuinely independent sets, not always
--  Whitespace -- something Rope.Mod's own TrimLeft/TrimRight/Trim
--  can't express at all (they only ever trim IsSpace).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Trim is

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
   declare
      R : constant Rope := From_String ("  hello world  ");
   begin
      Check (To_String (Trim (R, Right => Null_Set)) = "hello world  ", "Trim with only Left active (TrimLeft-equivalent)");
      Check (To_String (Trim (R, Left => Null_Set)) = "  hello world", "Trim with only Right active (TrimRight-equivalent)");
      Check (To_String (Trim (R)) = "hello world", "Trim (both sides, default Whitespace)");
   end;

   Check (Is_Empty (Trim (From_String ("   "))), "Trim of all-whitespace is Null_Rope");
   Check (Is_Empty (Trim (Null_Rope)), "Trim of Null_Rope is Null_Rope");
   Check (To_String (Trim (From_String ("no-trim-needed"))) = "no-trim-needed", "Trim leaves a rope with no padding unchanged");

   Check
     (To_String (Trim (From_String ("xxhelloxx"), Left => To_Set ('x'), Right => To_Set ('x'))) = "hello",
      "Trim with a non-whitespace Character_Set");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Trim;
