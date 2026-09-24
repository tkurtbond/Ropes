--  Phase 18 checks: the leaf-walking Index and Count. Each search now
--  starts a Leaf_Walk part-way through the rope (Start_Walk_At) and
--  walks it in either direction, so these run every search, from every
--  From, over ropes of the same text built into differently shaped
--  trees -- left-built, right-built, by scattered Inserts, one flat
--  leaf, and by "*" (whose subtrees are shared) -- with
--  Ada.Strings.Fixed on the same text as the oracle, Index_Error cases
--  included. The leaves are 9 characters (9 + 9 > 16, the short-leaf
--  merge threshold, so they stay separate), and the text is mostly a's
--  and b's, so most candidate matches are partial ones and many cross
--  one or more leaf boundaries.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;      use Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Text_IO;
with Ropes;            use Ropes;
with Ropes.Test_Support;

procedure Test_Search_Walk is

   --  Not "use Ada.Text_IO": its Count type would hide Ropes.Count.
   procedure Put_Line (Item : String) renames Ada.Text_IO.Put_Line;

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

   Leaf_Size : constant := 9;

   --  240 characters, mostly a's and b's, a few c's, from a small
   --  linear congruential generator, so the text is fixed but
   --  irregular.
   function Make_Text return String is
      Result : String (1 .. 240);
      Seed   : Natural := 12_345;
   begin
      for Ch of Result loop
         Seed := (Seed * 1_103 + 12_345) mod 65_536;
         Ch   := (case Seed mod 7 is when 0 => 'c', when 1 .. 3 => 'a', when others => 'b');
      end loop;
      return Result;
   end Make_Text;

   Text : constant String := Make_Text;

   --  Source in pieces of Leaf_Size, each appended in turn.
   function Left_Built (Source : String) return Rope is
      Result : Rope;
      I      : Positive := Source'First;
   begin
      while I <= Source'Last loop
         Result := Result & From_String (Source (I .. Natural'Min (I + Leaf_Size - 1, Source'Last)));
         I      := I + Leaf_Size;
      end loop;
      return Result;
   end Left_Built;

   --  Text in pieces of Leaf_Size, each prepended in turn.
   function Right_Built return Rope is
      Result : Rope;
      I      : Integer := Text'Last;
   begin
      while I >= Text'First loop
         Result := From_String (Text (Integer'Max (I - Leaf_Size + 1, Text'First) .. I)) & Result;
         I      := I - Leaf_Size;
      end loop;
      return Result;
   end Right_Built;

   --  Text in pieces of Leaf_Size, inserted in a scrambled order, each
   --  at the position that puts it in place among those already there.
   function Insert_Built return Rope is
      Pieces : constant Positive              := (Text'Length + Leaf_Size - 1) / Leaf_Size;
      Placed : array (1 .. Pieces) of Boolean := [others => False];
      Result : Rope;
      K      : Positive                       := 1;
   begin
      for Step in 1 .. Pieces loop
         K := (K * 7 + 3) mod Pieces + 1;
         while Placed (K) loop
            K := K mod Pieces + 1;
         end loop;
         declare
            Low    : constant Positive := (K - 1) * Leaf_Size + 1;
            Piece  : constant String   := Text (Low .. Natural'Min (Low + Leaf_Size - 1, Text'Last));
            Before : Positive          := 1;
         begin
            for J in 1 .. K - 1 loop
               if Placed (J) then
                  Before := Before + Leaf_Size;  --  Only the last piece is short, and it is never before another.
               end if;
            end loop;
            Result     := Insert (Result, Before, Piece);
            Placed (K) := True;
         end;
      end loop;
      return Result;
   end Insert_Built;

   --  "*" shares one subtree many times over, so its text is its own:
   --  a 30-character period, repeated.
   Period        : constant String := Text (1 .. 30);
   Repeated_Text : constant String := Ada.Strings.Fixed."*" (8, Period);

   type Shape_Name is (Left, Right, Inserted, One_Leaf, Starred);

   Shapes : constant array (Shape_Name) of Rope :=
     [Left   => Left_Built (Text), Right => Right_Built, Inserted => Insert_Built, One_Leaf => From_String (Text),
     Starred => 8 * Left_Built (Period)];

   Sets : constant array (1 .. 4) of Character_Set := [To_Set ('a'), To_Set ('c'), To_Set ("bc"), Null_Set];

   Lengths : constant array (1 .. 11) of Positive := [1, 2, 3, 5, 8, 9, 10, 17, 19, 30, 61];
   Starts  : constant array (1 .. 6) of Positive  := [1, 4, 9, 10, 55, 97];

   --  Whether Got and Want give the same answer, raising Index_Error
   --  included.
   generic
      with function Got return Natural;
      with function Want return Natural;
   function Agree return Boolean;

   function Agree return Boolean is
   begin
      declare
         W : constant Natural := Want;
      begin
         return Got = W;
      exception
         when Index_Error =>
            return False;  --  Only Got raised.
      end;
   exception
      when Index_Error =>
         declare
            Unused : Natural;
         begin
            Unused := Got;
            return False;
         exception
            when Index_Error =>
               return True;
         end;
   end Agree;

begin
   for Shape in Shape_Name loop
      declare
         Name : constant String := Shape'Image;
         O    : constant String := (if Shape = Starred then Repeated_Text else Text);
         R    : Rope renames Shapes (Shape);

         Chars_Agree, Sets_Agree, Patterns_Agree, Rope_Patterns_Agree, Counts_Agree : Boolean := True;

         procedure Try_Pattern (P : String) is
            --  In pieces, so that a long pattern is a multi-leaf rope,
            --  and Index/Count take the path that flattens it.
            P_Rope : constant Rope := Left_Built (P);
         begin
            for Going in Direction loop
               if Index (R, P, Going) /= Ada.Strings.Fixed.Index (O, P, Going) then
                  Patterns_Agree := False;
               end if;
               for From in 1 .. O'Last + 2 loop
                  declare
                     function Got return Natural is (Index (R, P, From, Going));
                     function Got_Rope return Natural is (Index (R, P_Rope, From, Going));
                     function Want return Natural is (Ada.Strings.Fixed.Index (O, P, From, Going));
                     function Agree_String is new Agree (Got, Want);
                     function Agree_Rope is new Agree (Got_Rope, Want);
                  begin
                     if not Agree_String then
                        Patterns_Agree := False;
                        Put_Line ("  " & Name & ": Index " & P & " From" & From'Image & " " & Going'Image);
                     end if;
                     if not Agree_Rope then
                        Rope_Patterns_Agree := False;
                     end if;
                  end;
               end loop;
            end loop;
            if Ropes.Count (R, P) /= Ada.Strings.Fixed.Count (O, P)
              or else Ropes.Count (R, P_Rope) /= Ada.Strings.Fixed.Count (O, P)
            then
               Counts_Agree := False;
               Put_Line ("  " & Name & ": Count " & P);
            end if;
         end Try_Pattern;
      begin
         Check (To_String (R) = O, Name & ": has the expected text");

         for Ch in Character range 'a' .. 'd' loop
            for Going in Direction loop
               for From in 1 .. O'Last + 2 loop
                  declare
                     function Got return Natural is (Index (R, Ch, From, Going));
                     function Want return Natural is (Ada.Strings.Fixed.Index (O, [1 => Ch], From, Going));
                     function Agree_Char is new Agree (Got, Want);
                  begin
                     if not Agree_Char then
                        Chars_Agree := False;
                     end if;
                  end;
               end loop;
            end loop;
         end loop;
         Check (Chars_Agree, Name & ": Index Character, every From, both ways");

         for Set of Sets loop
            for Test in Membership loop
               for Going in Direction loop
                  for From in 1 .. O'Last + 2 loop
                     declare
                        function Got return Natural is (Index (R, Set, From, Test, Going));
                        function Want return Natural is (Ada.Strings.Fixed.Index (O, Set, From, Test, Going));
                        function Agree_Set is new Agree (Got, Want);
                     begin
                        if not Agree_Set then
                           Sets_Agree := False;
                        end if;
                     end;
                  end loop;
               end loop;
            end loop;
         end loop;
         Check (Sets_Agree, Name & ": Index Character_Set, every From, Test and Going");

         for Len of Lengths loop
            for Low of Starts loop
               if Low + Len - 1 <= O'Last then
                  Try_Pattern (O (Low .. Low + Len - 1));
               end if;
            end loop;
            Try_Pattern (Ada.Strings.Fixed."*" (Len, 'c'));  --  Never occurs past Len = 2 or so.
         end loop;
         Try_Pattern (O);
         Try_Pattern (O & "a");
         Check (Patterns_Agree, Name & ": Index String, every From, both ways");
         Check (Rope_Patterns_Agree, Name & ": Index Rope pattern, multi-leaf too, agrees with String");
         Check (Counts_Agree, Name & ": Count, String and Rope patterns");
      end;
   end loop;

   Check
     (Ropes.Test_Support.Depth (Shapes (Left)) >= 5 and then Ropes.Test_Support.Depth (Shapes (Inserted)) >= 5,
      "left- and insert-built ropes are deep enough to exercise the walk's stack");

   Ada.Text_IO.New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Search_Walk;
