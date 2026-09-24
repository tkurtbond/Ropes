--  Phase 8 checks: the Process-callback form of Split (all four
--  separator overloads). See PLAN.md's phased plan, "Deferred /
--  stretch" section, and RopeTest.Mod's CheckSplit
--  (~/Repos/Oberon/oberon-tools/RopeTest.Mod) -- specifically its
--  "stops early when visit returns FALSE" scenario (StopAfterTwo),
--  which test_split.adb's own header comment explicitly noted didn't
--  translate back when only the array-returning Split existed. The
--  piece-count/content/empty-separator scenarios below are lighter
--  versions of test_split.adb's own (that file already covers the
--  underlying search/walk logic thoroughly per separator kind); this
--  file's focus is what's new here: Process's invocation order, the
--  early-stop case, and each overload's own single-call empty-separator
--  path (each has its own "call Process once, return" special case,
--  separate code from the general loop).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Split_Visitor is

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

   R : constant Rope := From_String ("a,b,,c");

begin
   --  --- Split (Separator : Rope) ---

   declare
      Count  : Natural := 0;
      Pieces : array (1 .. 4) of Rope;

      function Collect (Piece : Rope) return Boolean is
      begin
         Count          := Count + 1;
         Pieces (Count) := Piece;
         return True;
      end Collect;
   begin
      Split (R, From_String (","), Collect'Access);
      Check (Count = 4, "Split (Process, Rope separator): visits every piece, including an empty one");
      Check
        (To_String (Pieces (1)) = "a" and then To_String (Pieces (2)) = "b" and then To_String (Pieces (3)) = ""
         and then To_String (Pieces (4)) = "c",
         "Split (Process, Rope separator): piece contents in order");
   end;

   declare
      Count : Natural := 0;

      function Stop_After_Two (Piece : Rope) return Boolean is
         pragma Unreferenced (Piece);
      begin
         Count := Count + 1;
         return Count < 2;
      end Stop_After_Two;
   begin
      Split (R, From_String (","), Stop_After_Two'Access);
      Check (Count = 2, "Split (Process): stops early when Process returns False");
   end;

   declare
      Count : Natural := 0;

      function Collect_One (Piece : Rope) return Boolean is
      begin
         Count := Count + 1;
         Check (Piece = Null_Rope, "Split (Process, Rope separator) of Null_Rope: the one piece is empty");
         return True;
      end Collect_One;
   begin
      Split (Null_Rope, From_String (","), Collect_One'Access);
      Check (Count = 1, "Split (Process, Rope separator) of Null_Rope calls Process exactly once");
   end;

   declare
      Count : Natural := 0;

      function Collect_One (Piece : Rope) return Boolean is
      begin
         Count := Count + 1;
         Check
           (To_String (Piece) = "abc", "Split (Process, Rope separator) with an empty separator: the one piece is the whole rope");
         return True;
      end Collect_One;
   begin
      Split (From_String ("abc"), Null_Rope, Collect_One'Access);
      Check (Count = 1, "Split (Process, Rope separator) with an empty separator calls Process exactly once");
   end;

   --  --- Split (Separator : String) ---

   declare
      Count : Natural := 0;

      function Count_Piece (Piece : Rope) return Boolean is
         pragma Unreferenced (Piece);
      begin
         Count := Count + 1;
         return True;
      end Count_Piece;
   begin
      Split (R, ",", Count_Piece'Access);
      Check (Count = 4, "Split (Process, String separator): piece count");
   end;

   --  --- Split (Separator : Character) ---

   declare
      Count  : Natural := 0;
      Pieces : array (1 .. 4) of Rope;

      function Collect (Piece : Rope) return Boolean is
      begin
         Count          := Count + 1;
         Pieces (Count) := Piece;
         return True;
      end Collect;
   begin
      Split (R, ',', Collect'Access);
      Check (Count = 4, "Split (Process, Character separator): piece count");
      Check
        (To_String (Pieces (1)) = "a" and then To_String (Pieces (2)) = "b" and then To_String (Pieces (3)) = ""
         and then To_String (Pieces (4)) = "c",
         "Split (Process, Character separator): piece contents in order");
   end;

   --  --- Split (Separator : Character_Set) ---

   declare
      Seps  : constant Character_Set := To_Set (",;");
      Count : Natural                := 0;

      function Count_Piece (Piece : Rope) return Boolean is
         pragma Unreferenced (Piece);
      begin
         Count := Count + 1;
         return True;
      end Count_Piece;
   begin
      Split (From_String ("a,b;c"), Seps, Count_Piece'Access);
      Check (Count = 3, "Split (Process, Character_Set separator): piece count, two different set members");
   end;

   declare
      Count : Natural := 0;

      function Collect_One (Piece : Rope) return Boolean is
      begin
         Count := Count + 1;
         Check
           (To_String (Piece) = "abc", "Split (Process, Character_Set separator) with Null_Set: the one piece is the whole rope");
         return True;
      end Collect_One;
   begin
      Split (From_String ("abc"), Null_Set, Collect_One'Access);
      Check (Count = 1, "Split (Process, Character_Set separator) with Null_Set calls Process exactly once");
   end;

   --  A separator that ends the rope: see test_split.adb's check.
   declare
      Count : Natural := 0;
      Last  : Rope    := From_String ("not visited");

      function Collect (Piece : Rope) return Boolean is
      begin
         Count := Count + 1;
         Last  := Piece;
         return True;
      end Collect;
   begin
      Split (From_String ("a::b::"), "::", Collect'Access);
      Check
        (Count = 3 and then Is_Empty (Last), "Split (Process, String separator): one ending the rope gives a last, empty piece");
      Count := 0;
      Last  := From_String ("not visited");
      Split (From_String ("a,b,"), ',', Collect'Access);
      Check
        (Count = 3 and then Is_Empty (Last), "Split (Process, Character separator): one ending the rope gives a last, empty piece");
      Count := 0;
      Last  := From_String ("not visited");
      Split (From_String ("a,b;"), To_Set (",;"), Collect'Access);
      Check
        (Count = 3 and then Is_Empty (Last),
         "Split (Process, Character_Set separator): one ending the rope gives a last, empty piece");
   end;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Split_Visitor;
