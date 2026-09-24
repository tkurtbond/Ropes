--  Phase 7 checks: From_Unbounded_String/To_Unbounded_String. See
--  PLAN.md's phased plan and "Construction and concatenation" section
--  -- no Ropes.Mod counterpart at all (Oberon-2 has no unbounded string
--  type), so these scenarios are original: a round trip each way, plus
--  the empty-string edge case on each direction.

with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;
with Ropes;                 use Ropes;

procedure Test_Unbounded is

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
   Check
     (To_String (From_Unbounded_String (To_Unbounded_String ("hello world"))) = "hello world",
      "From_Unbounded_String round-trips an Unbounded_String's content");

   Check
     (Is_Empty (From_Unbounded_String (Null_Unbounded_String)), "From_Unbounded_String of an empty Unbounded_String is Null_Rope");

   Check (To_String (To_Unbounded_String (From_String ("hello world"))) = "hello world", "To_Unbounded_String: content");

   Check
     (Ada.Strings.Unbounded.Length (To_Unbounded_String (Null_Rope)) = 0,
      "To_Unbounded_String of Null_Rope is an empty Unbounded_String");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Unbounded;
