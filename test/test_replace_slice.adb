--  Phase 17 checks: Replace_Slice, Ada.Strings.Unbounded.Replace_Slice's
--  function form. No Ropes.Mod counterpart. The oracle is
--  Ada.Strings.Fixed.Replace_Slice, whose semantics
--  Ada.Strings.Unbounded's are defined by (RM A.4.5), run over every
--  Low/High pair around a rope of several leaves -- including the
--  Index_Error cases, which must raise exactly when Fixed's does.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Replace_Slice is

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

   --  Source split into leaves of Size characters each (Size > 16, the
   --  short-leaf merge threshold, so "&" keeps them as separate leaves).
   function Chunked (Source : String; Size : Positive) return Rope is
      Result : Rope;
      I      : Positive := Source'First;
   begin
      while I <= Source'Last loop
         Result := Result & From_String (Source (I .. Natural'Min (I + Size - 1, Source'Last)));
         I      := I + Size;
      end loop;
      return Result;
   end Chunked;

   Base : constant String (1 .. 40) := [for I in 1 .. 40 => Character'Val (Character'Pos ('a') + I mod 26)];

   Chunks : constant Rope := Chunked (Base, 17);

   --  Whether Replace_Slice (Chunks, Low, High, By) agrees with
   --  Ada.Strings.Fixed.Replace_Slice (Base, Low, High, By): the same
   --  result, or both raising Index_Error.
   function Agrees_At (Low : Positive; High : Natural; By : String) return Boolean is
   begin
      declare
         Expected : constant String := Ada.Strings.Fixed.Replace_Slice (Base, Low, High, By);
      begin
         return To_String (Replace_Slice (Chunks, Low, High, By)) = Expected;
      exception
         when Ada.Strings.Index_Error =>
            return False;  --  Only Ropes raised.
      end;
   exception
      when Ada.Strings.Index_Error =>
         --  Fixed raised; Ropes must too.
         declare
            Unused : Rope;
         begin
            Unused := Replace_Slice (Chunks, Low, High, By);
            return False;
         exception
            when Ada.Strings.Index_Error =>
               return True;
         end;
   end Agrees_At;

   --  Agrees_At for every Low in 1 .. Base'Last + 2 and High in 0 ..
   --  Base'Last + 2.
   function Agrees_With_Fixed (By : String) return Boolean is
   begin
      for Low in 1 .. Base'Last + 2 loop
         for High in 0 .. Base'Last + 2 loop
            if not Agrees_At (Low, High, By) then
               Put_Line ("  disagrees at Low =" & Low'Image & ", High =" & High'Image);
               return False;
            end if;
         end loop;
      end loop;
      return True;
   end Agrees_With_Fixed;

   function Raises (Source : Rope; Low : Positive; High : Natural) return Boolean is
      Unused : Rope;
   begin
      Unused := Replace_Slice (Source, Low, High, "x");
      return False;
   exception
      when Ada.Strings.Index_Error =>
         return True;
   end Raises;

   R : constant Rope := From_String ("hello world");

begin
   Check (To_String (Replace_Slice (R, 7, 11, "there")) = "hello there", "replace the end");
   Check (To_String (Replace_Slice (R, 1, 5, "goodbye")) = "goodbye world", "replace the start, longer By");
   Check (To_String (Replace_Slice (R, 6, 6, "")) = "helloworld", "empty By deletes");
   Check (To_String (Replace_Slice (R, 3, 2, "XX")) = "heXXllo world", "High < Low inserts before Low");
   Check (To_String (Replace_Slice (R, 12, 0, "!")) = "hello world!", "High < Low at Length + 1 appends");
   Check (To_String (Replace_Slice (R, 2, 99, "X")) = "hX", "High past the end is clamped");
   Check (Raises (R, 13, 20) and then Raises (R, 13, 0), "Low past Length + 1 raises Index_Error, either way round");
   Check (To_String (Replace_Slice (Null_Rope, 1, 0, "new")) = "new", "into Null_Rope");
   Check (Replace_Slice (R, 7, 11, From_String ("there")) = Replace_Slice (R, 7, 11, "there"), "Rope By = String By");
   Check (Agrees_With_Fixed ("") and then Agrees_With_Fixed ("XYZ") and then Agrees_With_Fixed (Base (1 .. 20)),
          "every Low/High across leaves agrees with Ada.Strings.Fixed.Replace_Slice");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Replace_Slice;
