--  Phase 8 checks: Head/Tail. See PLAN.md's phased plan and "Deferred
--  / stretch" section -- no Rope.Mod counterpart, so these scenarios
--  are original, written directly against
--  Ada.Strings.Unbounded.Head/Tail's own documented semantics
--  (verified from GNAT's a-strunb.ads, not assumed): cutting Source
--  down, padding it out past its own length (default Pad and an
--  explicit one), and the Source = Null_Rope / Count = 0 boundaries.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Head_Tail is

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
   Check (To_String (Head (From_String ("hello"), 3)) = "hel", "Head cuts Source down when Count <= Length (Source)");
   Check (To_String (Head (From_String ("hi"), 5)) = "hi   ", "Head pads with the default Space when Count > Length (Source)");
   Check (To_String (Head (From_String ("hi"), 5, '*')) = "hi***", "Head pads with an explicit Pad character");
   Check (To_String (Head (Null_Rope, 3)) = "   ", "Head of Null_Rope is all padding");
   Check (Is_Empty (Head (From_String ("hello"), 0)), "Head with Count = 0 is Null_Rope");

   Check (To_String (Tail (From_String ("hello"), 3)) = "llo", "Tail cuts Source down when Count <= Length (Source)");
   Check (To_String (Tail (From_String ("hi"), 5)) = "   hi", "Tail pads with the default Space when Count > Length (Source)");
   Check (To_String (Tail (From_String ("hi"), 5, '*')) = "***hi", "Tail pads with an explicit Pad character");
   Check (To_String (Tail (Null_Rope, 3)) = "   ", "Tail of Null_Rope is all padding");
   Check (Is_Empty (Tail (From_String ("hello"), 0)), "Tail with Count = 0 is Null_Rope");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Head_Tail;
