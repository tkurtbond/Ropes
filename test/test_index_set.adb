--  Phase 17 checks: Index with a Character_Set, Ada.Strings.Unbounded's
--  own overloads. No Ropes.Mod counterpart (Ropes.Mod's Split visitor
--  takes a character predicate, but it has no set-based search). The
--  oracle is GNAT's Ada.Strings.Fixed.Index with the RM's From check
--  added (RM, below), run for every From, Test and Going around a rope
--  of several leaves -- including the Index_Error cases, which must
--  raise exactly when the RM says (see ropes.ads).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;      use Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Index_Set is

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

   --  Mostly letters, with a few digits and spaces scattered across the
   --  17-character leaf boundaries, including at them.
   Base   : constant String := "abc 1defghijklmnop2qrs tuvwxyzabcd3efghij klm4";
   Chunks : constant Rope   := Chunked (Base, 17);

   --  The oracle: GNAT's Ada.Strings.Fixed result, with the RM's From
   --  check that GNAT leaves out (A.4.3(56.2/3, 58.5/3)): Index_Error
   --  for a From past the end of a non-empty Source, whichever way the
   --  search goes. GNAT itself raises only going Backward.
   function RM (Source : String; From : Positive; Fixed_Result : Natural) return Natural is
     (if Source'Length > 0 and then From > Source'Last then raise Index_Error else Fixed_Result);

   --  Whether Index (Chunks, Set, From, Test, Going) agrees with
   --  Ada.Strings.Fixed.Index (Base, Set, From, Test, Going): the same
   --  result, or both raising Index_Error.
   function Agrees_At (Set : Character_Set; From : Positive; Test : Membership; Going : Direction) return Boolean is
   begin
      declare
         Expected : constant Natural := RM (Base, From, Ada.Strings.Fixed.Index (Base, Set, From, Test, Going));
      begin
         return Index (Chunks, Set, From, Test, Going) = Expected;
      exception
         when Index_Error =>
            return False;  --  Only Ropes raised.
      end;
   exception
      when Index_Error =>
         declare
            Unused : Natural;
         begin
            Unused := Index (Chunks, Set, From, Test, Going);
            return False;
         exception
            when Index_Error =>
               return True;
         end;
   end Agrees_At;

   function Agrees_With_Fixed (Set : Character_Set) return Boolean is
   begin
      for Test in Membership loop
         for Going in Direction loop
            if Index (Chunks, Set, Test, Going) /= Ada.Strings.Fixed.Index (Base, Set, Test, Going) then
               return False;
            end if;
            for From in 1 .. Base'Last + 2 loop
               if not Agrees_At (Set, From, Test, Going) then
                  Put_Line ("  disagrees at From =" & From'Image & ", " & Test'Image & ", " & Going'Image);
                  return False;
               end if;
            end loop;
         end loop;
      end loop;
      return True;
   end Agrees_With_Fixed;

   Digits_Set : constant Character_Set := To_Set ("0123456789");
   R          : constant Rope          := From_String ("hello world");

   function Forward_Raises return Boolean is
      Unused : Natural;
   begin
      Unused := Index (R, Digits_Set, 12);
      return False;
   exception
      when Index_Error =>
         return True;
   end Forward_Raises;

   function Backward_Raises return Boolean is
      Unused : Natural;
   begin
      Unused := Index (R, Digits_Set, 12, Going => Backward);
      return False;
   exception
      when Index_Error =>
         return True;
   end Backward_Raises;

begin
   Check (Index (R, To_Set (" w")) = 6, "Inside, Forward");
   Check (Index (R, To_Set ("lo"), Going => Backward) = 10, "Inside, Backward");
   Check (Index (R, To_Set ("hel"), Test => Outside) = 5, "Outside, Forward");
   Check (Index (R, To_Set ("dlr"), Test => Outside, Going => Backward) = 8, "Outside, Backward");
   Check (Index (R, Digits_Set) = 0, "no match returns 0");
   Check (Index (R, To_Set ("o"), 6) = 8 and then Index (R, To_Set ("o"), 7, Going => Backward) = 5, "From, both ways");
   Check (Forward_Raises, "Forward From past the end raises Index_Error (the RM's rule; GNAT returns 0)");
   Check (Backward_Raises, "Backward From past the end raises Index_Error");
   Check (Index (Null_Rope, Digits_Set, 99, Going => Backward) = 0, "Null_Rope returns 0 before checking From");
   Check
     (Agrees_With_Fixed (Digits_Set) and then Agrees_With_Fixed (To_Set (' ')) and then Agrees_With_Fixed (Null_Set)
      and then Agrees_With_Fixed (To_Set ("aeiou")),
      "every From, Test and Going across leaves agrees with Ada.Strings.Fixed.Index");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Test_Index_Set;
