--  Phase 6 checks: To_Upper/To_Lower/Capitalize/Uncapitalize. See
--  PLAN.md's phased plan and Testing approach, and RopeTest.Mod's
--  CheckAsciiCase (~/Repos/Oberon/Ropes/RopeTest.Mod) --
--  UppercaseAscii/LowercaseAscii/CapitalizeAscii/UncapitalizeAscii
--  translate directly to To_Upper/To_Lower/Capitalize/Uncapitalize
--  (see ropes.ads's doc comment for the renaming). A couple of extra
--  one-character-rope checks are added beyond RopeTest.Mod's own
--  scenarios, to lock in the Length (Source) = 1 boundary (where
--  Capitalize/Uncapitalize's "rest of the rope" is Slice (Source, 2,
--  1) -- High < Low, empty, not an error).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Case is

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
   Check (To_String (To_Upper (From_String ("Hello, World! 123"))) = "HELLO, WORLD! 123", "To_Upper");
   Check (To_String (To_Lower (From_String ("Hello, World! 123"))) = "hello, world! 123", "To_Lower");
   Check (To_String (Capitalize (From_String ("hello"))) = "Hello", "Capitalize");
   Check (To_String (Uncapitalize (From_String ("Hello"))) = "hello", "Uncapitalize");
   Check (Is_Empty (Capitalize (Null_Rope)), "Capitalize of Null_Rope is Null_Rope");
   Check (Is_Empty (Uncapitalize (Null_Rope)), "Uncapitalize of Null_Rope is Null_Rope");

   Check (To_String (Capitalize (From_String ("a"))) = "A", "Capitalize of a one-character rope");
   Check (To_String (Uncapitalize (From_String ("A"))) = "a", "Uncapitalize of a one-character rope");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Case;
