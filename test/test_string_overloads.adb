--  Phase 16 checks: the String overloads of Index, Insert, Overwrite
--  and the comparison operators -- the forms Ada.Strings.Fixed and
--  Ada.Strings.Unbounded themselves take. No Rope.Mod counterpart
--  (Oberon-2 has no overloading). Index/Insert/Overwrite are checked
--  against their own Rope overloads' documented results; the
--  comparisons against predefined String comparison as an oracle,
--  across multi-leaf ropes, since they have their own leaf walk.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_String_Overloads is

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

   --  Source split into leaves of Size characters each (Size > 16, the
   --  short-leaf merge threshold, so "&" keeps them as separate leaves).
   function Chunked (Source : String; Size : Positive) return Rope is
      Result : Rope;
      I      : Positive := Source'First;
   begin
      while I <= Source'Last loop
         Result := Result & From_String (Source (I .. Natural'Min (I + Size - 1, Source'Last)));
         I      := I + Size;
      end loop;
      return Result;
   end Chunked;

   Base : constant String (1 .. 60) := [for I in 1 .. 60 => Character'Val (Character'Pos ('a') + I mod 26)];

   procedure Check_Index is
      R : constant Rope := From_String ("hello world hello");

      function Raises_Pattern_Error return Boolean is
         Unused : Natural;
      begin
         Unused := Index (R, "");
         return False;
      exception
         when Ada.Strings.Pattern_Error =>
            return True;
      end Raises_Pattern_Error;

      Offset_Pattern : constant String (5 .. 7) := "wor";
      Agrees         : Boolean                  := True;
      C              : constant Rope            := Chunked (Base, 17);
   begin
      Check (Index (R, "lo") = 4, "Index String forward");
      Check (Index (R, "lo", Going => Ada.Strings.Backward) = 16, "Index String backward");
      Check (Index (R, "hello", 2) = 13, "Index String From forward");
      Check (Index (R, "hello", 12, Ada.Strings.Backward) = 1, "Index String From backward");
      Check (Index (R, "xyz") = 0, "Index String missing");
      Check (Raises_Pattern_Error, "Index empty String raises Pattern_Error");
      Check (Index (Null_Rope, "", 1) = 0, "Index From on Null_Rope with empty String returns 0");
      Check (Index (R, Offset_Pattern) = 7, "Index String pattern not starting at 1");

      --  Every pattern of lengths 1 .. 20 taken from Base, found in a
      --  rope of Base in 17-character leaves, both directions.
      for Len in 1 .. 20 loop
         for Start in 1 .. Base'Last - Len + 1 loop
            declare
               P : constant String := Base (Start .. Start + Len - 1);
            begin
               if Index (C, P) /= Ada.Strings.Fixed.Index (Base, P)
                 or else Index (C, P, Going => Ada.Strings.Backward)
                   /= Ada.Strings.Fixed.Index (Base, P, Going => Ada.Strings.Backward)
               then
                  Agrees := False;
               end if;
            end;
         end loop;
      end loop;
      Check (Agrees, "Index String across leaves agrees with Ada.Strings.Fixed.Index");
   end Check_Index;

   procedure Check_Contains is
      R : constant Rope := From_String ("hello world hello");

      function Raises_Pattern_Error return Boolean is
         Unused : Boolean;
      begin
         Unused := Contains (R, "");
         return False;
      exception
         when Ada.Strings.Pattern_Error =>
            return True;
      end Raises_Pattern_Error;
   begin
      Check (Contains (R, "o w") and then not Contains (R, "xyz"), "Contains String");
      Check (Contains (R, "hello", 2) and then not Contains (R, "world", 8), "Contains String From");
      Check (Raises_Pattern_Error, "Contains empty String raises Pattern_Error");
   end Check_Contains;

   procedure Check_Insert_Overwrite is
      R : constant Rope := From_String ("hello world");

      function Insert_Raises return Boolean is
         Unused : Rope;
      begin
         Unused := Insert (R, 13, "x");
         return False;
      exception
         when Ada.Strings.Index_Error =>
            return True;
      end Insert_Raises;

      function Overwrite_Raises return Boolean is
         Unused : Rope;
      begin
         Unused := Overwrite (R, 13, "x");
         return False;
      exception
         when Ada.Strings.Index_Error =>
            return True;
      end Overwrite_Raises;
   begin
      Check (To_String (Insert (R, 7, "there ")) = "hello there world", "Insert String in the middle");
      Check (To_String (Insert (R, 12, "!")) = "hello world!", "Insert String at Length + 1 appends");
      Check (To_String (Insert (R, 1, "")) = "hello world", "Insert empty String");
      Check (Insert_Raises, "Insert String past Length + 1 raises Index_Error");
      Check (To_String (Overwrite (R, 7, "WORLD")) = "hello WORLD", "Overwrite String in the middle");
      Check (To_String (Overwrite (R, 10, "LD and more")) = "hello worLD and more", "Overwrite String past the end extends");
      Check (Overwrite_Raises, "Overwrite String past Length + 1 raises Index_Error");
   end Check_Insert_Overwrite;

   procedure Check_Compare is
      --  Strings around Base, differing from it or from each other at
      --  and around the 17-character leaf boundaries: prefixes of
      --  several lengths, and Base with one character raised or
      --  lowered at several positions.
      package UB renames Ada.Strings.Unbounded;

      function "+" (S : String) return UB.Unbounded_String renames UB.To_Unbounded_String;

      function Changed (Pos : Positive; By : Integer) return UB.Unbounded_String is
         S : String := Base;
      begin
         S (Pos) := Character'Val (Character'Pos (S (Pos)) + By);
         return +S;
      end Changed;

      Cases : constant array (Positive range <>) of UB.Unbounded_String :=
        [+"", +Base (1 .. 1), +Base (1 .. 16), +Base (1 .. 17), +Base (1 .. 18), +Base (1 .. 34), +Base, Changed (1, 1),
         Changed (1, -1), Changed (17, 1), Changed (18, -1), Changed (35, 1), Changed (60, -1)];

      Agrees : Boolean := True;
   begin
      for A_Case of Cases loop
         for B_Case of Cases loop
            declare
               A  : constant String := UB.To_String (A_Case);
               B  : constant String := UB.To_String (B_Case);
               RA : constant Rope   := Chunked (A, 17);
            begin
               if (RA = B) /= (A = B) or else (RA < B) /= (A < B)
                 or else (RA <= B) /= (A <= B) or else (RA > B) /= (A > B)
                 or else (RA >= B) /= (A >= B) or else (B = RA) /= (B = A)
                 or else (B < RA) /= (B < A) or else (B <= RA) /= (B <= A)
                 or else (B > RA) /= (B > A) or else (B >= RA) /= (B >= A)
               then
                  Agrees := False;
                  Put_Line ("  disagrees: """ & A & """ vs """ & B & """");
               end if;
            end;
         end loop;
      end loop;
      Check (Agrees, "all 10 Rope/String operators agree with String comparison across leaves");

      declare
         Offset : constant String (10 .. 14) := "hello";
         At_End : constant String (Positive'Last - 2 .. Positive'Last) := "abc";
      begin
         Check (From_String ("hello") = Offset and then Offset = From_String ("hello"), "String not starting at 1 compares equal");
         Check (From_String ("abc") = At_End and then From_String ("abd") > At_End and then From_String ("ab") < At_End,
                "String ending at Positive'Last compares");
         Check (Null_Rope = "" and then "" = Null_Rope, "Null_Rope = empty String");
         Check (Null_Rope < "a" and then "" < From_String ("a") and then From_String ("a") > "", "empty sorts first");
         Check (From_String ("abc") /= "abd" and then "abd" /= From_String ("abc"), "/= comes with =");
      end;
   end Check_Compare;

begin
   Check_Index;
   Check_Contains;
   Check_Insert_Overwrite;
   Check_Compare;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_String_Overloads;
