--  Phase 3 checks: Delete. See PLAN.md's phased plan and Testing
--  approach, and RopeTest.Mod's CheckRemove
--  (~/Repos/Oberon/Ropes/RopeTest.Mod), which this is sourced
--  from -- translated to 1-based inclusive From/Through (Ropes.Mod's
--  Remove takes a 0-based (pos, len) pair) and to
--  Ada.Strings.Index_Error where Ropes.Mod clamped a too-large From.
--  Delete's own "Through < From is always a no-op, even when From is
--  out of range" rule (matching Ada.Strings.Unbounded.Delete exactly
--  -- see ropes.ads) covers what Ropes.Mod's "clamps a too-large pos"
--  and "clamps a negative len" cases were separately testing; "clamps
--  a negative pos" has no equivalent at all, since From is Positive.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Delete is

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

   procedure Check_Index_Error (Source : Rope; From : Positive; Through : Natural; Name : String) is
   begin
      declare
         Unused : constant Rope := Delete (Source, From, Through);
      begin
         Check (False, Name);
      end;
   exception
      when Ada.Strings.Index_Error =>
         Check (True, Name);
   end Check_Index_Error;

   --  1h 2e 3l 4l 5o 6, 7space 8w 9o 10r 11l 12d
   R : constant Rope := From_String ("hello, world");

begin
   Check (To_String (Delete (R, 6, 7)) = "helloworld", "Delete from the middle");
   Check (To_String (Delete (R, 1, 7)) = "world", "Delete from the start");

   --  Ropes.Mod's Remove(r, pos, len) clamps a too-large len to
   --  Length(r) - pos; Ropes clamps Through the same way (unlike
   --  Slice's High, which raises Index_Error instead -- see
   --  ropes.ads's Delete comment for why they differ).
   Check (To_String (Delete (R, 6, 1_000)) = "hello", "Delete: Through past the end is clamped, not an error");

   Check (To_String (Delete (R, 101, 5)) = "hello, world", "Delete: Through < From is a no-op even when From is out of range");
   Check (To_String (Delete (R, 6, 5)) = "hello, world", "Delete: Through < From at a valid position is a no-op");

   Check (Is_Empty (Delete (R, 1, Length (R))), "Delete of the whole rope is Null_Rope");
   Check (Is_Empty (Delete (Null_Rope, 1, 5)), "Delete from Null_Rope is Null_Rope");

   Check (Length (Delete (R, 6, 7)) = 10, "Delete: resulting length");

   Check_Index_Error (R, 100, 105, "Delete: From past the end (with From <= Through) raises Index_Error");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Delete;
