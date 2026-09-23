with Ada.Streams;

package body Ropes.Stream_IO is

   use Ada.Streams;
   use Ada.Streams.Stream_IO;

   --  Read's chunk size: each full chunk becomes one leaf of the result.
   --  Same as Ropes.Text_IO.Get_Line's.
   Chunk_Size : constant := 4_096;

   function Read (File : Ada.Streams.Stream_IO.File_Type) return Rope is
      Buffer : Stream_Element_Array (1 .. Chunk_Size);
      Last   : Stream_Element_Offset;
      Result : Rope;
   begin
      while not End_Of_File (File) loop
         Read (File, Buffer, Last);
         declare
            Chunk : String (1 .. Natural (Last));
         begin
            for I in Chunk'Range loop
               Chunk (I) := Character'Val (Buffer (Stream_Element_Offset (I)));
            end loop;
            Result := Result & From_String (Chunk);
         end;
      end loop;
      return Result;
   end Read;

   procedure Write (File : Ada.Streams.Stream_IO.File_Type; Item : Rope) is
      procedure Write_Chunk (Chunk : String) is
      begin
         --  String'Write writes each Character as one stream element;
         --  GNAT does it as a single block write.
         String'Write (Stream (File), Chunk);
      end Write_Chunk;
   begin
      Process_Chunks (Item, Write_Chunk'Access);
   end Write;

   function Read_File (Name : String) return Rope is
      File : File_Type;
   begin
      Open (File, In_File, Name);
      return Result : constant Rope := Read (File) do
         Close (File);
      end return;
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         raise;
   end Read_File;

   procedure Write_File (Name : String; Item : Rope) is
      File : File_Type;
   begin
      Create (File, Out_File, Name);
      Write (File, Item);
      Close (File);
   exception
      when others =>
         if Is_Open (File) then
            Close (File);
         end if;
         raise;
   end Write_File;

end Ropes.Stream_IO;
