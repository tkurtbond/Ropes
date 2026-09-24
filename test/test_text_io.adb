--  Phase 11 checks: Process_Chunks and Ropes.Text_IO (Put/Put_Line/
--  Get_Line). See PLAN.md's phased plan. No RopeTest.Mod counterpart to
--  source these from (Ropes.Mod has no output operations) -- the
--  scenarios target this phase's own claims instead: chunks concatenate
--  to To_String, a rope far larger than the stack round-trips through a
--  file, and Get_Line handles lines around its internal 4096-character
--  buffer boundary (the one place an off-by-one would hide), matching
--  Ada.Text_IO.Unbounded_IO.Get_Line's own semantics.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;
with Ropes.Text_IO;

procedure Test_Text_IO is

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

   --  A rope with many leaves: "&" only merges short leaves, so 50-char
   --  pieces stay separate.
   function Many_Leaves return Rope is
      R : Rope;
   begin
      for I in 1 .. 200 loop
         R := R & From_String ([1 .. 50 => Character'Val (Character'Pos ('a') + I mod 26)]);
      end loop;
      return R;
   end Many_Leaves;

   procedure Check_Process_Chunks is
      Calls     : Natural := 0;
      Empty     : Boolean := False;
      Collected : Rope;

      procedure Count (Chunk : String) is
      begin
         Calls := Calls + 1;
         Empty := Empty or else Chunk'Length = 0;
      end Count;

      procedure Collect (Chunk : String) is
      begin
         Collected := Collected & From_String (Chunk);
         Calls     := Calls + 1;
      end Collect;

      R : Rope := Many_Leaves;

      --  Drops the caller's own reference to the rope being walked.
      procedure Clobber (Chunk : String) is
      begin
         R         := Null_Rope;
         Collected := Collected & From_String (Chunk);
      end Clobber;

      --  Built separately, not copied from R: a copy would share R's tree
      --  and keep it alive, hiding the hazard Clobber is checking for.
      Expected : constant Rope := Many_Leaves;
   begin
      Process_Chunks (Null_Rope, Count'Access);
      Check (Calls = 0, "Process_Chunks: never calls Process for Null_Rope");

      Process_Chunks (R, Count'Access);
      Check (Calls > 1, "Process_Chunks: a many-leaf rope arrives as more than one chunk");
      Check (not Empty, "Process_Chunks: never passes an empty chunk");

      Calls := 0;
      Process_Chunks (R, Collect'Access);
      Check (Collected = R and then To_String (Collected) = To_String (R), "Process_Chunks: chunks concatenate to To_String");

      Collected := Null_Rope;
      Process_Chunks (From_String ("x"), Collect'Access);
      Check (To_String (Collected) = "x", "Process_Chunks: a one-leaf rope is one chunk");

      --  Process assigning to the very variable passed as Source must not
      --  free the tree mid-walk (run under valgrind to see a failure here).
      Collected := Null_Rope;
      Process_Chunks (R, Clobber'Access);
      Check (Collected = Expected and then Is_Empty (R), "Process_Chunks: survives Process dropping the caller's reference");
   end Check_Process_Chunks;

   procedure Check_Put is
      F : File_Type;
      R : constant Rope := Many_Leaves;
   begin
      Create (F);   --  Anonymous temporary file, deleted on Close.
      Ropes.Text_IO.Put (F, R);
      Ropes.Text_IO.Put (F, From_String ("|tail"));
      New_Line (F);
      Ropes.Text_IO.Put_Line (F, From_String ("second"));
      Ropes.Text_IO.Put_Line (F, Null_Rope);
      Ropes.Text_IO.Put_Line (F, From_String ("fourth"));
      Reset (F, In_File);
      Check (Get_Line (F) = To_String (R) & "|tail", "Put: writes the same characters as Put (To_String (R))");
      Check (Get_Line (F) = "second", "Put_Line: writes the rope, then a line terminator");
      Check (Get_Line (F) = "", "Put_Line of Null_Rope writes an empty line");
      Check (Get_Line (F) = "fourth" and then End_Of_File (F), "Put_Line: nothing extra written");
      Close (F);
   end Check_Put;

   procedure Check_Current_Output_Input is
      F : File_Type;
   begin
      Create (F);
      Set_Output (F);
      Ropes.Text_IO.Put (From_String ("via "));
      Ropes.Text_IO.Put_Line (From_String ("Current_Output"));
      Ropes.Text_IO.Put_Line (From_String ("line two"));
      Set_Output (Standard_Output);
      Reset (F, In_File);
      Set_Input (F);
      Check
        (To_String (Ropes.Text_IO.Get_Line) = "via Current_Output",
         "Put/Put_Line/Get_Line: no-File overloads use Current_Output/Input");
      declare
         Item : Rope;
      begin
         Ropes.Text_IO.Get_Line (Item);
         Check (To_String (Item) = "line two", "Get_Line: procedure form, Current_Input");
      end;
      Set_Input (Standard_Input);
      Close (F);
   end Check_Current_Output_Input;

   procedure Check_Get_Line_Boundaries is
      Lengths : constant array (Positive range <>) of Natural := [0, 1, 4_095, 4_096, 4_097, 8_191, 8_192, 8_193, 100_000];
      F       : File_Type;
      All_OK  : Boolean                                       := True;

      function Line_Of (N : Natural) return Rope is (N * 'q');
   begin
      Create (F);
      for N of Lengths loop
         Ropes.Text_IO.Put_Line (F, Line_Of (N));
      end loop;
      Reset (F, In_File);
      for N of Lengths loop
         declare
            Item : Rope;
         begin
            Ropes.Text_IO.Get_Line (F, Item);
            if Item /= Line_Of (N) then
               Put_Line ("  line of length" & N'Image & " read back with length" & Length (Item)'Image);
               All_OK := False;
            end if;
         end;
      end loop;
      Check (All_OK, "Get_Line: lines of length 0, 1, 4095..4097, 8191..8193, 100000 each read back exactly");
      Check (End_Of_File (F), "Get_Line: End_Of_File after reading every line back");
      begin
         declare
            Extra : constant Rope := Ropes.Text_IO.Get_Line (F);
         begin
            Check (False, "Get_Line at end of file raises End_Error (got length" & Length (Extra)'Image & ")");
         end;
      exception
         when End_Error =>
            Check (True, "Get_Line at end of file raises End_Error");
      end;
      Close (F);

      --  The last line exactly fills the buffer, with no trailing
      --  terminator in the file at all.
      Create (F);
      Ropes.Text_IO.Put (F, Line_Of (4_096));
      Reset (F, In_File);
      Check (Ropes.Text_IO.Get_Line (F) = Line_Of (4_096), "Get_Line: an unterminated last line of exactly 4096 characters");
      Close (F);
   end Check_Get_Line_Boundaries;

   --  20 million characters: far bigger than the default 8 MB stack that
   --  To_String would build its copy on, so this only works if Put and
   --  Get_Line really never flatten the rope.
   procedure Check_Huge is
      Big : constant Rope := 2_000_000 * From_String ("0123456789");
      F   : File_Type;
   begin
      Create (F);
      Ropes.Text_IO.Put_Line (F, Big);
      Reset (F, In_File);
      declare
         Back : constant Rope := Ropes.Text_IO.Get_Line (F);
      begin
         Check (Length (Back) = 20_000_000 and then Back = Big, "Put_Line/Get_Line: a 20-million-character rope round-trips");
      end;
      Close (F);
   end Check_Huge;

begin
   Check_Process_Chunks;
   Check_Put;
   Check_Current_Output_Input;
   Check_Get_Line_Boundaries;
   Check_Huge;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Text_IO;
