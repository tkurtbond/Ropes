--  Text_IO for Ropes -- Put/Put_Line/Get_Line on Rope, mirroring
--  Ada.Text_IO.Unbounded_IO's subprograms for Unbounded_String exactly
--  (and GNAT's own name for that package, Ada.Strings.Unbounded.Text_IO,
--  which is where this child package's name comes from). No Rope.Mod
--  counterpart -- Phase 11, at explicit user request; see PLAN.md.
--
--  A child package rather than part of Ropes itself, so programs that
--  never do rope I/O don't depend on Ada.Text_IO through Ropes, same
--  split the standard library makes between Ada.Strings.Unbounded and
--  its I/O package.
--
--  Why not just Put (To_String (R))? To_String builds a full O(Length)
--  copy of the rope on the stack (then copies it again to return it),
--  which for a large enough rope overflows the stack outright. Put here
--  writes each leaf directly via Ropes.Process_Chunks, using O(depth)
--  stack no matter how long the rope is; Get_Line likewise reads a line
--  of any length in fixed-size chunks, never needing one buffer as long
--  as the whole line.

with Ada.Text_IO;

package Ropes.Text_IO is

   procedure Put (File : Ada.Text_IO.File_Type; Item : Rope);
   procedure Put (Item : Rope);
   --  Writes Item's characters to File (Current_Output for the
   --  no-File overload), exactly as Ada.Text_IO.Put (File, To_String
   --  (Item)) would.

   procedure Put_Line (File : Ada.Text_IO.File_Type; Item : Rope);
   procedure Put_Line (Item : Rope);
   --  Put, then New_Line.

   function Get_Line (File : Ada.Text_IO.File_Type) return Rope;
   function Get_Line return Rope;
   procedure Get_Line (File : Ada.Text_IO.File_Type; Item : out Rope);
   procedure Get_Line (Item : out Rope);
   --  Reads the next line from File (Current_Input for the no-File
   --  overloads), of any length, and returns it without its line
   --  terminator -- same semantics as Ada.Text_IO.Unbounded_IO.Get_Line,
   --  including raising Ada.Text_IO.End_Error at end of file.

end Ropes.Text_IO;
