--  Phase 13 checks: Ropes.Stream_IO (Read/Write on a Stream_IO.File_Type,
--  Read_File/Write_File by name). See PLAN.md's phased plan. The claim to
--  check is "byte for byte": every one of the 256 Character values, CR,
--  form feed, and the presence or absence of a final line feed all
--  survive a round trip, which is exactly where Ropes.Text_IO (line-
--  oriented, like Ada.Text_IO) would not. Plus Read's 4096-character
--  chunk boundary and a rope far larger than one chunk.

with Ada.Characters.Latin_1;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;
with Ropes.Stream_IO;

procedure Test_Stream_IO is

   package SIO renames Ada.Streams.Stream_IO;
   package L1 renames Ada.Characters.Latin_1;

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

   Temp_Name : constant String := "test_stream_io.tmp";

   --  Every Character value, in order.
   function All_Bytes return String is
      S : String (1 .. 256);
   begin
      for I in S'Range loop
         S (I) := Character'Val (I - 1);
      end loop;
      return S;
   end All_Bytes;

   --  The file's size on disk, in bytes.
   function File_Size (Name : String) return Natural is (Natural (Ada.Directories.Size (Name)));

   procedure Check_Named is
      Tricky : constant Rope := From_String ("line one" & L1.CR & L1.LF & "form" & L1.FF & "feed" & L1.LF & "no final line feed");
   begin
      Ropes.Stream_IO.Write_File (Temp_Name, Tricky);
      Check (File_Size (Temp_Name) = Length (Tricky), "Write_File: the file is exactly Length (Item) bytes");
      Check
        (Ropes.Stream_IO.Read_File (Temp_Name) = Tricky, "Read_File: CR, form feed, and no final line feed survive a round trip");

      Ropes.Stream_IO.Write_File (Temp_Name, 3 * From_String (All_Bytes));
      Check
        (Ropes.Stream_IO.Read_File (Temp_Name) = 3 * From_String (All_Bytes),
         "Read_File/Write_File: all 256 Character values survive a round trip");

      Ropes.Stream_IO.Write_File (Temp_Name, Null_Rope);
      Check
        (File_Size (Temp_Name) = 0 and then Is_Empty (Ropes.Stream_IO.Read_File (Temp_Name)),
         "Write_File of Null_Rope makes an empty file; Read_File of it is Null_Rope");

      Ropes.Stream_IO.Write_File (Temp_Name, From_String ("a longer first version"));
      Ropes.Stream_IO.Write_File (Temp_Name, From_String ("short"));
      Check
        (Ropes.Stream_IO.Read_File (Temp_Name) = From_String ("short"),
         "Write_File replaces an existing file, not overwrites its start");

      Ada.Directories.Delete_File (Temp_Name);
      begin
         declare
            R : constant Rope := Ropes.Stream_IO.Read_File (Temp_Name);
         begin
            Check (False, "Read_File of a missing file raises Name_Error (got length" & Length (R)'Image & ")");
         end;
      exception
         when Ada.IO_Exceptions.Name_Error =>
            Check (True, "Read_File of a missing file raises Name_Error");
      end;
   end Check_Named;

   procedure Check_Boundaries is
      Sizes  : constant array (Positive range <>) of Natural := [1, 4_095, 4_096, 4_097, 8_192, 8_193, 100_000];
      All_OK : Boolean                                       := True;
   begin
      for N of Sizes loop
         Ropes.Stream_IO.Write_File (Temp_Name, N * 'z');
         declare
            Back : constant Rope := Ropes.Stream_IO.Read_File (Temp_Name);
         begin
            if Back /= N * 'z' then
               Put_Line ("  file of" & N'Image & " bytes read back as" & Length (Back)'Image);
               All_OK := False;
            end if;
         end;
      end loop;
      Ada.Directories.Delete_File (Temp_Name);
      Check (All_OK, "Read_File: files of 1, 4095..4097, 8192, 8193, 100000 bytes each read back exactly");
   end Check_Boundaries;

   procedure Check_File_Type is
      F : SIO.File_Type;
   begin
      SIO.Create (F, SIO.Out_File, Temp_Name);
      Ropes.Stream_IO.Write (F, From_String ("first,"));
      Ropes.Stream_IO.Write (F, From_String ("second"));
      SIO.Close (F);
      Check
        (Ropes.Stream_IO.Read_File (Temp_Name) = From_String ("first,second"),
         "Write: successive writes append at the current position");

      SIO.Open (F, SIO.In_File, Temp_Name);
      SIO.Set_Index (F, 7);
      Check (Ropes.Stream_IO.Read (F) = From_String ("second"), "Read: reads from the current position to the end");
      Check (Is_Empty (Ropes.Stream_IO.Read (F)), "Read at end of file is Null_Rope");
      SIO.Close (F);
      Ada.Directories.Delete_File (Temp_Name);
   end Check_File_Type;

   --  Twenty million characters, far more than one chunk.
   procedure Check_Large is
      Big : constant Rope := 2_000_000 * From_String ("0123456789");
   begin
      Ropes.Stream_IO.Write_File (Temp_Name, Big);
      Check
        (File_Size (Temp_Name) = 20_000_000 and then Ropes.Stream_IO.Read_File (Temp_Name) = Big,
         "Write_File/Read_File: a 20-million-character rope round-trips");
      Ada.Directories.Delete_File (Temp_Name);
   end Check_Large;

begin
   Check_Named;
   Check_Boundaries;
   Check_File_Type;
   Check_Large;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Stream_IO;
