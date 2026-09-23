--  Phase 8 checks: Overwrite. See PLAN.md's phased plan and "Deferred
--  / stretch" section -- no Rope.Mod counterpart (Oberon-2's Rope has
--  no positional-replace operation), so these scenarios are original,
--  written directly against Ada.Strings.Unbounded.Overwrite's own
--  documented semantics (verified from GNAT's a-strunb.ads, not
--  assumed): replacing in place without extending, replacing and
--  extending past the current end, a pure append at Position = Length
--  (Source) + 1, and the Ada.Strings.Index_Error boundary.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Overwrite is

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

   procedure Check_Index_Error (Source : Rope; Position : Positive; New_Item : Rope; Name : String) is
   begin
      declare
         Unused : constant Rope := Overwrite (Source, Position, New_Item);
      begin
         Check (False, Name);
      end;
   exception
      when Ada.Strings.Index_Error =>
         Check (True, Name);
   end Check_Index_Error;

begin
   Check
     (To_String (Overwrite (From_String ("abcdef"), 2, From_String ("XY"))) = "aXYdef",
      "Overwrite in the middle, with unchanged characters left over on both sides");

   Check
     (To_String (Overwrite (From_String ("hello world"), 7, From_String ("there"))) = "hello there",
      "Overwrite reaching exactly to the end leaves nothing left over");

   Check
     (To_String (Overwrite (From_String ("hi"), 2, From_String ("ello"))) = "hello",
      "Overwrite extends Source when New_Item runs past the current end");

   Check
     (To_String (Overwrite (From_String ("abc"), 4, From_String ("def"))) = "abcdef",
      "Overwrite at Position = Length (Source) + 1 is a pure append");

   Check
     (To_String (Overwrite (From_String ("abcdef"), 3, Null_Rope)) = "abcdef", "Overwrite with an empty New_Item changes nothing");

   Check_Index_Error
     (From_String ("abc"), 5, From_String ("x"), "Overwrite raises Index_Error when Position - 1 > Length (Source)");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Overwrite;
