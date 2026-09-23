package body Ropes.Text_IO is

   --  Get_Line's read size: each full buffer becomes one leaf of the
   --  result. Larger than GNAT's own Unbounded_IO buffer (1000) since
   --  here it also sets the leaf size of every long line read.
   Buffer_Size : constant := 4_096;

   procedure Put (File : Ada.Text_IO.File_Type; Item : Rope) is
      procedure Put_Chunk (Chunk : String) is
      begin
         Ada.Text_IO.Put (File, Chunk);
      end Put_Chunk;
   begin
      Process_Chunks (Item, Put_Chunk'Access);
   end Put;

   procedure Put (Item : Rope) is
   begin
      Put (Ada.Text_IO.Current_Output, Item);
   end Put;

   procedure Put_Line (File : Ada.Text_IO.File_Type; Item : Rope) is
   begin
      Put (File, Item);
      Ada.Text_IO.New_Line (File);
   end Put_Line;

   procedure Put_Line (Item : Rope) is
   begin
      Put_Line (Ada.Text_IO.Current_Output, Item);
   end Put_Line;

   --  Same loop as GNAT's own Unbounded_IO.Get_Line: Ada.Text_IO.Get_Line
   --  stops either at a line terminator (which it skips) or when Buffer
   --  fills (which it doesn't), so Last = Buffer'Last means "maybe more
   --  of this line to come" -- keep reading until a short read. A line
   --  of exactly a multiple of Buffer_Size ends with one extra zero-length
   --  read, which is what consumes its terminator.
   function Get_Line (File : Ada.Text_IO.File_Type) return Rope is
      Buffer : String (1 .. Buffer_Size);
      Last   : Natural;
      Result : Rope;
   begin
      loop
         Ada.Text_IO.Get_Line (File, Buffer, Last);
         Result := Result & From_String (Buffer (1 .. Last));
         exit when Last < Buffer'Last;
      end loop;
      return Result;
   end Get_Line;

   function Get_Line return Rope is (Get_Line (Ada.Text_IO.Current_Input));

   procedure Get_Line (File : Ada.Text_IO.File_Type; Item : out Rope) is
   begin
      Item := Get_Line (File);
   end Get_Line;

   procedure Get_Line (Item : out Rope) is
   begin
      Item := Get_Line (Ada.Text_IO.Current_Input);
   end Get_Line;

end Ropes.Text_IO;
