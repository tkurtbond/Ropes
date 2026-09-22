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

   --  --- slice S LOW HIGH ---

   Slice_Count : Natural := 0;
   Slice_S     : Rope;
   Slice_Low   : Positive;

   function Slice_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Slice_Count is
         when 0 =>
            Slice_S := From_String (Arg);

         when 1 =>
            Slice_Low := Positive'Value (Arg);

         when 2 =>
            Put_Line (To_String (Slice (Slice_S, Slice_Low, Natural'Value (Arg))));

         when others =>
            null;
      end case;
      Slice_Count := Slice_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         --  Not necessarily Arg itself at fault -- LOW or HIGH, set on
         --  an earlier call, could be the one out of range.
         Put_Line (Standard_Error, "Error: LOW/HIGH out of range");
         Set_Exit_Status (Failure);
         return False;
   end Slice_Argument_Handler;

   --  --- insert S BEFORE INS ---

   Insert_Count  : Natural := 0;
   Insert_S      : Rope;
   Insert_Before : Positive;

   function Insert_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Insert_Count is
         when 0 =>
            Insert_S := From_String (Arg);

         when 1 =>
            Insert_Before := Positive'Value (Arg);

         when 2 =>
            Put_Line (To_String (Insert (Insert_S, Insert_Before, From_String (Arg))));

         when others =>
            null;
      end case;
      Insert_Count := Insert_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         --  Not necessarily Arg itself at fault -- BEFORE, set on an
         --  earlier call, could be the one out of range.
         Put_Line (Standard_Error, "Error: BEFORE out of range");
         Set_Exit_Status (Failure);
         return False;
   end Insert_Argument_Handler;

   --  --- delete S FROM THROUGH ---

   Delete_Count : Natural := 0;
   Delete_S     : Rope;
   Delete_From  : Positive;

   function Delete_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Delete_Count is
         when 0 =>
            Delete_S := From_String (Arg);

         when 1 =>
            Delete_From := Positive'Value (Arg);

         when 2 =>
            Put_Line (To_String (Delete (Delete_S, Delete_From, Natural'Value (Arg))));

         when others =>
            null;
      end case;
      Delete_Count := Delete_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         --  Not necessarily Arg itself at fault -- FROM, set on an
         --  earlier call, could be the one out of range.
         Put_Line (Standard_Error, "Error: FROM out of range");
         Set_Exit_Status (Failure);
         return False;
   end Delete_Argument_Handler;

   --  --- cmp A B ---
   --  Ropes has no public Compare function (see PLAN.md's
   --  "Comparison"): built here from "="/"<" instead, same as any
   --  other Ropes client would have to.

   Cmp_Count : Natural := 0;
   Cmp_A     : Rope;

   function Cmp_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Cmp_Count = 0 then
         Cmp_A := From_String (Arg);
      elsif Cmp_Count = 1 then
         declare
            Cmp_B : constant Rope := From_String (Arg);
         begin
            if Cmp_A = Cmp_B then
               Put_Line ("0");
            elsif Cmp_A < Cmp_B then
               Put_Line ("-1");
            else
               Put_Line ("1");
            end if;
         end;
      end if;
      Cmp_Count := Cmp_Count + 1;
      return True;
   end Cmp_Argument_Handler;

   --  --- index S PATTERN FROM ---

   Index_Count   : Natural := 0;
   Index_S       : Rope;
   Index_Pattern : Rope;

   function Index_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Index_Count is
         when 0 =>
            Index_S := From_String (Arg);

         when 1 =>
            Index_Pattern := From_String (Arg);

         when 2 =>
            Put_Line
              (Ada.Strings.Fixed.Trim
                 (Natural'Image (Index (Index_S, Index_Pattern, Positive'Value (Arg), Ada.Strings.Forward)), Ada.Strings.Both));

         when others =>
            null;
      end case;
      Index_Count := Index_Count + 1;
      return True;
   exception
      when Constraint_Error          =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Pattern_Error =>
         Put_Line (Standard_Error, "Error: PATTERN must not be empty");
         Set_Exit_Status (Failure);
         return False;
   end Index_Argument_Handler;

   --  --- rindex S PATTERN FROM ---

   Rindex_Count   : Natural := 0;
   Rindex_S       : Rope;
   Rindex_Pattern : Rope;

   function Rindex_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Rindex_Count is
         when 0 =>
            Rindex_S := From_String (Arg);

         when 1 =>
            Rindex_Pattern := From_String (Arg);

         when 2 =>
            Put_Line
              (Ada.Strings.Fixed.Trim
                 (Natural'Image (Index (Rindex_S, Rindex_Pattern, Positive'Value (Arg), Ada.Strings.Backward)), Ada.Strings.Both));

         when others =>
            null;
      end case;
      Rindex_Count := Rindex_Count + 1;
      return True;
   exception
      when Constraint_Error          =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Pattern_Error =>
         Put_Line (Standard_Error, "Error: PATTERN must not be empty");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error   =>
         Put_Line (Standard_Error, "Error: FROM out of range");
         Set_Exit_Status (Failure);
         return False;
   end Rindex_Argument_Handler;

   --  --- indexchar S CH FROM ---

   Indexchar_Count : Natural := 0;
   Indexchar_S     : Rope;
   Indexchar_Ch    : Character;

   function Indexchar_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Indexchar_Count is
         when 0 =>
            Indexchar_S := From_String (Arg);

         when 1 =>
            if Arg'Length /= 1 then
               Put_Line (Standard_Error, "Error: CH must be exactly one character: """ & Arg & """");
               Set_Exit_Status (Failure);
               return False;
            end if;
            Indexchar_Ch := Arg (Arg'First);

         when 2 =>
            Put_Line
              (Ada.Strings.Fixed.Trim
                 (Natural'Image (Index (Indexchar_S, Indexchar_Ch, Positive'Value (Arg), Ada.Strings.Forward)), Ada.Strings.Both));

         when others =>
            null;
      end case;
      Indexchar_Count := Indexchar_Count + 1;
      return True;
   exception
      when Constraint_Error =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Indexchar_Argument_Handler;

   --  --- rindexchar S CH FROM ---

   Rindexchar_Count : Natural := 0;
   Rindexchar_S     : Rope;
   Rindexchar_Ch    : Character;

   function Rindexchar_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Rindexchar_Count is
         when 0 =>
            Rindexchar_S := From_String (Arg);

         when 1 =>
            if Arg'Length /= 1 then
               Put_Line (Standard_Error, "Error: CH must be exactly one character: """ & Arg & """");
               Set_Exit_Status (Failure);
               return False;
            end if;
            Rindexchar_Ch := Arg (Arg'First);

         when 2 =>
            Put_Line
              (Ada.Strings.Fixed.Trim
                 (Natural'Image (Index (Rindexchar_S, Rindexchar_Ch, Positive'Value (Arg), Ada.Strings.Backward)),
                  Ada.Strings.Both));

         when others =>
            null;
      end case;
      Rindexchar_Count := Rindexchar_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         Put_Line (Standard_Error, "Error: FROM out of range");
         Set_Exit_Status (Failure);
         return False;
   end Rindexchar_Argument_Handler;

   --  --- split S SEP ---

   Split_Count : Natural := 0;
   Split_S     : Rope;

   function Split_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Split_Count is
         when 0 =>
            Split_S := From_String (Arg);

         when 1 =>
            for Piece of Split (Split_S, From_String (Arg)) loop
               Put_Line (To_String (Piece));
            end loop;

         when others =>
            null;
      end case;
      Split_Count := Split_Count + 1;
      return True;
   end Split_Argument_Handler;

end Rope_Tool_Args;
