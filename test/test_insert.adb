--  Phase 3 checks: Insert. See PLAN.md's phased plan and Testing
--  approach, and RopeTest.Mod's CheckInsert
--  (~/Repos/Oberon/Ropes/RopeTest.Mod), which this is sourced
--  from -- translated to 1-based Before (Ropes.Mod's Insert takes a
--  0-based pos; Oberon pos N = our Before N + 1) and to
--  Ada.Strings.Index_Error where Ropes.Mod clamped. One of
--  CheckInsert's cases has no equivalent here: Before is Positive, so
--  "a negative pos" isn't a representable call, not just a
--  differently-handled one.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Insert is

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

   procedure Check_Index_Error (Source : Rope; Before : Positive; New_Item : Rope; Name : String) is
   begin
      declare
         Unused : constant Rope := Insert (Source, Before, New_Item);
      begin
         Check (False, Name);
      end;
   exception
      when Ada.Strings.Index_Error =>
         Check (True, Name);
   end Check_Index_Error;

   R : constant Rope := From_String ("hello world");

begin
   Check (To_String (Insert (R, 6, From_String (","))) = "hello, world", "Insert in the middle");
   Check (To_String (Insert (R, 1, From_String (">> "))) = ">> hello world", "Insert at the start");
   Check (To_String (Insert (R, 12, From_String ("!"))) = "hello world!", "Insert at the end (Before = Length + 1)");

   Check (To_String (Insert (Null_Rope, 1, From_String ("x"))) = "x", "Insert into Null_Rope is just the inserted rope");
   Check (To_String (Insert (R, 6, Null_Rope)) = "hello world", "Insert of Null_Rope leaves the rope unchanged");
   Check (Is_Empty (Insert (Null_Rope, 1, Null_Rope)), "Insert of Null_Rope into Null_Rope is Null_Rope");

   Check (Length (Insert (R, 6, From_String (","))) = 12, "Insert: resulting length");

   Check_Index_Error (R, 101, From_String ("!"), "Insert: Before past the end raises Index_Error, not clamped");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Insert;
