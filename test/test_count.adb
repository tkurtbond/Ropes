--  Phase 17 checks: Count, Ada.Strings.Unbounded.Count's Pattern and
--  Character_Set overloads. No Ropes.Mod counterpart. The oracle is
--  Ada.Strings.Fixed.Count, run over a rope of several leaves, so that
--  both occurrences and set members fall across leaf boundaries.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Count is

   --  Ada.Text_IO is not use-visible here: its Count type would hide
   --  Ropes.Count (RM 8.4(11)), the same clash as with
   --  Ada.Strings.Unbounded.Count.
   procedure Put_Line (Item : String) renames Ada.Text_IO.Put_Line;
   procedure New_Line (Spacing : Ada.Text_IO.Positive_Count := 1) renames Ada.Text_IO.New_Line;

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

   function Raises_Pattern_Error (Source : Rope; Pattern : String) return Boolean is
      Unused : Natural;
   begin
      Unused := Count (Source, Pattern);
      return False;
   exception
      when Ada.Strings.Pattern_Error =>
         return True;
   end Raises_Pattern_Error;

   --  Runs of a's and b's, so that patterns like "aa" and "aba" overlap
   --  themselves and the nonoverlapping rule matters.
   Base   : constant String := "aaaabababaaabbbaabaaaababbbabaaaaaaabababbaaabaaabbbaaba";
   Chunks : constant Rope   := Chunked (Base, 17);
   R      : constant Rope   := From_String ("hello world, hello");

   Sets : constant array (1 .. 5) of Character_Set := [To_Set ('a'), To_Set ('b'), To_Set ("ab"), Null_Set, To_Set ('z')];

   Patterns_Agree : Boolean := True;
   Sets_Agree     : Boolean := True;

begin
   Check (Count (R, "hello") = 2 and then Count (R, "xyz") = 0, "String pattern");
   Check (Count (R, From_String ("l")) = 5, "Rope pattern");
   Check (Count (From_String ("aaaaa"), "aa") = 2, "nonoverlapping: aa in aaaaa is 2, not 4");
   Check (Count (From_String ("abababa"), "aba") = 2, "nonoverlapping: aba in abababa is 2, not 3");
   Check (Count (R, "hello world, hello") = 1 and then Count (R, "hello world, hello!") = 0, "pattern the whole rope, or longer");
   Check (Count (Null_Rope, "a") = 0, "Null_Rope Source");
   Check
     (Raises_Pattern_Error (R, "") and then Raises_Pattern_Error (Null_Rope, ""),
      "empty pattern raises Pattern_Error, even on an empty Source");
   Check
     (Count (R, To_Set ("lo")) = 8 and then Count (R, Null_Set) = 0 and then Count (Null_Rope, To_Set ("a")) = 0, "Character_Set");

   for Len in 1 .. 6 loop
      for Start in 1 .. Base'Last - Len + 1 loop
         declare
            P : constant String := Base (Start .. Start + Len - 1);
         begin
            if Count (Chunks, P) /= Ada.Strings.Fixed.Count (Base, P) then
               Patterns_Agree := False;
               Put_Line ("  disagrees for """ & P & """");
            end if;
         end;
      end loop;
   end loop;
   Check (Patterns_Agree, "every pattern of lengths 1 .. 6 across leaves agrees with Ada.Strings.Fixed.Count");

   for S of Sets loop
      if Count (Chunks, S) /= Ada.Strings.Fixed.Count (Base, S) then
         Sets_Agree := False;
      end if;
   end loop;
   Check (Sets_Agree, "Character_Set counts across leaves agree with Ada.Strings.Fixed.Count");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Count;
