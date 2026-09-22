--  Phase 4 checks: Split, all four overloads. See PLAN.md's phased
--  plan and Testing approach, and RopeTest.Mod's CheckSplit
--  (~/Repos/Oberon/oberon-tools/RopeTest.Mod). Rope.Mod's Split is a
--  visitor callback (and SplitList builds a linked list); Ropes.Split
--  just returns the array, matching Rope.Mod's own SplitArray instead
--  -- so CheckSplit's "stops early when visit returns FALSE" case and
--  SplitList's cases don't translate (no visitor/list API exists
--  here). Everything else -- piece count and contents, NIL source,
--  absent separator, empty separator -- translates directly.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Split is

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
      P : constant Rope_Array := Split (R, From_String (","));
   begin
      Check (P'Length = 4, "Split (Rope separator): visits every piece, including an empty one");
      Check
        (To_String (P (1)) = "a" and then To_String (P (2)) = "b" and then To_String (P (3)) = "" and then To_String (P (4)) = "c",
         "Split (Rope separator): piece contents in order");
   end;

   declare
      P : constant Rope_Array := Split (Null_Rope, From_String (","));
   begin
      Check (P'Length = 1 and then To_String (P (1)) = "", "Split of Null_Rope gives one empty piece");
   end;

   declare
      P : constant Rope_Array := Split (From_String ("abc"), From_String (","));
   begin
      Check (P'Length = 1 and then To_String (P (1)) = "abc", "Split with an absent separator gives one piece: the whole rope");
   end;

   declare
      P : constant Rope_Array := Split (From_String ("abc"), Null_Rope);
   begin
      Check (P'Length = 1 and then To_String (P (1)) = "abc", "Split (Rope separator) with an empty separator never splits");
   end;

   --  --- Split (Separator : String) -- pure ergonomics over the Rope overload ---

   declare
      P : constant Rope_Array := Split (R, ",");
   begin
      Check (P'Length = 4, "Split (String separator): piece count");
      Check
        (To_String (P (1)) = "a" and then To_String (P (2)) = "b" and then To_String (P (3)) = "" and then To_String (P (4)) = "c",
         "Split (String separator): piece contents in order");
   end;

   declare
      P : constant Rope_Array := Split (From_String ("abc"), "");
   begin
      Check (P'Length = 1 and then To_String (P (1)) = "abc", "Split (String separator) with an empty separator never splits");
   end;

   --  --- Split (Separator : Character) ---

   declare
      P : constant Rope_Array := Split (R, ',');
   begin
      Check (P'Length = 4, "Split (Character separator): piece count");
      Check
        (To_String (P (1)) = "a" and then To_String (P (2)) = "b" and then To_String (P (3)) = "" and then To_String (P (4)) = "c",
         "Split (Character separator): piece contents in order");
   end;

   declare
      P : constant Rope_Array := Split (Null_Rope, ',');
   begin
      Check (P'Length = 1 and then To_String (P (1)) = "", "Split (Character separator) of Null_Rope gives one empty piece");
   end;

   --  --- Split (Separator : Character_Set) ---

   declare
      Seps : constant Character_Set := To_Set (",;");
      P    : constant Rope_Array    := Split (From_String ("a,b;c"), Seps);
   begin
      Check (P'Length = 3, "Split (Character_Set separator): piece count, two different set members");
      Check
        (To_String (P (1)) = "a" and then To_String (P (2)) = "b" and then To_String (P (3)) = "c",
         "Split (Character_Set separator): piece contents in order");
   end;

   declare
      Seps : constant Character_Set := To_Set (",;");
      P    : constant Rope_Array    := Split (From_String ("a,;b"), Seps);
   begin
      Check
        (P'Length = 3 and then To_String (P (1)) = "a" and then To_String (P (2)) = "" and then To_String (P (3)) = "b",
         "Split (Character_Set separator) does not collapse two adjacent, distinct set members");
   end;

   declare
      P : constant Rope_Array := Split (From_String ("abc"), Null_Set);
   begin
      Check (P'Length = 1 and then To_String (P (1)) = "abc", "Split (Character_Set separator) with Null_Set never splits");
   end;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Split;
