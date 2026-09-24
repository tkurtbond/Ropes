--  Phase 1 checks: Rope/Node construction, refcounting, Length,
--  Is_Empty, plain "&" (short-leaf merge only, no rebalancing yet),
--  From_String/To_String, Element. See PLAN.md's phased plan and
--  Testing approach, and RopeTest.Mod
--  (~/Repos/Oberon/Ropes/RopeTest.Mod), which this is sourced
--  from -- CheckConstruction, CheckLengthAndFetch and CheckCat's
--  content-only assertions, translated to 1-based indexing and to
--  Ada.Strings.Index_Error where Ropes.Mod clamped.

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Construction is

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

   procedure Check_Index_Error (Source : Rope; Index : Positive; Name : String) is
   begin
      declare
         Unused : constant Character := Element (Source, Index);
      begin
         Check (False, Name);
      end;
   exception
      when Ada.Strings.Index_Error =>
         Check (True, Name);
   end Check_Index_Error;

begin
   --  --- Construction ---
   Check (Is_Empty (From_String ("")), "From_String of an empty string Is_Empty");
   Check (not Is_Empty (From_String ("x")), "not Is_Empty (From_String (x))");
   Check (To_String (From_String ("hello")) = "hello", "From_String/To_String round trip");
   Check (Length (From_String ("hello")) = 5, "Length of From_String (hello)");
   Check (To_String (Null_Rope) = "", "To_String (Null_Rope) gives an empty string");
   Check (Length (Null_Rope) = 0, "Length (Null_Rope) = 0");
   Check (Is_Empty (Null_Rope), "Is_Empty (Null_Rope)");

   --  --- Element ---
   Check (Element (From_String ("abcde"), 1) = 'a', "Element: first character");
   Check (Element (From_String ("abcde"), 5) = 'e', "Element: last character");
   Check_Index_Error (From_String ("abcde"), 6, "Element: one past the end raises Index_Error");
   Check_Index_Error (Null_Rope, 1, "Element on Null_Rope raises Index_Error");

   --  --- "&" ---
   Check (To_String (Null_Rope & From_String ("foo")) = "foo", "Null_Rope & x has x's content");
   Check (To_String (From_String ("foo") & Null_Rope) = "foo", "x & Null_Rope has x's content");

   --  Both short leaves (2 + 2 <= Short_Leaf_Length): merges into one leaf.
   Check (To_String (From_String ("ab") & From_String ("cd")) = "abcd", "Cat of two short leaves: content");
   Check (Length (From_String ("ab") & From_String ("cd")) = 4, "Cat of two short leaves: length");

   --  Two large leaves (16 + 10 > Short_Leaf_Length): an ordinary
   --  Concat node, not a merge.
   declare
      R : constant Rope := From_String ("0123456789012345") & From_String ("abcdefghij");
   begin
      Check (To_String (R) = "0123456789012345abcdefghij", "Cat of two large leaves: content");
      Check (Length (R) = 26, "Cat of two large leaves: length");
   end;

   --  Mirrors Ropes.Mod's CheckCat (content only -- Depth is not part
   --  of Phase 1's public API): the first "0123456789012345" append
   --  (16 chars) forces a real Concat (4 + 16 > 16). The "01234"
   --  append (5 chars) does NOT absorb into that 16-char right leaf
   --  either (16 + 5 > 16) -- it adds another Concat level. Only the
   --  final "x" append absorbs, into the 5-char right leaf (5 + 1 <=
   --  16).
   declare
      R : Rope := From_String ("ab") & From_String ("cd");
   begin
      R := R & From_String ("0123456789012345");  --  forces a real Concat
      R := R & From_String ("01234");              --  also a real Concat (16 + 5 > 16)
      R := R & From_String ("x");                  --  absorbs into the 5-char right leaf
      Check (To_String (R) = "abcd012345678901234501234x", "Absorbing a short leaf: content");
      Check (Length (R) = 26, "Absorbing a short leaf: length");
   end;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Construction;
