--  Phase 25 checks: the Mapping parameter of Index, Count and Contains
--  -- Ada.Strings.Unbounded's own Character_Mapping (defaulting to
--  Identity) and Character_Mapping_Function forms. No Ropes.Mod
--  counterpart. The oracle is GNAT's Ada.Strings.Fixed.Index and Count
--  with the same Mapping, on the same text, over ropes of two leaf
--  chunkings (9 and 17 characters; 9 + 9 > 16, the short-leaf merge
--  threshold, so leaves stay separate), for every From in both
--  directions, exception cases included. Where GNAT is laxer than the
--  RM about From, the oracle has the RM's check added (RM, below), as
--  in test_find_token.adb.

with Ada.Characters.Handling;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;      use Ada.Strings;
with Ada.Strings.Fixed;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Strings.Maps.Constants;
with Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Index_Mapping is

   --  Not use Ada.Text_IO: its Count type would hide Ropes.Count (RM
   --  8.4(11)), as in test_count.adb.
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

   --  Source in Size-character leaves.
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

   Text : constant String := "The Quick BROWN Fox; the quICK brown fOX. THE end, The ENd, the End: thethe xyzabc";
   R9   : constant Rope   := Chunked (Text, 9);
   R17  : constant Rope   := Chunked (Text, 17);

   Lower    : Character_Mapping renames Ada.Strings.Maps.Constants.Lower_Case_Map;
   Swap     : constant Character_Mapping          := To_Mapping ("abcxyz", "xyzabc");
   Lower_Fn : constant Character_Mapping_Function := Ada.Characters.Handling.To_Lower'Access;
   --  Constant null actuals for a not null formal draw a compile-time
   --  warning; these calls are meant to raise.
   pragma Warnings (Off, "*null-excluding formal*");
   pragma Warnings (Off, "Constraint_Error will be raised at run time");
   No_Mapping : constant Character_Mapping_Function := null;

   Both : constant array (1 .. 2) of Rope := [R9, R17];

   Tables : constant array (1 .. 3) of Character_Mapping := [Lower, Swap, Identity];

   type Pattern_Name is (The, Quick_Brown, Fox, The_End, Thethe, Absent, O, Upper_The, Xyz, Abc);

   function Image (P : Pattern_Name) return String is
     (case P is when The => "the", when Quick_Brown => "quick brown", when Fox => "fox", when The_End => "the end",
        when Thethe => "thethe", when Absent => "zzz", when O => "o", when Upper_The => "THE", when Xyz => "xyz",
        when Abc => "abc");

   --  An outcome: the Natural a call returned, or which exception it
   --  raised -- so that a result and an exception compare alike.
   Index_Error_Raised   : constant Integer := -1;
   Pattern_Error_Raised : constant Integer := -2;
   Constraint_Raised    : constant Integer := -3;

   function Outcome (F : not null access function return Natural) return Integer is
   begin
      return F.all;
   exception
      when Index_Error      =>
         return Index_Error_Raised;
      when Pattern_Error    =>
         return Pattern_Error_Raised;
      when Constraint_Error =>
         return Constraint_Raised;
   end Outcome;

   --  GNAT's Ada.Strings.Fixed result, with the RM's From check that
   --  GNAT leaves out (A.4.3(56.2/3)): Index_Error for a From past the
   --  end of a non-empty Source, whichever way the search goes.
   function RM (Source : String; From : Positive; Fixed_Result : Natural) return Natural is
     (if Source'Length > 0 and then From > Source'Last then raise Index_Error else Fixed_Result);

   Tables_Agree, Functions_Agree, No_From_Agree, Counts_Agree, Ropes_Agree : Boolean := True;

   procedure Compare_From (R : Rope; P : String; From : Positive; Going : Direction) is
      function Want_Table (M : Character_Mapping) return Integer is
         function F return Natural is (RM (Text, From, Ada.Strings.Fixed.Index (Text, P, From, Going, M)));
      begin
         return Outcome (F'Access);
      end Want_Table;

      function Got_Table (M : Character_Mapping) return Integer is
         function F return Natural is (Index (R, P, From, Going, M));
      begin
         return Outcome (F'Access);
      end Got_Table;

      function Got_Rope_Pattern (M : Character_Mapping) return Integer is
         function F return Natural is (Index (R, Chunked (P, 2), From, Going, M));
      begin
         return Outcome (F'Access);
      end Got_Rope_Pattern;

      function Want_Function return Natural is (RM (Text, From, Ada.Strings.Fixed.Index (Text, P, From, Going, Lower_Fn)));
      function Got_Function return Natural is (Index (R, P, From, Going, Lower_Fn));
   begin
      for M of Tables loop
         if Got_Table (M) /= Want_Table (M) then
            Tables_Agree := False;
            Put_Line ("  table disagrees: """ & P & """ From =" & From'Image & " " & Going'Image);
         end if;
         if Got_Rope_Pattern (M) /= Want_Table (M) then
            Ropes_Agree := False;
         end if;
      end loop;
      if Outcome (Got_Function'Access) /= Outcome (Want_Function'Access) then
         Functions_Agree := False;
         Put_Line ("  function disagrees: """ & P & """ From =" & From'Image & " " & Going'Image);
      end if;
   end Compare_From;

   function Raises_Constraint_Error (F : not null access function return Natural) return Boolean is
     (Outcome (F) = Constraint_Raised);

   function Null_Index return Natural is (Index (Null_Rope, "x", Mapping => No_Mapping));
   function Null_Index_From return Natural is (Index (R9, "x", 1, Forward, No_Mapping));
   function Null_Count return Natural is (Count (Null_Rope, "x", No_Mapping));
   function Null_Contains return Natural is (Boolean'Pos (Contains (R9, From_String ("x"), No_Mapping)));
   function Empty_Pattern return Natural is (Index (R9, "", Forward, Lower));
   function Empty_Pattern_Count return Natural is (Count (R9, Null_Rope, Lower_Fn));

begin
   Check (To_String (R9) = Text and then To_String (R17) = Text, "the test ropes have the expected text");

   Check
     (Index (R9, "quick brown", Mapping => Lower) = 5 and then Index (R9, "quick brown", Mapping => Lower_Fn) = 5
      and then Index (R9, "quick brown") = 0,
      "a case-insensitive search, either Mapping form; without one, no match");
   Check
     (Index (R9, "the end", Backward, Lower) = 61 and then Index (R17, "the end", Backward, Lower_Fn) = 61,
      "Backward, across leaves");
   Check (Index (R9, "THE", Mapping => Lower) = 0, "Pattern is not mapped: an upper-case Pattern never matches a lowered Source");
   Check
     (Index (R9, "xyz", Mapping => Swap) = Text'Last - 2 and then Index (R17, "abc", Mapping => Swap) = Text'Last - 5,
      "Pattern is not mapped: under a to-and-fro mapping, ""xyz"" finds ""abc"", and ""abc"" ""xyz""");

   for P in Pattern_Name loop
      for R of Both loop
         for Going in Direction loop
            for From in 1 .. Text'Length + 2 loop
               Compare_From (R, Image (P), From, Going);
            end loop;
            for M of Tables loop
               if Index (R, Image (P), Going, M) /= Ada.Strings.Fixed.Index (Text, Image (P), Going, M) then
                  No_From_Agree := False;
               end if;
            end loop;
            if Index (R, Image (P), Going, Lower_Fn) /= Ada.Strings.Fixed.Index (Text, Image (P), Going, Lower_Fn) then
               No_From_Agree := False;
            end if;
         end loop;
         for M of Tables loop
            if Count (R, Image (P), M) /= Ada.Strings.Fixed.Count (Text, Image (P), M)
              or else Count (R, Chunked (Image (P), 2), M) /= Ada.Strings.Fixed.Count (Text, Image (P), M)
            then
               Counts_Agree := False;
            end if;
         end loop;
         if Count (R, Image (P), Lower_Fn) /= Ada.Strings.Fixed.Count (Text, Image (P), Lower_Fn) then
            Counts_Agree := False;
         end if;
      end loop;
   end loop;
   Check (Tables_Agree, "Index From, Character_Mapping: every pattern, From and direction agrees with Ada.Strings.Fixed");
   Check (Functions_Agree, "Index From, Character_Mapping_Function: every pattern, From and direction agrees");
   Check (Ropes_Agree, "Index From with a multi-leaf Rope pattern: the same as with the String");
   Check (No_From_Agree, "Index without From, both Mapping forms: agrees with Ada.Strings.Fixed");
   Check (Counts_Agree, "Count, both Mapping forms, String and Rope patterns: agrees with Ada.Strings.Fixed.Count");

   Check (Count (R9, "the", Lower) = 7 and then Count (R9, "the") = 4, "Count: case-insensitive, and not");
   Check
     (Contains (R9, "brown fox", Lower) and then Contains (R9, From_String ("brown fox"), Lower_Fn)
      and then not Contains (R9, "brown fox") and then Contains (R9, "fox", 30, Lower)
      and then not Contains (R9, From_String ("fox"), 40, Lower_Fn),
      "Contains, both Mapping forms, with and without From");
   Check (Index (R9, "the", 30, Forward, Identity) = Index (R9, "the", 30), "Identity is the default");
   Check
     (Raises_Constraint_Error (Null_Index'Access) and then Raises_Constraint_Error (Null_Index_From'Access)
      and then Raises_Constraint_Error (Null_Count'Access) and then Raises_Constraint_Error (Null_Contains'Access),
      "a null Character_Mapping_Function raises Constraint_Error, even for Null_Rope");
   Check
     (Outcome (Empty_Pattern'Access) = Pattern_Error_Raised and then Outcome (Empty_Pattern_Count'Access) = Pattern_Error_Raised,
      "an empty Pattern still raises Pattern_Error, with a Mapping");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Index_Mapping;
