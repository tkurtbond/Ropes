--  Whole-file I/O for Ropes, byte for byte -- Phase 13; see PLAN.md.
--  Read_File/Write_File load a file into a Rope and save one back
--  exactly: every byte becomes one Character and back, with no line or
--  page terminators added, dropped or translated. That is what
--  Ropes.Text_IO cannot do, being line-oriented like Ada.Text_IO under
--  it: Get_Line drops terminators (so a last line with or without one
--  reads the same), form feeds are page terminators rather than
--  characters, and closing an output file whose last line is unfinished
--  adds a line terminator. Hence Ada.Streams.Stream_IO here, not
--  Ada.Text_IO -- the same split the standard library makes.
--
--  These read eagerly: the whole file is in memory once Read or
--  Read_File returns (Read_File also closes the file; Read leaves File
--  open, at its end) -- an ordinary rope, like cord's
--  CORD_from_file_eager, not a file-backed one like CORD_from_file/
--  CORD_from_file_lazy, which keep the file open and read on demand and
--  remain out of scope (see PLAN.md's "What's explicitly out of scope"
--  and its Phase 13 entry).
--
--  The result is built from leaves of at most 4096 characters, not one
--  leaf the size of the file: Slice copies whatever parts of leaves it
--  covers, so a one-leaf rope of a large file would make every later
--  edit copy megabytes.

with Ada.Streams.Stream_IO;

package Ropes.Stream_IO is

   function Read (File : Ada.Streams.Stream_IO.File_Type) return Rope;
   --  Everything from File's current position to its end, byte for byte;
   --  Null_Rope if there is nothing left. Reads until End_Of_File, not a
   --  precomputed Size, so it also works on files with no fixed size.

   procedure Write (File : Ada.Streams.Stream_IO.File_Type; Item : Rope);
   --  Writes Item's characters at File's current position, byte for
   --  byte, one leaf at a time (via Process_Chunks).

   function Read_File (Name : String) return Rope;
   --  The whole of the file named Name. Propagates Stream_IO's own
   --  exceptions (Name_Error if there is no such file, Use_Error if it
   --  cannot be read), as Ada.Streams.Stream_IO.Open does.

   procedure Write_File (Name : String; Item : Rope);
   --  Creates (or replaces) the file named Name, containing exactly
   --  Item's characters. Propagates Stream_IO's own exceptions, as
   --  Ada.Streams.Stream_IO.Create does.

end Ropes.Stream_IO;
