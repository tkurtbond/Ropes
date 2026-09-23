--  Phase 3 checks: Slice. See PLAN.md's phased plan and Testing
--  approach, and RopeTest.Mod's CheckSubstring
--  (~/Repos/Oberon/oberon-tools/RopeTest.Mod), which this is sourced
--  from -- translated to inclusive 1-based Low/High (Rope.Mod's
--  Substring takes a 0-based (start, len) pair instead) and to
--  Ada.Strings.Index_Error where Rope.Mod clamped. Two of
--  CheckSubstring's cases have no equivalent here at all: Low is
--  Positive, so "a negative start" isn't a representable call, not
--  just a differently-handled one.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Slice is

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

   procedure Check_Index_Error (Source : Rope; Low : Positive; High : Natural; Name : String) is
   begin
      declare
         Unused : constant Rope := Slice (Source, Low, High);
      begin
         Check (False, Name);
      end;
   exception
      when Ada.Strings.Index_Error =>
         Check (True, Name);
   end Check_Index_Error;

   --  A real Concat node (16 + 10 > Short_Leaf_Length): left child is
   --  "0123456789012345" (16 chars), right child "abcdefghij" (10).
   R : constant Rope := From_String ("0123456789012345") & From_String ("abcdefghij");

begin
   Check (To_String (Slice (R, 1, Length (R))) = "0123456789012345abcdefghij", "Slice of the whole rope");

   Check (Is_Empty (Slice (R, 4, 3)), "Slice with High < Low is empty, not an error");

   --  Positions 11 .. 20 (1-based) span both children: "012345" (the
   --  last 6 of the left leaf) then "abcd" (the first 4 of the right).
   Check (To_String (Slice (R, 11, 20)) = "012345abcd", "Slice spanning two tree nodes");

   --  Rope.Mod's Substring(r, start, len) always clamps an
   --  over-length end to Length(r); Ropes does not -- see PLAN.md's
   --  "Access and slicing".
   Check_Index_Error (R, 21, 1_000, "Slice: High past the end raises Index_Error, not clamped");

   --  Low = Length (R) + 1 is the valid empty-slice-at-the-end
   --  boundary (Ada.Strings.Unbounded.Slice's own convention) --
   --  distinct from genuinely out-of-range, checked next.
   Check (Is_Empty (Slice (R, Length (R) + 1, Length (R))), "Slice: Low = Length + 1, High = Length is empty, not an error");

   Check_Index_Error (R, Length (R) + 2, Length (R) + 2, "Slice: Low past Length + 1 raises Index_Error");

   Check (Is_Empty (Slice (Null_Rope, 1, 0)), "Slice of Null_Rope at the valid empty boundary");
   Check_Index_Error (Null_Rope, 2, 2, "Slice of Null_Rope past the boundary raises Index_Error");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Slice;
