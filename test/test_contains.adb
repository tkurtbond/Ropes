--  Phase 8 checks: Contains, all four overloads. See PLAN.md's phased
--  plan, "Search" section, and the "Open questions" note that floated
--  Contains as a plausible thin wrapper over Index (...) /= 0.
--  Ropes.Mod's own Contains (Character pattern, with From, always
--  Forward) is the direct model for the Character/From overload; the
--  Rope-pattern and no-From overloads have no Ropes.Mod counterpart at
--  all, so those scenarios are original. The last check confirms
--  Contains is genuinely a thin wrapper: it inherits Index's own
--  Ada.Strings.Pattern_Error on a Null_Rope Pattern rather than
--  softening it.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Contains is

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

   procedure Check_Pattern_Error (Source, Pattern : Rope; Name : String) is
   begin
      declare
         Unused : constant Boolean := Contains (Source, Pattern);
      begin
         Check (False, Name);
      end;
   exception
      when Ada.Strings.Pattern_Error =>
         Check (True, Name);
   end Check_Pattern_Error;

   R : constant Rope := From_String ("hello world");

begin
   Check (Contains (R, From_String ("world")), "Contains (Rope, Rope): pattern present");
   Check (not Contains (R, From_String ("xyz")), "Contains (Rope, Rope): pattern absent");

   Check
     (Contains (From_String ("ababab"), From_String ("ab"), 3), "Contains (Rope, Rope, From): pattern present at or after From");
   Check
     (not Contains (From_String ("ababab"), From_String ("ab"), 6), "Contains (Rope, Rope, From): pattern absent at or after From");

   Check (Contains (R, 'w'), "Contains (Rope, Character): pattern present");
   Check (not Contains (R, 'z'), "Contains (Rope, Character): pattern absent");

   Check (Contains (From_String ("hello"), 'l', 4), "Contains (Rope, Character, From): pattern present at or after From");
   Check (not Contains (From_String ("hello"), 'l', 5), "Contains (Rope, Character, From): pattern absent at or after From");

   Check_Pattern_Error (R, Null_Rope, "Contains (Rope, Rope) with a Null_Rope Pattern raises Pattern_Error, inherited from Index");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Contains;
