--  Phase 6 checks: Map/Map_Indexed. See PLAN.md's phased plan and
--  Testing approach, and RopeTest.Mod's CheckMap
--  (~/Repos/Oberon/Ropes/RopeTest.Mod), which this is sourced
--  from -- ShiftMapper translates directly; IndexDigitMapper's index
--  arithmetic is adjusted from Ropes.Mod's 0-based "i MOD 10" to
--  "(Index - 1) mod 10" for Map_Indexed's 1-based Index, so it still
--  produces the same expected string ("0123456789...").

with Ada.Command_Line;   use Ada.Command_Line;
with Ada.Text_IO;        use Ada.Text_IO;
with Ropes;              use Ropes;
with Ropes.Test_Support; use Ropes.Test_Support;

procedure Test_Map is

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

   function Shift_Char (Ch : Character) return Character is (Character'Val (Character'Pos (Ch) + 1));

   function Index_Digit (Index : Positive; Ch : Character) return Character is
      pragma Unreferenced (Ch);
   begin
      return Character'Val (Character'Pos ('0') + (Index - 1) mod 10);
   end Index_Digit;

begin
   Check (To_String (Map (From_String ("abc"), Shift_Char'Access)) = "bcd", "Map shifts every character");
   Check (Is_Empty (Map (Null_Rope, Shift_Char'Access)), "Map of Null_Rope is Null_Rope");

   declare
      --  Two tree nodes (left leaf is 16 chars, Short_Leaf_Length),
      --  so Map_Indexed's threaded index has to survive the
      --  recursion into the right child.
      R      : constant Rope := From_String ("0123456789012345") & From_String ("abcdefghij");
      Mapped : Rope;
   begin
      Mapped := Map (R, Shift_Char'Access);
      Check (Depth (Mapped) = Depth (R), "Map preserves tree shape (same Depth)");

      Mapped := Map_Indexed (R, Index_Digit'Access);
      Check (To_String (Mapped) = "01234567890123456789012345", "Map_Indexed: index threads correctly across a Concat node");
   end;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Map;
