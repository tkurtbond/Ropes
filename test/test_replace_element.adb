--  Phase 23 checks: Replace_Element, Ada.Strings.Unbounded's own, as a
--  function. No Ropes.Mod counterpart. The oracle is
--  Ada.Strings.Unbounded.Replace_Element (a procedure) on the same
--  text, over a rope of 9-character leaves (9 + 9 > 16, the short-leaf
--  merge threshold, so they stay separate) and one built by "*", whose
--  subtrees are shared.

with Ada.Command_Line;      use Ada.Command_Line;
with Ada.Strings;           use Ada.Strings;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;           use Ada.Text_IO;
with Ropes;                 use Ropes;
with Ropes.Test_Support;

procedure Test_Replace_Element is

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

   --  Source in 9-character leaves.
   function Chunked (Source : String) return Rope is
      Result : Rope;
      I      : Positive := Source'First;
   begin
      while I <= Source'Last loop
         Result := Result & From_String (Source (I .. Natural'Min (I + 8, Source'Last)));
         I      := I + 9;
      end loop;
      return Result;
   end Chunked;

   Text   : constant String := "The quick brown fox jumps over the lazy dog, 0123456789.";
   Chunks : constant Rope   := Chunked (Text);

   function Raises_Index_Error (Source : Rope; Index : Positive) return Boolean is
      Unused : Rope;
   begin
      Unused := Replace_Element (Source, Index, '#');
      return False;
   exception
      when Index_Error =>
         return True;
   end Raises_Index_Error;

   All_Agree : Boolean := True;

   Period  : constant String := "abc,xyz;";
   Starred : constant Rope   := 1_000 * Chunked (Period);
   Changed : constant Rope   := Replace_Element (Starred, 4_004, '!');
begin
   Check (To_String (Chunks) = Text, "the test rope has the expected text");
   Check
     (To_String (Replace_Element (Chunks, 5, 'Q')) = "The Quick brown fox jumps over the lazy dog, 0123456789.",
      "Replace_Element: one character");

   for I in Text'Range loop
      declare
         Want : Unbounded_String := To_Unbounded_String (Text);
      begin
         Replace_Element (Want, I, '#');
         if To_String (Replace_Element (Chunks, I, '#')) /= To_String (Want) then
            All_Agree := False;
            Put_Line ("  disagrees at Index =" & I'Image);
         end if;
      end;
   end loop;
   Check (All_Agree, "every Index, across leaves, agrees with Ada.Strings.Unbounded.Replace_Element");

   Check (Replace_Element (Chunks, 1, 'T') = Chunks, "replacing a character with itself leaves the text unchanged");
   Check (To_String (Chunks) = Text, "Source itself is unchanged (Rope is immutable)");
   Check
     (Raises_Index_Error (Chunks, Text'Last + 1) and then not Raises_Index_Error (Chunks, Text'Last),
      "Index past the end raises Index_Error -- it never appends, unlike Overwrite");
   Check (Raises_Index_Error (Null_Rope, 1), "Null_Rope: any Index raises Index_Error");
   Check
     (Length (Changed) = 8_000 and then Element (Changed, 4_004) = '!' and then Slice (Changed, 4_001, 4_008) = "abc!xyz;"
      and then Slice (Changed, 1, 4_000) = Slice (Starred, 1, 4_000)
      and then Slice (Changed, 4_009, 8_000) = Slice (Starred, 4_009, 8_000),
      "a ""*""-built rope, whose subtrees are shared: only the one character changes");
   Check (Ropes.Test_Support.Depth (Changed) <= Ropes.Test_Support.Depth (Starred) + 4, "the result's depth stays near Source's");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Replace_Element;
