--  Phase 4 checks: Index (Rope and Character patterns, both
--  directions, both overloads). See PLAN.md's phased plan and Testing
--  approach, and RopeTest.Mod's CheckCompareFindRepeat (its Find
--  cases only -- Compare/Equal are Phase 3, Repeat is a later phase)
--  and CheckIndexCharAndRFind (~/Repos/Oberon/oberon-tools/
--  RopeTest.Mod). Translated 0-based -> 1-based throughout, and NOT
--  translated verbatim where PLAN.md changed the semantics:
--
--  * An empty pattern now raises Ada.Strings.Pattern_Error instead of
--    Rope.Mod's Find/RFind, which treat it as matching at "from" --
--    see ropes.ads's Index doc comment.
--  * Ropes.Index (Going => Backward) matches Ada.Strings.Fixed.Index's
--    own Backward semantics exactly (a match must fit entirely within
--    Source (1 .. From), i.e. Start <= From - Pattern'Length + 1),
--    NOT Rope.Mod's RFind, which instead clamps to Start <= before.
--    These coincide for a length-1 pattern (RIndexChar's scenarios
--    translate directly) but differ for a longer one (RFind's
--    scenarios are translated to different From/expected values
--    below, chosen to exercise the same "a bound excludes a later
--    occurrence" shape under the real formula).
--
--  Rope.Mod's Contains has no Ropes counterpart yet (PLAN.md flags it
--  optional/undecided) and is not translated here.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;      use Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Index is

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

   procedure Check_Pattern_Error (Name : String; Tried : access function return Natural) is
   begin
      declare
         Unused : constant Natural := Tried.all;
      begin
         Put_Line ("FAIL - " & Name & " (no exception raised)");
         Failed := Failed + 1;
      end;
   exception
      when Ada.Strings.Pattern_Error =>
         Put_Line ("ok   - " & Name);
         Passed := Passed + 1;
   end Check_Pattern_Error;

   procedure Check_Index_Error (Name : String; Tried : access function return Natural) is
   begin
      declare
         Unused : constant Natural := Tried.all;
      begin
         Put_Line ("FAIL - " & Name & " (no exception raised)");
         Failed := Failed + 1;
      end;
   exception
      when Ada.Strings.Index_Error =>
         Put_Line ("ok   - " & Name);
         Passed := Passed + 1;
   end Check_Index_Error;

   Hello_World : constant Rope := From_String ("Hello, ") & From_String ("World!");
   --  "Hello, World!", length 13; "World" starts at 1-based 8.

   Two_Worlds : constant Rope := From_String ("Hello, ") & From_String ("World! World!");
   --  "Hello, World! World!", length 20; "World" starts at 1-based 8
   --  and 15.

   Abcabc : constant Rope := From_String ("abcabc");

   function Try_2 return Natural is (Index (Hello_World, Null_Rope, From => 4, Going => Forward));
   function Try_3 return Natural is (Index (Two_Worlds, Null_Rope, Going => Backward));
   function Try_3b return Natural is (Index (Null_Rope, Null_Rope, Going => Backward));
   function Try_4 return Natural is (Index (From_String ("abc"), Null_Rope));
   function Try_5 return Natural is (Index (Abcabc, 'b', From => 100, Going => Backward));

begin
   --  --- Index (Pattern : Rope), Forward ---

   Check (Index (Hello_World, From_String ("World"), From => 1, Going => Forward) = 8, "Find a substring present in the rope");
   Check (Index (Hello_World, From_String ("xyz"), From => 1, Going => Forward) = 0, "Find a substring not present");
   Check
     (Index (Hello_World, From_String ("o"), From => 6, Going => Forward) = 9,
      "Find starting from an offset skips an earlier match");
   Check (Index (Hello_World, From_String ("World")) = 8, "Find with the no-From overload defaults to searching from 1");
   Check
     (Index (Hello_World, From_String ("World"), From => 100, Going => Forward) = 0,
      "Forward never raises for an out-of-range From -- it just finds nothing");
   Check_Pattern_Error ("Find of the empty pattern raises Pattern_Error", Try_2'Access);

   --  --- Index (Pattern : Rope), Backward ---

   Check (Index (Two_Worlds, From_String ("World"), Going => Backward) = 15, "RFind-equivalent: last occurrence, whole rope");
   Check
     (Index (Two_Worlds, From_String ("World"), From => 13, Going => Backward) = 8,
      "RFind-equivalent: a bound excludes a later occurrence");
   Check (Index (Two_Worlds, From_String ("xyz"), Going => Backward) = 0, "RFind-equivalent: not present");
   Check_Pattern_Error ("RFind-equivalent of the empty pattern raises Pattern_Error", Try_3'Access);

   declare
      function Try return Natural is (Index (Two_Worlds, From_String ("World"), From => 100, Going => Backward));
   begin
      Check_Index_Error ("Backward raises Index_Error for an out-of-range From", Try'Access);
   end;

   --  --- Both Source and Pattern empty ---

   --  The no-From overload (used above, and by a bare "Index (S, P)"
   --  call) checks Pattern's emptiness first, unconditionally -- just
   --  like the real no-From Ada.Strings.Search.Index -- so it raises
   --  Pattern_Error here too, even though Source is also Null_Rope.
   Check_Pattern_Error
     ("Null_Rope pattern via the no-From overload still raises Pattern_Error, even with a Null_Rope source", Try_3b'Access);

   --  Only the *with-From* overload has the special case: it checks
   --  Source's emptiness first and returns 0 immediately, before ever
   --  looking at Pattern -- so here, uniquely, a Null_Rope pattern
   --  does NOT raise.
   Check
     (Index (Null_Rope, Null_Rope, From => 1, Going => Forward) = 0,
      "Null_Rope pattern in a Null_Rope source, With-From overload, Forward: Source's emptiness wins, returns 0");
   Check
     (Index (Null_Rope, Null_Rope, From => 1, Going => Backward) = 0,
      "Same, Backward -- Source's emptiness is still checked before Pattern's, and before the From bound too");

   Check_Pattern_Error ("A Null_Rope pattern in a non-empty source still raises Pattern_Error", Try_4'Access);
   Check (Index (Null_Rope, From_String ("x")) = 0, "A non-empty pattern in a Null_Rope source returns 0");

   --  --- Index (Pattern : Character) ---

   Check (Index (Abcabc, 'b', From => 1, Going => Forward) = 2, "IndexChar: first occurrence");
   Check (Index (Abcabc, 'b', From => 3, Going => Forward) = 5, "IndexChar: from an offset");
   Check (Index (Abcabc, 'z', From => 1, Going => Forward) = 0, "IndexChar: not present");
   Check (Index (Abcabc, 'b', Going => Backward) = 5, "RIndexChar-equivalent: last occurrence");
   Check (Index (Abcabc, 'b', From => 4, Going => Backward) = 2, "RIndexChar-equivalent: before an offset");
   Check (Index (Abcabc, 'z', Going => Backward) = 0, "RIndexChar-equivalent: not present");
   Check_Index_Error ("Character Backward also raises Index_Error for an out-of-range From", Try_5'Access);

   Check (Index (Null_Rope, 'x') = 0, "Character Forward on a Null_Rope source returns 0");
   Check (Index (Null_Rope, 'x', Going => Backward) = 0, "Character Backward on a Null_Rope source returns 0, not Index_Error");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Index;
