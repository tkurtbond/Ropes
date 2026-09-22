with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

package body Rope_Tool_Args is

   function Do_Help return Boolean is
   begin
      Usage (Main_Parser);
      --  Once they ask for help it is too late to continue.
      return False;
   end Do_Help;

   function Main_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Put_Line (Standard_Error, "Error: unknown command: " & Arg);
      Usage (Main_Parser);
      Set_Exit_Status (Failure);
      return False;
   end Main_Argument_Handler;

   --  --- cat A B ---

   Cat_Count : Natural := 0;
   Cat_A     : Rope;

   function Cat_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Cat_Count = 0 then
         Cat_A := From_String (Arg);
      elsif Cat_Count = 1 then
         Put_Line (To_String (Cat_A & From_String (Arg)));
      end if;
      Cat_Count := Cat_Count + 1;
      return True;
   end Cat_Argument_Handler;

   --  --- len S ---

   function Len_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Put_Line (Ada.Strings.Fixed.Trim (Natural'Image (Length (From_String (Arg))), Ada.Strings.Both));
      return True;
   end Len_Argument_Handler;

   --  --- fetch S I ---

   Fetch_Count : Natural := 0;
   Fetch_S     : Rope;

   function Fetch_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Fetch_Count = 0 then
         Fetch_S := From_String (Arg);
      elsif Fetch_Count = 1 then
         Put_Line ([Element (Fetch_S, Positive'Value (Arg))]);
      end if;
      Fetch_Count := Fetch_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         Put_Line (Standard_Error, "Error: index out of range: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Fetch_Argument_Handler;

end Rope_Tool_Args;
