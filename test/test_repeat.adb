--  Phase 7 checks: "*" (Natural, Rope) and "*" (Natural, Character).
--  See PLAN.md's phased plan and "Construction and concatenation"
--  section, and RopeTest.Mod's CheckCompareFindRepeat (its Repeat
--  scenarios), CheckFromCharAndMake (its Make scenarios), and
--  CheckOverflowGuard -- this is where these two operators' checks
--  come from, since PLAN.md ended up naming them "*" (matching
--  Ada.Strings.Fixed's own "*" (Natural, Character/String) operators)
--  rather than Ropes.Mod's Repeat/Make names; see ropes.ads's doc
--  comment on "*" for why. The MAX(LONGINT) boundary in
--  CheckOverflowGuard translates to Natural'Last here.

with Ada.Command_Line;   use Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Text_IO;        use Ada.Text_IO;
with Ropes;              use Ropes;
with Ropes.Test_Support; use Ropes.Test_Support;

procedure Test_Repeat is

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

begin
   Check (To_String (4 * From_String ("ab")) = "abababab", """*"" (Natural, Rope): content");
   Check (Length (4 * From_String ("ab")) = 8, """*"" (Natural, Rope): length");
   Check (Is_Empty (0 * From_String ("x")), """*"" (Natural, Rope) 0 times is Null_Rope");
   Check (Is_Empty (5 * Null_Rope), """*"" (Natural, Rope) of Null_Rope is Null_Rope");

   Check (To_String (5 * 'z') = "zzzzz", """*"" (Natural, Character): content");
   Check (Is_Empty (0 * 'z'), """*"" (Natural, Character) 0 times is Null_Rope");

   --  Phase 23: "*" (Natural, String), Ada.Strings.Unbounded's own
   --  third "*", against Ada.Strings.Fixed's "*" (Natural, String).
   declare
      All_Agree : Boolean := True;
   begin
      for N in 0 .. 9 loop
         if To_String (N * "abc") /= Ada.Strings.Fixed."*" (N, "abc") then
            All_Agree := False;
         end if;
      end loop;
      Check (All_Agree, """*"" (Natural, String): 0 .. 9 times agree with Ada.Strings.Fixed");
   end;
   Check (To_String (3 * "abc") = "abcabcabc", """*"" (Natural, String): content");
   Check (Is_Empty (5 * "") and then Is_Empty (0 * "abc"), """*"" (Natural, String): of """" or 0 times is Null_Rope");
   Check
     (Length (1_000_000 * "abcdefghij") = 10_000_000 and then Depth (1_000_000 * "abcdefghij") < 40,
      """*"" (Natural, String): a million times is cheap, shared by doubling");

   --  A rope built by balanced binary doubling should come out with a
   --  close-to-minimal Depth -- Ropes has no public Balance/Depth to
   --  check the paper's strict IsBalanced definition directly (Phase 2
   --  deliberately keeps those internal), so this is the same
   --  Depth-stays-bounded proxy test_balance.adb already uses,
   --  applied to "*" instead of repeated AppendChar.
   Check (Depth (200 * From_String ("0123456789012345")) < 20, """*"" (Natural, Rope): binary doubling stays well-balanced");

   declare
      --  Exactly at the boundary: (Natural'Last - 1) + 1 = Natural'Last,
      --  which must succeed -- only a combined length that would exceed
      --  Natural'Last raises Ada.Strings.Length_Error (see New_Concat's
      --  overflow guard). Cheap even at this size: "*"'s binary
      --  doubling shares subtrees instead of allocating Natural'Last
      --  real characters.
      R : constant Rope := (Natural'Last - 1) * 'x' & 'y';
   begin
      Check (Length (R) = Natural'Last, """&"" right at the Natural'Last boundary succeeds");
   end;

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Repeat;
