--  Phase 24 checks: Hash, Hash_Case_Insensitive,
--  Equal_Case_Insensitive and Less_Case_Insensitive -- RM A.4.9 and
--  A.4.10's Ada.Strings.Unbounded ones. No Rope.Mod counterpart. The
--  oracles are GNAT's own Ada.Strings functions of the same names on
--  the same text, over ropes of two different leaf chunkings (9 and 17
--  characters; 9 + 9 > 16, the short-leaf merge threshold, so leaves
--  stay separate) and over every pair of Latin-1 characters, since
--  case folding is Ada.Characters.Handling.To_Lower's, accented
--  letters included. Hash agreeing with Ada.Strings.Hash is GNAT's
--  behavior, not the RM's promise (Ada.Strings.Hash's value is
--  implementation-defined).

with Ada.Command_Line; use Ada.Command_Line;
with Ada.Containers;   use Ada.Containers;
with Ada.Containers.Hashed_Maps;
with Ada.Containers.Ordered_Sets;
with Ada.Strings.Equal_Case_Insensitive;
with Ada.Strings.Hash;
with Ada.Strings.Hash_Case_Insensitive;
with Ada.Strings.Less_Case_Insensitive;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;

procedure Test_Hash is

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

   --  Mixed case, Latin-1 accented letters (whose To_Lower differs)
   --  and characters To_Lower leaves alone, such as the German sharp
   --  s and y with diaeresis, which have no Latin-1 capital.
   Text  : constant String :=
     "The Quick BROWN fox " & Character'Val (16#C0#) & Character'Val (16#E9#) & Character'Val (16#DF#) & Character'Val (16#FF#) &
     " jumps Over the LAZY dog; 0123456789 [\]^_`{|}~ THE END.";
   Lower : constant String :=
     "the quick brown fox " & Character'Val (16#E0#) & Character'Val (16#E9#) & Character'Val (16#DF#) & Character'Val (16#FF#) &
     " jumps over the lazy dog; 0123456789 [\]^_`{|}~ the end.";

   A9  : constant Rope := Chunked (Text, 9);
   A17 : constant Rope := Chunked (Text, 17);
   L9  : constant Rope := Chunked (Lower, 9);

   Prefixes_Agree, Pairs_Agree, Hashes_Agree : Boolean := True;

   package Rope_Counts is new Ada.Containers.Hashed_Maps
     (Key_Type => Rope, Element_Type => Positive, Hash => Hash, Equivalent_Keys => "=");

   package Folded_Counts is new Ada.Containers.Hashed_Maps
     (Key_Type => Rope, Element_Type => Positive, Hash => Hash_Case_Insensitive, Equivalent_Keys => Equal_Case_Insensitive);

   package Folded_Sets is new Ada.Containers.Ordered_Sets
     (Element_Type => Rope, "<" => Less_Case_Insensitive, "=" => Equal_Case_Insensitive);

   Words : constant array (1 .. 7) of Rope :=
     [Chunked ("apple", 2), Chunked ("Apple", 3), Chunked ("APPLE", 1), Chunked ("banana", 4), Chunked ("Banana", 6),
     Chunked ("cherry", 5), Chunked ("apple", 3)];

   Exact  : Rope_Counts.Map;
   Folded : Folded_Counts.Map;
   Sorted : Folded_Sets.Set;

   procedure Tally (Word : Rope) is
   begin
      if Exact.Contains (Word) then
         Exact.Replace (Word, Exact.Element (Word) + 1);
      else
         Exact.Insert (Word, 1);
      end if;
      if Folded.Contains (Word) then
         Folded.Replace (Word, Folded.Element (Word) + 1);
      else
         Folded.Insert (Word, 1);
      end if;
      Sorted.Include (Word);
   end Tally;

   Starred : constant Rope := 100_000 * Chunked ("Ab,cD;", 3);

begin
   Check (To_String (A9) = Text and then To_String (A17) = Text, "the test ropes have the expected text");

   Check
     (Hash (A9) = Ada.Strings.Hash (Text) and then Hash (A17) = Hash (A9),
      "Hash: GNAT's Ada.Strings.Hash of the text, whatever the leaf chunking");
   Check
     (Hash_Case_Insensitive (A9) = Ada.Strings.Hash_Case_Insensitive (Text)
      and then Hash_Case_Insensitive (A17) = Hash_Case_Insensitive (L9),
      "Hash_Case_Insensitive: GNAT's, and the same for either case");
   Check (Hash (A9) /= Hash (L9), "Hash: distinguishes case");
   Check (Hash (Null_Rope) = Ada.Strings.Hash ("") and then Hash_Case_Insensitive (Null_Rope) = 0, "Null_Rope hashes as """"");
   Check
     (Hash (Starred) = Ada.Strings.Hash (To_String (Starred))
      and then Hash_Case_Insensitive (Starred) = Ada.Strings.Hash_Case_Insensitive (To_String (Starred)),
      "a ""*""-built rope, whose subtrees are shared");

   for I in 0 .. Text'Length loop
      declare
         T : String renames Text (Text'First .. Text'First + I - 1);
      begin
         if Hash (Chunked (T, 9)) /= Ada.Strings.Hash (T)
           or else Hash_Case_Insensitive (Chunked (T, 17)) /= Ada.Strings.Hash_Case_Insensitive (T)
         then
            Hashes_Agree := False;
         end if;
      end;
   end loop;
   Check (Hashes_Agree, "Hash and Hash_Case_Insensitive: every prefix agrees with Ada.Strings'");

   Check
     (Equal_Case_Insensitive (A9, L9) and then Equal_Case_Insensitive (A17, A9) and then not (A9 = L9),
      "Equal_Case_Insensitive: across case and leaf chunkings; ""="" still tells case apart");
   Check
     (Equal_Case_Insensitive (A9, A9) and then Equal_Case_Insensitive (Null_Rope, Null_Rope),
      "Equal_Case_Insensitive: itself, and Null_Rope");
   Check
     (not Equal_Case_Insensitive (A9, Chunked (Lower (Lower'First .. Lower'Last - 1), 9))
      and then not Equal_Case_Insensitive (Null_Rope, A9),
      "Equal_Case_Insensitive: a proper prefix, or Null_Rope, is not equal");

   --  Every prefix of Text against every prefix of Lower, in two
   --  different chunkings: exercises the leaf-run logic of the
   --  case-insensitive compare the way test_compare.adb does "<".
   for I in 0 .. Text'Length loop
      for J in 0 .. Lower'Length loop
         declare
            L   : String renames Text (Text'First .. Text'First + I - 1);
            R   : String renames Lower (Lower'First .. Lower'First + J - 1);
            L_R : constant Rope := Chunked (L, 9);
            R_R : constant Rope := Chunked (R, 17);
         begin
            if Less_Case_Insensitive (L_R, R_R) /= Ada.Strings.Less_Case_Insensitive (L, R)
              or else Less_Case_Insensitive (R_R, L_R) /= Ada.Strings.Less_Case_Insensitive (R, L)
              or else Equal_Case_Insensitive (L_R, R_R) /= Ada.Strings.Equal_Case_Insensitive (L, R)
            then
               Prefixes_Agree := False;
            end if;
         end;
      end loop;
   end loop;
   Check (Prefixes_Agree, "Less/Equal_Case_Insensitive: every pair of prefixes agrees with Ada.Strings'");

   for C1 in Character loop
      for C2 in Character loop
         declare
            L : constant String := "x" & C1;
            R : constant String := "x" & C2;
         begin
            if Less_Case_Insensitive (From_String (L), From_String (R)) /= Ada.Strings.Less_Case_Insensitive (L, R)
              or else Equal_Case_Insensitive (From_String (L), From_String (R)) /= Ada.Strings.Equal_Case_Insensitive (L, R)
              or else Hash_Case_Insensitive (From_String (L)) /= Ada.Strings.Hash_Case_Insensitive (L)
            then
               Pairs_Agree := False;
            end if;
         end;
      end loop;
   end loop;
   Check (Pairs_Agree, "every pair of Latin-1 characters folds as Ada.Strings' case-insensitive functions do");

   for W of Words loop
      Tally (W);
   end loop;
   Check
     (Natural (Exact.Length) = 6 and then Exact.Element (From_String ("apple")) = 2
      and then Exact.Element (From_String ("Banana")) = 1,
      "Hashed_Maps keyed by Rope with Hash and ""="": exact words");
   Check
     (Natural (Folded.Length) = 3 and then Folded.Element (From_String ("aPPle")) = 4
      and then Folded.Element (From_String ("BANANA")) = 2,
      "Hashed_Maps with Hash_Case_Insensitive and Equal_Case_Insensitive: words in any case");
   Check
     (Natural (Sorted.Length) = 3 and then Equal_Case_Insensitive (Sorted.First_Element, From_String ("APPLE"))
      and then Equal_Case_Insensitive (Sorted.Last_Element, From_String ("Cherry")),
      "Ordered_Sets with Less_Case_Insensitive: sorted, one per word in any case");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Hash;
