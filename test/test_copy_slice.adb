--  Phase 15 checks: Copy_Slice, Rope.Mod's Blit. See PLAN.md's phased
--  plan and RopeTest.Mod's CheckBlit/CheckBlitAcrossLeaves
--  (~/Repos/Oberon/oberon-tools/RopeTest.Mod), whose scenarios these
--  translate: 1-based inclusive Low/High instead of Blit's 0-based
--  (srcStart, len), and Ada.Strings.Index_Error instead of HALT(1). The
--  oracle is the slice assignment Copy_Slice is documented as equal to,
--  Target (...) := To_String (Slice (Source, Low, High)).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ada.Unchecked_Deallocation;
with Ropes;            use Ropes;

procedure Test_Copy_Slice is

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

   Base : constant String (1 .. 200) := [for I in 1 .. 200 => Character'Val (Character'Pos ('a') + I mod 26)];

   --  True if Copy_Slice (Source, Low, High, Target, Target_Low), with a
   --  10-character Target, raises Ada.Strings.Index_Error and leaves
   --  Target unchanged.
   function Raises_Leaving_Unchanged (Source : Rope; Low : Positive; High : Natural; Target_Low : Positive) return Boolean is
      Target : String (1 .. 10) := [others => '#'];
   begin
      Copy_Slice (Source, Low, High, Target, Target_Low);
      return False;
   exception
      when Ada.Strings.Index_Error =>
         return Target = [1 .. 10 => '#'];
   end Raises_Leaving_Unchanged;

   procedure Check_Basics is
      Target : String (1 .. 11)  := "XXXXXXXXXXX";
      Offset : String (10 .. 20) := [others => '.'];
      Hello  : constant Rope     := From_String ("hello world");
   begin
      Copy_Slice (Hello, 7, 11, Target, 3);
      Check (Target = "XXworldXXXX", "Copy_Slice copies into the middle of Target without touching the rest");

      Copy_Slice (Hello, 1, 5, Offset, 16);
      Check (Offset = "......hello", "Copy_Slice: Target need not start at 1 (Target_Low indexes Target itself)");

      Target := "XXXXXXXXXXX";
      Copy_Slice (Hello, 1, 11, Target, 1);
      Check (Target = "hello world", "Copy_Slice of the whole rope into a Target of exactly its length");
   end Check_Basics;

   --  Every Low and High, across the leaf boundaries of a 17-character-leaf
   --  rope, against To_String (Slice (...)) -- including the empty ranges
   --  (High = Low - 1, from Low = 1 through Length + 1). Target has a
   --  sentinel on either side of the copied range, so copying one too
   --  many or too few characters is caught as well as copying the wrong
   --  ones.
   procedure Check_Every_Range is
      Source : constant Rope := Chunked (Base, 17);
      All_OK : Boolean       := True;
   begin
      for Low in 1 .. Base'Last + 1 loop
         for High in Low - 1 .. Base'Last loop
            declare
               Target : String (1 .. Base'Last + 2) := [others => '#'];
               N      : constant Natural            := High - Low + 1;
            begin
               Copy_Slice (Source, Low, High, Target, 2);
               All_OK :=
                 All_OK and then Target (1) = '#' and then Target (2 .. N + 1) = To_String (Slice (Source, Low, High))
                 and then Target (N + 2 .. Target'Last) = [N + 2 .. Target'Last => '#'];
            end;
         end loop;
      end loop;
      Check (All_OK, "Copy_Slice: every Low and High across leaf boundaries copies exactly Slice (Source, Low, High)");
   end Check_Every_Range;

   procedure Check_Errors is
      Hello : constant Rope := From_String ("hello");
   begin
      Check (Raises_Leaving_Unchanged (Hello, 7, 7, 1), "Copy_Slice: Low - 1 > Length (Source) raises Index_Error");
      Check (Raises_Leaving_Unchanged (Hello, 2, 6, 1), "Copy_Slice: High > Length (Source) raises Index_Error");
      Check
        (Raises_Leaving_Unchanged (Hello, 1, 5, 7),
         "Copy_Slice: a range that doesn't fit in Target raises Index_Error, Target unchanged");
      Check
        (Raises_Leaving_Unchanged (Hello, 1, 5, Positive'Last),
         "Copy_Slice: a Target_Low near Positive'Last raises Index_Error, not an overflow");

      declare
         Target : String (5 .. 9) := [others => '#'];
         OK     : Boolean         := False;
      begin
         begin
            Copy_Slice (Hello, 1, 5, Target, 4);
         exception
            when Ada.Strings.Index_Error =>
               OK := Target = [5 .. 9 => '#'];
         end;
         Check (OK, "Copy_Slice: Target_Low < Target'First raises Index_Error, Target unchanged");
      end;

      declare
         Target : String (1 .. 3) := "abc";
      begin
         Copy_Slice (Hello, 6, 5, Target, 1);  --  Low = Length + 1, High = Low - 1: empty, like Slice
         Copy_Slice (Hello, 3, 2, Target, 1_000);  --  An empty range needn't fit in Target.
         Copy_Slice (Null_Rope, 1, 0, Target, 1);
         Check (Target = "abc", "Copy_Slice of an empty range copies nothing and is not an error, as for Slice");
      end;
   end Check_Errors;

   --  Twenty million characters into a heap-allocated String: the slice
   --  assignment Copy_Slice replaces would build its To_String temporary
   --  on the stack, which overflows at this size.
   procedure Check_Large is
      type String_Access is access String;
      procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);
      Big    : constant Rope := 2_000_000 * From_String ("0123456789");
      Target : String_Access := new String (1 .. 20_000_000);
      All_OK : Boolean       := True;
   begin
      Copy_Slice (Big, 1, 20_000_000, Target.all, 1);
      for I in Target'Range loop
         All_OK := All_OK and then Target (I) = Character'Val (Character'Pos ('0') + (I - 1) mod 10);
      end loop;
      Check (All_OK, "Copy_Slice: a 20-million-character range into a heap-allocated String");
      Free (Target);
   end Check_Large;

begin
   Check_Basics;
   Check_Every_Range;
   Check_Errors;
   Check_Large;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Copy_Slice;
