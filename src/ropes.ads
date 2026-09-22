--  Ropes -- an Ada port of Boehm/Atkinson/Plass ropes ("Ropes: an
--  Alternative to Strings", Software--Practice and Experience 25(12),
--  1315-1330, 1995), following the scope and engineering choices of
--  the Oberon-2 port at ~/Repos/Oberon/oberon-tools/Rope.Mod (a
--  "core" rope: flat leaves and concatenation nodes only), reworked
--  with Ada idioms in place of Rope.Mod's Oberon-2 ones. See
--  PLAN.md for the full design rationale and AGENTS.md for house
--  conventions specific to this codebase.
--
--  This is Phase 1+2+3+4 of PLAN.md's phased implementation plan: the
--  Rope/Node skeleton, reference counting, the smallest useful slice
--  of the API (Length, Is_Empty, "&", From_String/To_String,
--  Element), "&"'s automatic depth-bounded rebalancing,
--  Slice/Insert/Delete, the five comparison operators, and now Index
--  and Split. Iteration and case mapping are later phases -- see
--  PLAN.md before adding to this package.
--
--  A Rope is an immutable value: every operation returns a new Rope
--  rather than modifying an existing one, so Ropes may be freely
--  shared and copied -- copying is O(1) (a reference-count bump), not
--  a deep copy. The empty rope is Null_Rope, also Rope's default
--  value: "R : Rope;" with no initial expression is already a valid
--  empty rope, not an uninitialized one.

with Ada.Finalization;
with Ada.Strings;
with Ada.Strings.Maps;

package Ropes is

   type Rope is private;

   Null_Rope : constant Rope;

   function Length (Source : Rope) return Natural;

   function Is_Empty (Source : Rope) return Boolean;

   function "&" (Left, Right : Rope) return Rope;
   --  Concatenation. O(1) amortized, except when both operands are
   --  short flat leaves (Rope.Mod's short-leaf merge, ported as-is):
   --  then the result is copied into one new leaf instead of adding a
   --  tree level, so that repeated single-character "&" does not grow
   --  an ever-deeper skinny tree. Raises Ada.Strings.Length_Error if
   --  the combined length would exceed Natural'Last.
   --
   --  If the result's tree depth would reach an internal bound, it is
   --  automatically rebalanced (Rope.Mod's Cat/Balance, the
   --  Fibonacci-forest algorithm) so that Element/Slice/etc. stay
   --  logarithmic even after many incremental "&" calls -- see
   --  PLAN.md's "Balancing" section. Transparent to callers; there is
   --  no public Balance or Depth to call directly (unlike Rope.Mod).

   function From_String (Source : String) return Rope;
   --  Null_Rope if Source is empty.

   function To_String (Source : Rope) return String;
   --  "" if Source is Null_Rope.

   function Element (Source : Rope; Index : Positive) return Character;
   --  Raises Ada.Strings.Index_Error if Index > Length (Source).

   function Slice (Source : Rope; Low : Positive; High : Natural) return Rope;
   --  The slice at positions Low through High, inclusive -- matches
   --  Ada.Strings.Unbounded.Slice exactly, including its edge cases:
   --  Null_Rope (not an error) if High < Low, even if Low = Length
   --  (Source) + 1; raises Ada.Strings.Index_Error if Low - 1 >
   --  Length (Source) or High > Length (Source). Rope.Mod's
   --  Substring (start, len), but with inclusive 1-based Low/High
   --  instead of a 0-based (start, len) pair, and Index_Error instead
   --  of clamping -- see PLAN.md's "Access and slicing".

   function Insert (Source : Rope; Before : Positive; New_Item : Rope) return Rope;
   --  Source with New_Item spliced in just before index Before.
   --  Raises Ada.Strings.Index_Error if Before - 1 > Length (Source)
   --  -- Before = Length (Source) + 1 (append) is valid, matching
   --  Ada.Strings.Unbounded.Insert. Rope.Mod's Insert, unclamped.

   function Delete (Source : Rope; From : Positive; Through : Natural) return Rope;
   --  Source with the characters from From through Through, inclusive,
   --  removed. Source unchanged (not an error) if Through < From, even
   --  if From is out of range; a Through past the end is clamped to
   --  Length (Source) (also not an error). Raises
   --  Ada.Strings.Index_Error only if From <= Through and From - 1 >
   --  Length (Source) -- matches Ada.Strings.Unbounded.Delete exactly.
   --  Rope.Mod's Remove, unclamped except where Ada.Strings.Unbounded
   --  itself still clamps (Through past the end).

   function "=" (Left, Right : Rope) return Boolean;
   function "<" (Left, Right : Rope) return Boolean;
   function "<=" (Left, Right : Rope) return Boolean;
   function ">" (Left, Right : Rope) return Boolean;
   function ">=" (Left, Right : Rope) return Boolean;
   --  Lexicographic, character by character, then by length on a
   --  common prefix -- Rope.Mod's Compare/Equal, exposed as the
   --  standard operators instead of a -1/0/1 function. "=" replaces
   --  the predefined (pointer-identity-based) equality that a private
   --  type wrapping a Controlled component would otherwise get.

   function Index (Source : Rope; Pattern : Rope; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   function Index
     (Source : Rope; Pattern : Rope; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   --  The 1-based starting index of Pattern's first (Going => Forward)
   --  or last (Going => Backward) occurrence in Source, or 0 if
   --  Pattern does not occur. Raises Ada.Strings.Pattern_Error if
   --  Pattern is Null_Rope, matching Ada.Strings.Fixed.Index exactly
   --  -- NOT Rope.Mod's Find, which instead treats an empty pattern as
   --  matching at "from". The From overload matches
   --  Ada.Strings.Fixed.Index's own From-bounded overload exactly,
   --  including its asymmetry: Forward never raises for an
   --  out-of-range From (Source (From .. Length (Source)) is simply
   --  empty, so the search just finds nothing), but Backward raises
   --  Ada.Strings.Index_Error if From > Length (Source); and if Source
   --  itself is Null_Rope, both overloads return 0 immediately, even
   --  when Pattern is also Null_Rope (Source's emptiness is checked
   --  before Pattern's) -- see PLAN.md's "Search" section.

   function Index (Source : Rope; Pattern : Character; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   function Index
     (Source : Rope; Pattern : Character; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   --  As above, searching for a single Character instead -- Rope.Mod's
   --  IndexChar/RIndexChar. No empty-pattern case; the same From/Going
   --  boundary rules apply.

   type Rope_Array is array (Positive range <>) of Rope;

   function Split (Source : Rope; Separator : Rope) return Rope_Array;
   function Split (Source : Rope; Separator : String) return Rope_Array;
   function Split (Source : Rope; Separator : Character) return Rope_Array;
   function Split (Source : Rope; Separator : Ada.Strings.Maps.Character_Set) return Rope_Array;
   --  Source split at each non-overlapping occurrence of Separator,
   --  Python str.split's convention: always exactly one more piece
   --  than the number of occurrences, so a leading, trailing, or
   --  doubled separator yields an empty piece (Rope.Mod's Split, but
   --  returning the pieces instead of visiting them through a
   --  callback). An empty Separator (Null_Rope or "") never splits --
   --  Source is the array's one element -- matching Rope.Mod exactly;
   --  the Character overload has no empty case; the Character_Set
   --  overload's empty case is Ada.Strings.Maps.Null_Set. The
   --  Character_Set overload does not collapse adjacent matches: N
   --  consecutive separator characters produce N - 1 empty pieces
   --  between them, one split per character.

private

   type Node_Kind is (Leaf_Kind, Concat_Kind);

   type Node;
   type Node_Access is access Node;

   type Node (Kind : Node_Kind; Len : Positive) is record
      Depth     : Natural := 0;
      Ref_Count : Natural := 1;
      case Kind is
         when Leaf_Kind =>
            Chars : String (1 .. Len);

         when Concat_Kind =>
            --  Never null -- see PLAN.md's acyclic-invariant note:
            --  every Node is built strictly bottom-up from
            --  already-built children and never mutated afterward.
            Left, Right : Node_Access;
      end case;
   end record;

   --  Rope is deliberately untagged: a plain private record wrapping
   --  one Ada.Finalization.Controlled component (Rope_Ref) for
   --  reference counting, not "new Controlled with private" directly.
   --  See AGENTS.md and PLAN.md's "Rope, Node, and memory management"
   --  section for why -- in short, RM 3.9.3(10) forbids a subprogram
   --  from being a dispatching primitive of two different tagged
   --  types declared in the same package, which would bite the moment
   --  a tagged iteration Cursor exists alongside a tagged Rope. RM 7.6
   --  finalizes/adjusts a controlled component automatically even
   --  when the enclosing type is itself untagged, so reference
   --  counting still works, one level removed.
   type Rope_Ref is new Ada.Finalization.Controlled with record
      Data : Node_Access := null;
   end record;

   overriding procedure Adjust (R : in out Rope_Ref);
   overriding procedure Finalize (R : in out Rope_Ref);

   --  Rope is also deliberately NOT limited, for a related but
   --  separate reason: RM 7.6 defines assignment of a type with a
   --  controlled component as Finalize the target's old value, copy,
   --  then Adjust the new value -- exactly Decr_Ref the old Data, copy
   --  the Node_Access, Incr_Ref the new Data. That is the entire
   --  refcounting scheme; plain ":=" already does it. Were Rope
   --  limited private instead, ordinary assignment ("R2 := R1;")
   --  would not be available to clients at all, defeating the point --
   --  see the "may be freely shared and copied" claim in this file's
   --  header comment, and Ada.Strings.Unbounded.Unbounded_String,
   --  which is likewise a non-limited private type specifically so it
   --  behaves like an ordinary value everywhere (records, arrays,
   --  Ada.Containers instantiations, ...).
   type Rope is record
      Ref : Rope_Ref;
   end record;

   Null_Rope : constant Rope := (Ref => (Ada.Finalization.Controlled with Data => null));

end Ropes;
