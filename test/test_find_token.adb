--  Phase 19 checks: Index_Non_Blank and Find_Token,
--  Ada.Strings.Unbounded's own. No Ropes.Mod counterpart. The oracle is
--  GNAT's Ada.Strings.Fixed on the same text, over a rope of 9-character
--  leaves (9 + 9 > 16, the short-leaf merge threshold, so they stay
--  separate), run for every From in both directions -- Index_Error
--  cases included, which must raise exactly when the RM says. For
--  Find_Token, GNAT's Fixed already follows the RM (GNAT's Unbounded,
--  whose From precondition is never checked, does not); for
--  Index_Non_Blank, it needs the RM's From check added (RM, below).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;      use Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Find_Token is

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

   --  Source in 9-character leaves.
   function Chunked (Source : String) return Rope is
      Result : Rope;
      I      : Positive := Source'First;
   begin
      while I <= Source'Last loop
         Result := Result & From_String (Source (I .. Natural'Min (I + 8, Source'Last)));
         I      := I + 9;
      end loop;
      return Result;
   end Chunked;

   --  Words and digit runs of assorted lengths, some crossing leaf
   --  boundaries, separated by runs of spaces (one of them a whole
   --  leaf and more); leading and trailing spaces too.
   Text   : constant String := "   alpha 12 bravo          charlie3456789 delta  x 1234567890123456789 echo   ";
   Chunks : constant Rope   := Chunked (Text);

   --  The oracle: GNAT's Ada.Strings.Fixed result, with the RM's From
   --  check that GNAT leaves out (A.4.3(56.2/3, 58.5/3)): Index_Error
   --  for a From past the end of a non-empty Source, whichever way the
   --  search goes. GNAT itself raises only going Backward.
   function RM (Source : String; From : Positive; Fixed_Result : Natural) return Natural is
     (if Source'Length > 0 and then From > Source'Last then raise Index_Error else Fixed_Result);

   Digit_Set  : constant Character_Set := To_Set ("0123456789");
   Letter_Set : constant Character_Set := To_Set (Ranges => [('a', 'z')]);
   Blank_Set  : constant Character_Set := To_Set (' ');

   Sets : constant array (1 .. 4) of Character_Set := [Digit_Set, Letter_Set, Blank_Set, Null_Set];

   --  Whether Find_Token on Chunks agrees with Ada.Strings.Fixed's on
   --  Text: the same First and Last, or both raising Index_Error.
   function Token_Agrees (Set : Character_Set; From : Positive; Test : Membership) return Boolean is
      Want_First, Got_First : Positive;
      Want_Last, Got_Last   : Natural;
   begin
      begin
         Ada.Strings.Fixed.Find_Token (Text, Set, From, Test, Want_First, Want_Last);
      exception
         when Index_Error =>
            begin
               Find_Token (Chunks, Set, From, Test, Got_First, Got_Last);
               return False;
            exception
               when Index_Error =>
                  return True;
            end;
      end;
      Find_Token (Chunks, Set, From, Test, Got_First, Got_Last);
      return Got_First = Want_First and then Got_Last = Want_Last;
   exception
      when Index_Error =>
         return False;  --  Only Ropes raised.
   end Token_Agrees;

   function Non_Blank_Agrees (R : Rope; O : String; From : Positive; Going : Direction) return Boolean is
   begin
      declare
         Want : constant Natural := RM (O, From, Ada.Strings.Fixed.Index_Non_Blank (O, From, Going));
      begin
         return Index_Non_Blank (R, From, Going) = Want;
      exception
         when Index_Error =>
            return False;
      end;
   exception
      when Index_Error =>
         declare
            Unused : Natural;
         begin
            Unused := Index_Non_Blank (R, From, Going);
            return False;
         exception
            when Index_Error =>
               return True;
         end;
   end Non_Blank_Agrees;

   function Raises_Index_Error (Source : Rope; From : Positive) return Boolean is
      First : Positive;
      Last  : Natural;
   begin
      Find_Token (Source, Digit_Set, From, Inside, First, Last);
      return False;
   exception
      when Index_Error =>
         return True;
   end Raises_Index_Error;

   First : Positive;
   Last  : Natural;

   Tokens_Agree, Non_Blanks_Agree : Boolean := True;

   All_Blank : constant String := "            ";

begin
   Check (To_String (Chunks) = Text, "the test rope has the expected text");

   Find_Token (Chunks, Letter_Set, Inside, First, Last);
   Check (First = 4 and then Last = 8, "Find_Token: first word");
   Find_Token (Chunks, Digit_Set, 20, Inside, First, Last);
   Check (Text (First .. Last) = "3456789", "Find_Token From: a digit run across a leaf boundary");
   Find_Token (Chunks, Blank_Set, 1, Outside, First, Last);
   Check (Text (First .. Last) = "alpha", "Find_Token Outside");
   Find_Token (From_String ("abc"), Digit_Set, 2, Inside, First, Last);
   Check (First = 2 and then Last = 0, "Find_Token no token: First = From, Last = 0");
   Find_Token (Null_Rope, Digit_Set, 7, Inside, First, Last);
   Check (First = 7 and then Last = 0, "Find_Token Null_Rope: First = From, Last = 0, even with From out of range");
   Find_Token (Null_Rope, Digit_Set, Inside, First, Last);
   Check (First = 1 and then Last = 0, "Find_Token Null_Rope, no From: First = 1, Last = 0");
   Check
     (Raises_Index_Error (From_String ("abc"), 4) and then not Raises_Index_Error (From_String ("abc"), 3),
      "Find_Token From past the end raises Index_Error (the RM's rule, and GNAT's Fixed)");

   for Set of Sets loop
      for Test in Membership loop
         for From in 1 .. Text'Last + 2 loop
            if not Token_Agrees (Set, From, Test) then
               Tokens_Agree := False;
               Put_Line ("  disagrees at From =" & From'Image & ", " & Test'Image);
            end if;
         end loop;
      end loop;
   end loop;
   Check (Tokens_Agree, "Find_Token: every From, Test and set agrees with Ada.Strings.Fixed.Find_Token");

   Check (Index_Non_Blank (Chunks) = 4 and then Index_Non_Blank (Chunks, Backward) = Text'Last - 3, "Index_Non_Blank, both ways");
   Check (Index_Non_Blank (Chunks, 9) = 10 and then Index_Non_Blank (Chunks, 27, Backward) = 17, "Index_Non_Blank From, both ways");
   Check
     (Index_Non_Blank (Chunked (All_Blank)) = 0 and then Index_Non_Blank (Null_Rope) = 0, "Index_Non_Blank: all blank, or empty");
   Check (Index_Non_Blank (From_String (ASCII.HT & "x")) = 1, "Index_Non_Blank: only a space is blank");

   for Going in Direction loop
      for From in 1 .. Text'Last + 2 loop
         if not Non_Blank_Agrees (Chunks, Text, From, Going)
           or else not Non_Blank_Agrees (Chunked (All_Blank), All_Blank, From, Going)
         then
            Non_Blanks_Agree := False;
         end if;
      end loop;
      if Index_Non_Blank (Chunks, Going) /= Ada.Strings.Fixed.Index_Non_Blank (Text, Going) then
         Non_Blanks_Agree := False;
      end if;
   end loop;
   Check (Non_Blanks_Agree, "Index_Non_Blank: every From, both ways, agrees with Ada.Strings.Fixed.Index_Non_Blank");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Find_Token;
