with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;
with Ropes.Stream_IO;
with Ropes.Text_IO;

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
         Ropes.Text_IO.Put_Line (Cat_A & From_String (Arg));
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
            Ropes.Text_IO.Put_Line (Slice (Slice_S, Slice_Low, Natural'Value (Arg)));

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

   --  --- copyslice S LOW HIGH T POS ---
   --
   --  Demonstrates Copy_Slice (Phase 15): unlike slice, the characters go
   --  into part of an existing String, T, whose other characters are left
   --  as they were -- which is what the output shows.

   Copyslice_Count : Natural := 0;
   Copyslice_S     : Rope;
   Copyslice_Low   : Positive;
   Copyslice_High  : Natural;
   Copyslice_T     : Ada.Strings.Unbounded.Unbounded_String;

   function Copyslice_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Copyslice_Count is
         when 0 =>
            Copyslice_S := From_String (Arg);

         when 1 =>
            Copyslice_Low := Positive'Value (Arg);

         when 2 =>
            Copyslice_High := Natural'Value (Arg);

         when 3 =>
            Copyslice_T := Ada.Strings.Unbounded.To_Unbounded_String (Arg);

         when 4 =>
            declare
               T : String := Ada.Strings.Unbounded.To_String (Copyslice_T);
            begin
               Copy_Slice (Copyslice_S, Copyslice_Low, Copyslice_High, T, Positive'Value (Arg));
               Put_Line (T);
            end;

         when others =>
            null;
      end case;
      Copyslice_Count := Copyslice_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         Put_Line (Standard_Error, "Error: LOW/HIGH out of range for S, or the slice does not fit in T at POS");
         Set_Exit_Status (Failure);
         return False;
   end Copyslice_Argument_Handler;

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
            Ropes.Text_IO.Put_Line (Insert (Insert_S, Insert_Before, Arg));

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
            Ropes.Text_IO.Put_Line (Delete (Delete_S, Delete_From, Natural'Value (Arg)));

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
   --  other Ropes client would have to. B is compared as the String
   --  it arrives as, using the mixed Rope/String operators.

   Cmp_Count : Natural := 0;
   Cmp_A     : Rope;

   function Cmp_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Cmp_Count = 0 then
         Cmp_A := From_String (Arg);
      elsif Cmp_Count = 1 then
         if Cmp_A = Arg then
            Put_Line ("0");
         elsif Cmp_A < Arg then
            Put_Line ("-1");
         else
            Put_Line ("1");
         end if;
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
            --  The Process-callback form (Phase 8), not the
            --  array-returning one above -- demonstrates the addition
            --  the same way chars below demonstrates Cursor/Iterable:
            --  by actually using it, not leaving it to the test suite
            --  alone.
            declare
               function Print_Piece (Piece : Rope) return Boolean is
               begin
                  Ropes.Text_IO.Put_Line (Piece);
                  return True;
               end Print_Piece;
            begin
               Split (Split_S, From_String (Arg), Print_Piece'Access);
            end;

         when others =>
            null;
      end case;
      Split_Count := Split_Count + 1;
      return True;
   end Split_Argument_Handler;

   --  --- chars S ---
   --  A direct demo of Ropes.Cursor and the Iterable aspect (see
   --  PLAN.md's "Iteration" section) -- the Ada replacement for
   --  Rope.Mod's own Iterator type -- rather than a wrapped operation
   --  like every other command here. Rope.Mod itself has two
   --  character-level iteration APIs, Iterate (a push-based Visitor
   --  callback with early-stop support) and the Iterator type (a
   --  stateful Get/Incr/Decr/Goto/Move/Peek/Source cursor); both
   --  existed there all along -- it was RopeTool.Mod that had no
   --  subcommand demonstrating either one, not Rope.Mod lacking the
   --  capability. Since fixed (oberon-tools commit 6676de6): RopeTool.Mod
   --  now has iterate/iterator subcommands that print a rope's
   --  characters one per line, the same output chars produces here.

   function Chars_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      for Ch of From_String (Arg) loop
         Put_Line ([Ch]);
      end loop;
      return True;
   end Chars_Argument_Handler;

   --  --- trim / triml / trimr S ---
   --  Ropes has one Trim function, not RopeTool.Mod's separate
   --  TrimLeft/TrimRight/Trim -- triml/trimr pass
   --  Ada.Strings.Maps.Null_Set for the side they don't want touched
   --  (see ropes.ads's Trim doc comment).

   function Trim_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (Trim (From_String (Arg)));
      return True;
   end Trim_Argument_Handler;

   function Triml_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (Trim (From_String (Arg), Right => Ada.Strings.Maps.Null_Set));
      return True;
   end Triml_Argument_Handler;

   function Trimr_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (Trim (From_String (Arg), Left => Ada.Strings.Maps.Null_Set));
      return True;
   end Trimr_Argument_Handler;

   --  --- upper / lower / capitalize / uncapitalize S ---

   function Upper_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (To_Upper (From_String (Arg)));
      return True;
   end Upper_Argument_Handler;

   function Lower_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (To_Lower (From_String (Arg)));
      return True;
   end Lower_Argument_Handler;

   function Capitalize_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (Capitalize (From_String (Arg)));
      return True;
   end Capitalize_Argument_Handler;

   function Uncapitalize_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (Uncapitalize (From_String (Arg)));
      return True;
   end Uncapitalize_Argument_Handler;

   --  --- repeat S N ---

   Repeat_Count : Natural := 0;
   Repeat_S     : Rope;

   function Repeat_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Repeat_Count = 0 then
         Repeat_S := From_String (Arg);
      elsif Repeat_Count = 1 then
         Ropes.Text_IO.Put_Line (Natural'Value (Arg) * Repeat_S);
      end if;
      Repeat_Count := Repeat_Count + 1;
      return True;
   exception
      when Constraint_Error =>
         Put_Line (Standard_Error, "Error: not a valid count: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Repeat_Argument_Handler;

   --  --- make LEN CH ---

   Make_Count : Natural := 0;
   Make_Len   : Natural;

   function Make_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Make_Count is
         when 0 =>
            Make_Len := Natural'Value (Arg);

         when 1 =>
            if Arg'Length /= 1 then
               Put_Line (Standard_Error, "Error: CH must be exactly one character: """ & Arg & """");
               Set_Exit_Status (Failure);
               return False;
            end if;
            Ropes.Text_IO.Put_Line (Make_Len * Arg (Arg'First));

         when others =>
            null;
      end case;
      Make_Count := Make_Count + 1;
      return True;
   exception
      when Constraint_Error =>
         Put_Line (Standard_Error, "Error: not a valid length: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Make_Argument_Handler;

   --  --- bigcat N1 CH1 N2 CH2 ---
   --  Built with "*" so that even huge N1/N2 stay cheap (its binary
   --  doubling shares subtrees instead of copying characters). Lets
   --  New_Concat's overflow guard be exercised -- and
   --  Ada.Strings.Length_Error raised, as designed, instead of
   --  silently wrapping -- without actually allocating anywhere near
   --  Natural'Last real characters.

   Bigcat_Count : Natural := 0;
   Bigcat_N1    : Natural;
   Bigcat_Ch1   : Character;
   Bigcat_N2    : Natural;

   function Bigcat_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Bigcat_Count is
         when 0 =>
            Bigcat_N1 := Natural'Value (Arg);

         when 1 =>
            if Arg'Length /= 1 then
               Put_Line (Standard_Error, "Error: CH1 must be exactly one character: """ & Arg & """");
               Set_Exit_Status (Failure);
               return False;
            end if;
            Bigcat_Ch1 := Arg (Arg'First);

         when 2 =>
            Bigcat_N2 := Natural'Value (Arg);

         when 3 =>
            if Arg'Length /= 1 then
               Put_Line (Standard_Error, "Error: CH2 must be exactly one character: """ & Arg & """");
               Set_Exit_Status (Failure);
               return False;
            end if;
            Put_Line
              (Ada.Strings.Fixed.Trim
                 (Natural'Image (Length (Bigcat_N1 * Bigcat_Ch1 & Bigcat_N2 * Arg (Arg'First))), Ada.Strings.Both));

         when others =>
            null;
      end case;
      Bigcat_Count := Bigcat_Count + 1;
      return True;
   exception
      when Constraint_Error         =>
         Put_Line (Standard_Error, "Error: not a valid count: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Length_Error =>
         --  New_Concat's overflow guard: N1 + N2 exceeds Natural'Last
         --  -- Rope.Mod's own Cat HALTs(1) here instead of raising, so
         --  this is the one place this CLI's error convention diverges
         --  in kind (an exception, not a clamp), not just wording; see
         --  PLAN.md's "Comparison"/overflow notes for the general
         --  clamp-to-exception shift this whole port makes.
         Put_Line (Standard_Error, "Error: combined length exceeds Natural'Last");
         Set_Exit_Status (Failure);
         return False;
   end Bigcat_Argument_Handler;

   --  --- contains S CH FROM ---

   Contains_Count : Natural := 0;
   Contains_S     : Rope;
   Contains_Ch    : Character;

   function Contains_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Contains_Count is
         when 0 =>
            Contains_S := From_String (Arg);

         when 1 =>
            if Arg'Length /= 1 then
               Put_Line (Standard_Error, "Error: CH must be exactly one character: """ & Arg & """");
               Set_Exit_Status (Failure);
               return False;
            end if;
            Contains_Ch := Arg (Arg'First);

         when 2 =>
            Put_Line (Boolean'Image (Contains (Contains_S, Contains_Ch, Positive'Value (Arg))));

         when others =>
            null;
      end case;
      Contains_Count := Contains_Count + 1;
      return True;
   exception
      when Constraint_Error =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Contains_Argument_Handler;

   --  --- escaped S ---

   function Escaped_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      Ropes.Text_IO.Put_Line (Escape (From_String (Arg)));
      return True;
   end Escaped_Argument_Handler;

   --  --- overwrite S POS NEW ---

   Overwrite_Count : Natural := 0;
   Overwrite_S     : Rope;
   Overwrite_Pos   : Positive;

   function Overwrite_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Overwrite_Count is
         when 0 =>
            Overwrite_S := From_String (Arg);

         when 1 =>
            Overwrite_Pos := Positive'Value (Arg);

         when 2 =>
            Ropes.Text_IO.Put_Line (Overwrite (Overwrite_S, Overwrite_Pos, Arg));

         when others =>
            null;
      end case;
      Overwrite_Count := Overwrite_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         --  Not necessarily Arg itself at fault -- POS, set on an
         --  earlier call, could be the one out of range.
         Put_Line (Standard_Error, "Error: POS out of range");
         Set_Exit_Status (Failure);
         return False;
   end Overwrite_Argument_Handler;

   --  --- head / tail S COUNT ---

   Head_Count : Natural := 0;
   Head_S     : Rope;

   function Head_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Head_Count = 0 then
         Head_S := From_String (Arg);
      elsif Head_Count = 1 then
         Ropes.Text_IO.Put_Line (Head (Head_S, Natural'Value (Arg)));
      end if;
      Head_Count := Head_Count + 1;
      return True;
   exception
      when Constraint_Error =>
         Put_Line (Standard_Error, "Error: not a valid count: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Head_Argument_Handler;

   Tail_Count : Natural := 0;
   Tail_S     : Rope;

   function Tail_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Tail_Count = 0 then
         Tail_S := From_String (Arg);
      elsif Tail_Count = 1 then
         Ropes.Text_IO.Put_Line (Tail (Tail_S, Natural'Value (Arg)));
      end if;
      Tail_Count := Tail_Count + 1;
      return True;
   exception
      when Constraint_Error =>
         Put_Line (Standard_Error, "Error: not a valid count: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Tail_Argument_Handler;

   --  --- lines FILE ---
   --
   --  The one rope_tool command that reads input, demonstrating
   --  Ropes.Text_IO.Get_Line (Phase 11) as the rest demonstrate its
   --  Put_Line: each line is read whole, however long, without a
   --  buffer as long as the line. FILE = "-" reads Current_Input via
   --  the no-File overload; anything else is opened and read via the
   --  File overload. No Rope.Mod/RopeTool.Mod counterpart (Rope.Mod has
   --  no I/O at all). Needs an Arg_Parser that passes a bare "-" on as
   --  an argument (arg_parser 264a098 and later); older ones silently
   --  dropped it, so this handler never saw it.

   function Lines_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);

      procedure Print (Line : Rope) is
      begin
         Put (Ada.Strings.Fixed.Trim (Natural'Image (Length (Line)), Ada.Strings.Both) & " ");
         Ropes.Text_IO.Put_Line (Line);
      end Print;

      F : File_Type;
   begin
      if Arg = "-" then
         while not End_Of_File loop
            Print (Ropes.Text_IO.Get_Line);
         end loop;
      else
         Open (F, In_File, Arg);
         while not End_Of_File (F) loop
            Print (Ropes.Text_IO.Get_Line (F));
         end loop;
         Close (F);
      end if;
      return True;
   exception
      when Name_Error | Use_Error =>
         Put_Line (Standard_Error, "Error: cannot open """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Device_Error           =>
         --  E.g. FILE is a directory: Open succeeds, reading does not.
         if Is_Open (F) then
            Close (F);
         end if;
         Put_Line (Standard_Error, "Error: cannot read """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Lines_Argument_Handler;

   --  --- readfile FILE ---
   --
   --  Demonstrates Ropes.Stream_IO.Read_File (Phase 13): the whole file,
   --  byte for byte. Printed escaped (Ropes.Escape) so that what makes a
   --  byte-exact read different from a line-by-line one -- a CR, a form
   --  feed, a 0X, whether there is a final line feed -- is visible in the
   --  output rather than lost to the terminal or to the test harness's
   --  trailing-white-space stripping.

   function Readfile_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
      Contents : Rope;
   begin
      Contents := Ropes.Stream_IO.Read_File (Arg);
      Put (Ada.Strings.Fixed.Trim (Natural'Image (Length (Contents)), Ada.Strings.Both) & " ");
      Ropes.Text_IO.Put_Line (Escape (Contents));
      return True;
   exception
      when Name_Error | Use_Error | Device_Error =>
         Put_Line (Standard_Error, "Error: cannot read """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
   end Readfile_Argument_Handler;

   --  --- replaceslice S LOW HIGH BY ---

   Replaceslice_Count : Natural := 0;
   Replaceslice_S     : Rope;
   Replaceslice_Low   : Positive;
   Replaceslice_High  : Natural;

   function Replaceslice_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      case Replaceslice_Count is
         when 0 =>
            Replaceslice_S := From_String (Arg);

         when 1 =>
            Replaceslice_Low := Positive'Value (Arg);

         when 2 =>
            Replaceslice_High := Natural'Value (Arg);

         when 3 =>
            Ropes.Text_IO.Put_Line (Replace_Slice (Replaceslice_S, Replaceslice_Low, Replaceslice_High, Arg));

         when others =>
            null;
      end case;
      Replaceslice_Count := Replaceslice_Count + 1;
      return True;
   exception
      when Constraint_Error        =>
         Put_Line (Standard_Error, "Error: not a valid index: """ & Arg & """");
         Set_Exit_Status (Failure);
         return False;
      when Ada.Strings.Index_Error =>
         --  LOW, set on an earlier call, is the one out of range.
         Put_Line (Standard_Error, "Error: LOW out of range");
         Set_Exit_Status (Failure);
         return False;
   end Replaceslice_Argument_Handler;

   --  --- count S PATTERN ---
   --
   --  Ropes.Count is written qualified here and in countset below:
   --  with both Ada.Text_IO and Ropes use-visible, a bare Count is
   --  hidden by Ada.Text_IO's own Count type (RM 8.4(11)) -- the same
   --  clash a client of Ada.Strings.Unbounded.Count gets.

   Count_Count : Natural := 0;
   Count_S     : Rope;

   function Count_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Count_Count = 0 then
         Count_S := From_String (Arg);
      elsif Count_Count = 1 then
         Put_Line (Ada.Strings.Fixed.Trim (Natural'Image (Ropes.Count (Count_S, Arg)), Ada.Strings.Both));
      end if;
      Count_Count := Count_Count + 1;
      return True;
   exception
      when Ada.Strings.Pattern_Error =>
         Put_Line (Standard_Error, "Error: PATTERN must not be empty");
         Set_Exit_Status (Failure);
         return False;
   end Count_Argument_Handler;

   --  --- countset S CHARS ---

   Countset_Count : Natural := 0;
   Countset_S     : Rope;

   function Countset_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      if Countset_Count = 0 then
         Countset_S := From_String (Arg);
      elsif Countset_Count = 1 then
         Put_Line
           (Ada.Strings.Fixed.Trim (Natural'Image (Ropes.Count (Countset_S, Ada.Strings.Maps.To_Set (Arg))), Ada.Strings.Both));
      end if;
      Countset_Count := Countset_Count + 1;
      return True;
   end Countset_Argument_Handler;

   --  --- indexset / rindexset S CHARS FROM ---
   --
   --  One Ropes.Index (Character_Set) overload with a fixed Going,
   --  split into two commands like index/rindex.

   Indexset_Count : Natural := 0;
   Indexset_S     : Rope;
   Indexset_Set   : Ada.Strings.Maps.Character_Set;

   function Indexset_Handler (Arg : String; Going : Ada.Strings.Direction) return Boolean is
   begin
      case Indexset_Count is
         when 0 =>
            Indexset_S := From_String (Arg);

         when 1 =>
            Indexset_Set := Ada.Strings.Maps.To_Set (Arg);

         when 2 =>
            Put_Line
              (Ada.Strings.Fixed.Trim
                 (Natural'Image (Index (Indexset_S, Indexset_Set, Positive'Value (Arg), Going => Going)), Ada.Strings.Both));

         when others =>
            null;
      end case;
      Indexset_Count := Indexset_Count + 1;
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
   end Indexset_Handler;

   function Indexset_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      return Indexset_Handler (Arg, Ada.Strings.Forward);
   end Indexset_Argument_Handler;

   function Rindexset_Argument_Handler (Start_With : Positive; Arg : String) return Boolean is
      pragma Unreferenced (Start_With);
   begin
      return Indexset_Handler (Arg, Ada.Strings.Backward);
   end Rindexset_Argument_Handler;

end Rope_Tool_Args;
