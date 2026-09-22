--  Phase 2 checks: the depth-triggered auto-rebalance layered onto
--  "&" (Rope.Mod's Cat/Balance, the Fibonacci-forest algorithm). See
--  PLAN.md's phased plan and Testing approach, and RopeTest.Mod's
--  CheckStressAndBalance
--  (~/Repos/Oberon/oberon-tools/RopeTest.Mod), which this is sourced
--  from -- translated to 1-based indexing, and using
--  Ropes.Test_Support.Depth in place of Rope.Mod's public Depth/
--  MaxDepth/Balance/IsBalanced (none of which Ropes exposes publicly
--  -- see ropes-test_support.ads).

with Ada.Command_Line;   use Ada.Command_Line;
with Ada.Text_IO;        use Ada.Text_IO;
with Ropes;              use Ropes;
with Ropes.Test_Support; use Ropes.Test_Support;

procedure Test_Balance is

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

   function Cycled_Char (I : Natural) return Character is (Character'Val (Character'Pos ('a') + I mod 26));

   R  : Rope := Null_Rope;
   Ok : Boolean;

begin
   --  Build a rope by appending one character at a time, the way a
   --  naive caller building up output would. Without the short-leaf
   --  merge, this would grow one Concat level per character (depth
   --  2000); with only the short-leaf merge and no depth-triggered
   --  rebalance, roughly one Concat level per Short_Leaf_Length
   --  characters (depth ~125). "&"'s depth check (Balance, once
   --  Depth reaches Max_Depth) keeps the actual depth well below
   --  either.
   for I in 0 .. 1_999 loop
      R := R & From_String ([Cycled_Char (I)]);
   end loop;

   Check (Length (R) = 2_000, "Append x2000: length");
   Check (Element (R, 1) = 'a', "Append x2000: first character");
   Check (Element (R, 2_000) = Cycled_Char (1_999), "Append x2000: last character");

   Ok := True;
   for I in 1 .. 2_000 loop
      if Element (R, I) /= Cycled_Char (I - 1) then
         Ok := False;
      end if;
   end loop;
   Check (Ok, "Append x2000: every character matches");

   --  60 is a generous, non-hardcoded-Max_Depth bound: comfortably
   --  above whatever Max_Depth actually computes to (44 on a 32-bit
   --  Natural), comfortably below the ~125 a short-leaf-merge-only,
   --  never-rebalanced tree would reach for 2000 characters.
   Check (Depth (R) < 60, "Append x2000: depth stays bounded well below linear growth");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Balance;
