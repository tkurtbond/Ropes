--  Ropes -- an Ada port of Boehm/Atkinson/Plass ropes ("Ropes: an
--  Alternative to Strings", Software--Practice and Experience 25(12),
--  1315-1330, 1995), following the scope and engineering choices of
--  the Oberon-2 port at ~/Repos/Oberon/oberon-tools/Rope.Mod (a
--  "core" rope: flat leaves and concatenation nodes only), reworked
--  with Ada idioms in place of Rope.Mod's Oberon-2 ones. See
--  PLAN.md for the full design rationale and AGENTS.md for house
--  conventions specific to this codebase.
--
--  This is Phase 1 through 8 -- the whole of PLAN.md's phased
--  implementation plan (Phases 7 and 8 both stretch phases, beyond
--  matching Rope.Mod's own scope): the Rope/Node skeleton, reference
--  counting, the smallest useful slice of the API (Length, Is_Empty,
--  "&", From_String/To_String, Element), "&"'s automatic depth-bounded
--  rebalancing, Slice/Insert/Delete, the five comparison operators,
--  Index and Split, Cursor-based iteration ("for Ch of Some_Rope
--  loop"), Trim, Map/Map_Indexed, To_Upper/To_Lower,
--  Capitalize/Uncapitalize, the remaining "&"/From_.../"*" construction
--  conveniences (From_Character, the Character/String "&" overloads,
--  From_Unbounded_String/To_Unbounded_String, "*"), Escape, and now
--  Overwrite/Head/Tail, Contains, and the Process-callback form of
--  Split. See PLAN.md before adding to this package.
--
--  A Rope is an immutable value: every operation returns a new Rope
--  rather than modifying an existing one, so Ropes may be freely
--  shared and copied -- copying is O(1) (a reference-count bump), not
--  a deep copy. The empty rope is Null_Rope, also Rope's default
--  value: "R : Rope;" with no initial expression is already a valid
--  empty rope, not an uninitialized one.

with Ada.Characters.Latin_1;
with Ada.Finalization;
with Ada.Strings;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;

package Ropes is

   type Rope is private with
     Iterable => (First => First, Next => Next, Has_Element => Has_Element, Element => Element);
   --  First/Next/Has_Element/Element are declared further down (see
   --  "Cursor-based traversal" below) -- Ada resolves this forward
   --  reference at Rope's freeze point, the standard idiom for the
   --  Iterable aspect (every GNAT-provided Iterable container gives
   --  the aspect this way, directly on the type declaration, not via
   --  a separate "for Rope use Iterable => (...)" clause -- the
   --  latter rejects this forward reference with "invalid
   --  representation clause").

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

   function "&" (Left : Rope; Right : Character) return Rope;
   function "&" (Left : Character; Right : Rope) return Rope;
   function "&" (Left : Rope; Right : String) return Rope;
   function "&" (Left : String; Right : Rope) return Rope;
   --  As above, with one side already a plain Character/String --
   --  Ada.Strings.Unbounded's own "&" suite exactly (Unbounded_String
   --  "&" Character/String and the mirror-image overloads). Each is
   --  just Left/Right wrapped with From_Character/From_String and
   --  passed to the Rope "&" Rope operator above -- convenience, not a
   --  separate algorithm.

   function From_String (Source : String) return Rope;
   --  Null_Rope if Source is empty.

   function From_Character (Source : Character) return Rope;
   --  A one-character Rope -- Rope.Mod's FromChar.

   function To_String (Source : Rope) return String;
   --  "" if Source is Null_Rope.

   procedure Process_Chunks (Source : Rope; Process : not null access procedure (Chunk : String));
   --  Calls Process once per leaf of Source, in order, passing that
   --  leaf's characters -- so the concatenation of every Chunk passed
   --  equals To_String (Source), but Source is never flattened into
   --  one String. Never called for Null_Rope, and never called with an
   --  empty Chunk. How Source is divided into chunks is unspecified
   --  (it depends on how Source was built); only their order and
   --  concatenation are. Chunk is a view of a leaf's own storage: it
   --  is only valid during that call, so copy it if it needs to
   --  outlive the call.
   --
   --  No Rope.Mod counterpart (Phase 11, at explicit user request --
   --  see PLAN.md): the general primitive for writing a rope anywhere
   --  -- a file (Ropes.Text_IO is built on this), a stream, a hash --
   --  without To_String's full O(Length) copy, which lives on the stack
   --  and so can overflow it for a large enough rope. Shaped like
   --  Ada.Containers' own Iterate/Query_Element (a Process
   --  access-to-procedure, no early stop); a caller wanting to stop
   --  early can raise and handle an exception, same as with those.

   function From_Unbounded_String (Source : Ada.Strings.Unbounded.Unbounded_String) return Rope;
   function To_Unbounded_String (Source : Rope) return Ada.Strings.Unbounded.Unbounded_String;
   --  No Rope.Mod counterpart (Oberon-2 has no unbounded string type)
   --  -- added because Ada does, and a rope library that cannot
   --  interop with the type most Ada code already uses for "a string
   --  that grows" would be an odd omission.

   function "*" (Left : Natural; Right : Character) return Rope;
   function "*" (Left : Natural; Right : Rope) return Rope;
   --  Left copies of Right, concatenated -- Null_Rope if Left = 0 (or
   --  Right is Null_Rope, for the Rope overload). Mirrors
   --  Ada.Strings.Fixed's own "*" (Natural, Character) and "*"
   --  (Natural, String) operators exactly, reusing that vocabulary
   --  instead of inventing separate Repeat/Make names (see AGENTS.md's
   --  "Reuse Ada.Strings vocabulary" convention) -- discovered only at
   --  Phase 7 implementation time; PLAN.md's original design sketch
   --  had named these Repeat/Make after Rope.Mod's own names, before
   --  this match was found. The Rope overload is Rope.Mod's Repeat:
   --  O(log Left) via binary doubling (Piece := Piece & Piece), sharing
   --  subtrees rather than copying characters, so even Left in the
   --  billions is cheap -- not Left successive "&" calls. The Character
   --  overload is Rope.Mod's Make, implemented as Left * From_Character
   --  (Right).

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

   procedure Copy_Slice (Source : Rope; Low : Positive; High : Natural; Target : in out String; Target_Low : Positive);
   --  Copies Source's characters Low through High, inclusive, into
   --  Target (Target_Low .. Target_Low + (High - Low)), leaving the rest
   --  of Target untouched -- the same characters as
   --  Target (Target_Low .. Target_Low + (High - Low)) := To_String
   --  (Slice (Source, Low, High)), but copied once, straight out of the
   --  leaves that overlap Low .. High, with no intermediate Rope and no
   --  String temporary on the stack (so a range of any length can be
   --  copied into, say, a heap-allocated String). Rope.Mod's Blit, with
   --  Slice's inclusive 1-based Low/High instead of Blit's 0-based
   --  (srcStart, len), and Target_Low an index into Target itself
   --  (which need not start at 1). Phase 15; see PLAN.md.
   --
   --  Source's bounds are checked exactly as Slice checks them: nothing
   --  is copied (not an error) if High < Low, even if Low = Length
   --  (Source) + 1; Ada.Strings.Index_Error if Low - 1 > Length
   --  (Source) or High > Length (Source). Ada.Strings.Index_Error too,
   --  rather than the Constraint_Error the slice assignment above would
   --  give, if a non-empty range does not fit in Target (Target_Low <
   --  Target'First or Target_Low + (High - Low) > Target'Last). Every
   --  check is made before anything is copied, so on Index_Error Target
   --  is unchanged.

   function Insert (Source : Rope; Before : Positive; New_Item : Rope) return Rope;
   --  Source with New_Item spliced in just before index Before.
   --  Raises Ada.Strings.Index_Error if Before - 1 > Length (Source)
   --  -- Before = Length (Source) + 1 (append) is valid, matching
   --  Ada.Strings.Unbounded.Insert. Rope.Mod's Insert, unclamped.

   function Insert (Source : Rope; Before : Positive; New_Item : String) return Rope;
   --  As above, with a String New_Item -- the form
   --  Ada.Strings.Unbounded.Insert itself takes. Same as Insert
   --  (Source, Before, From_String (New_Item)).

   function Delete (Source : Rope; From : Positive; Through : Natural) return Rope;
   --  Source with the characters from From through Through, inclusive,
   --  removed. Source unchanged (not an error) if Through < From, even
   --  if From is out of range; a Through past the end is clamped to
   --  Length (Source) (also not an error). Raises
   --  Ada.Strings.Index_Error only if From <= Through and From - 1 >
   --  Length (Source) -- matches Ada.Strings.Unbounded.Delete exactly.
   --  Rope.Mod's Remove, unclamped except where Ada.Strings.Unbounded
   --  itself still clamps (Through past the end).

   function Overwrite (Source : Rope; Position : Positive; New_Item : Rope) return Rope;
   --  Source with the characters from Position onward replaced by
   --  New_Item, extending Source if New_Item runs past its current end
   --  -- Ada.Strings.Unbounded.Overwrite's own signature and semantics
   --  exactly (function form only: there is no in-place Rope, the same
   --  reason Insert/Delete above have no procedure form either).
   --  Raises Ada.Strings.Index_Error if Position - 1 > Length (Source)
   --  -- Position = Length (Source) + 1 (append) is valid, matching
   --  Insert above. No Rope.Mod counterpart (Oberon-2's Rope has no
   --  positional-replace operation at all) -- see PLAN.md's "Deferred
   --  / stretch" section for why this was added anyway.

   function Overwrite (Source : Rope; Position : Positive; New_Item : String) return Rope;
   --  As above, with a String New_Item -- the form
   --  Ada.Strings.Unbounded.Overwrite itself takes. Same as Overwrite
   --  (Source, Position, From_String (New_Item)).

   function Replace_Slice (Source : Rope; Low : Positive; High : Natural; By : Rope) return Rope;
   function Replace_Slice (Source : Rope; Low : Positive; High : Natural; By : String) return Rope;
   --  Source with the characters from Low through High, inclusive,
   --  replaced by By -- Ada.Strings.Unbounded.Replace_Slice's own
   --  signature and semantics (function form only, as Overwrite
   --  above). If High >= Low, the result is Slice (Source, 1, Low - 1)
   --  & By & the rest of Source after High; a High past the end is
   --  clamped to Length (Source), not an error. If High < Low, the
   --  result is Insert (Source, Low, By). Raises
   --  Ada.Strings.Index_Error if Low - 1 > Length (Source), in either
   --  case. No Rope.Mod counterpart.

   function Head (Source : Rope; Count : Natural; Pad : Character := Ada.Strings.Space) return Rope;
   function Tail (Source : Rope; Count : Natural; Pad : Character := Ada.Strings.Space) return Rope;
   --  The first (Head) or last (Tail) Count characters of Source,
   --  padded on the right (Head) or left (Tail) with Pad if Count
   --  exceeds Length (Source) -- Ada.Strings.Unbounded.Head/Tail's own
   --  signatures and semantics exactly (function form only, as
   --  Overwrite above). No Rope.Mod counterpart, same as Overwrite.

   function "=" (Left, Right : Rope) return Boolean;
   function "<" (Left, Right : Rope) return Boolean;
   function "<=" (Left, Right : Rope) return Boolean;
   function ">" (Left, Right : Rope) return Boolean;
   function ">=" (Left, Right : Rope) return Boolean;
   --  Lexicographic, character by character, then by length on a
   --  common prefix -- Rope.Mod's Compare/Equal, exposed as the
   --  standard operators instead of a -1/0/1 function. "=" replaces
   --  the predefined (pointer-identity-based) equality that a private
   --  type wrapping a Controlled component would otherwise get. Time
   --  is linear in the common prefix, regardless of how differently
   --  the two ropes' trees are shaped, and O(1) for a rope compared
   --  with a copy of itself.

   function "=" (Left : Rope; Right : String) return Boolean;
   function "=" (Left : String; Right : Rope) return Boolean;
   function "<" (Left : Rope; Right : String) return Boolean;
   function "<" (Left : String; Right : Rope) return Boolean;
   function "<=" (Left : Rope; Right : String) return Boolean;
   function "<=" (Left : String; Right : Rope) return Boolean;
   function ">" (Left : Rope; Right : String) return Boolean;
   function ">" (Left : String; Right : Rope) return Boolean;
   function ">=" (Left : Rope; Right : String) return Boolean;
   function ">=" (Left : String; Right : Rope) return Boolean;
   --  As above, comparing a Rope with a String -- the mixed overloads
   --  Ada.Strings.Unbounded has for each operator. The same order as
   --  comparing Left with From_String (Right) (or From_String (Left)
   --  with Right), but the String is never copied into a rope: it is
   --  compared a leaf at a time, in time linear in the common prefix.
   --  The String need not start at index 1.

   function Index (Source : Rope; Pattern : Rope; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   function Index
     (Source : Rope; Pattern : Rope; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   --  The 1-based starting index of Pattern's first (Going => Forward)
   --  or last (Going => Backward) occurrence in Source, or 0 if
   --  Pattern does not occur. Raises Ada.Strings.Pattern_Error if
   --  Pattern is Null_Rope, matching Ada.Strings.Fixed.Index exactly
   --  -- NOT Rope.Mod's Find, which instead treats an empty pattern as
   --  matching at "from".
   --
   --  The From overload searches Source (From .. Length (Source))
   --  (Forward) or Source (1 .. From) (Backward). If Source is
   --  Null_Rope it returns 0 at once, even when Pattern is also
   --  Null_Rope (Source's emptiness is checked before Pattern's).
   --  Otherwise, a From past the end of Source is handled as GNAT's
   --  Ada.Strings.Fixed.Index handles it, which is NOT what the RM
   --  says:
   --
   --  * The RM (A.4.3(56.2/3), and 58.5/3 for the Character_Set
   --    overloads; the same since Ada 2005) says Index_Error whenever
   --    From is not in Source'Range, in either direction.
   --
   --  * GNAT (a-strsea.adb) checks only the bound its direction
   --    needs, then searches a slice: Forward raises only if From <
   --    Source'First, and otherwise returns Index (Source (From ..
   --    Source'Last), ...), which for From > Source'Last is a null
   --    slice, and so 0; Backward raises only if From > Source'Last.
   --    From is Positive and a rope starts at 1, so for a rope
   --    Forward never raises.
   --
   --  So here, as with GNAT, Forward with From > Length (Source)
   --  returns 0, where the RM says Index_Error; Backward with From >
   --  Length (Source) raises Ada.Strings.Index_Error, as both say.
   --  Ropes follows GNAT because that is what a caller moving from
   --  Ada.Strings.Fixed/Unbounded under GNAT actually gets, and
   --  because it is what makes the usual scan loop -- search, then
   --  search again from just past the match -- work without a guard
   --  when the match ends the rope (Split and Count here rely on it).
   --  Every From overload of Index (Rope, String, Character and
   --  Character_Set) follows this same rule. See PLAN.md's "Search"
   --  section.
   --
   --  Time, for every Index overload: O(depth) to reach From, then
   --  linear in the characters scanned, walking Source's leaves in
   --  place. A pattern search is the same naive algorithm as GNAT's
   --  Ada.Strings.Fixed.Index -- test each candidate's first
   --  character (last, Backward), then compare the rest -- so O(n m)
   --  at worst for a length-m pattern, and near O(n) when the
   --  pattern's first character is uncommon. A Rope Pattern of more
   --  than one leaf is first copied into a String on the heap.

   function Index (Source : Rope; Pattern : String; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   function Index
     (Source : Rope; Pattern : String; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   --  As above, with a String Pattern -- the form Ada.Strings.Fixed
   --  and Ada.Strings.Unbounded's own Index take. Same as Index
   --  (Source, From_String (Pattern), ...), including every boundary
   --  rule above: Ada.Strings.Pattern_Error for an empty Pattern ("",
   --  like Null_Rope), with Source's emptiness checked first in the
   --  From overload only.

   function Index (Source : Rope; Pattern : Character; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   function Index
     (Source : Rope; Pattern : Character; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   --  As above, searching for a single Character instead -- Rope.Mod's
   --  IndexChar/RIndexChar. No empty-pattern case; the same From/Going
   --  boundary rules apply.

   function Index
     (Source : Rope; Set : Ada.Strings.Maps.Character_Set; Test : Ada.Strings.Membership := Ada.Strings.Inside;
      Going  : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   function Index
     (Source : Rope; Set : Ada.Strings.Maps.Character_Set; From : Positive; Test : Ada.Strings.Membership := Ada.Strings.Inside;
      Going  : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
   --  The index of the first (Going => Forward) or last (Going =>
   --  Backward) character of Source that is in Set (Test => Inside)
   --  or not in Set (Test => Outside), or 0 if there is none --
   --  Ada.Strings.Unbounded's own Character_Set Index. The From
   --  overload follows the same boundary rules as the Rope overload
   --  above -- GNAT's, not the RM's, as explained there: 0 for a
   --  Null_Rope Source; Forward returns 0 for From > Length (Source),
   --  where the RM (A.4.3(58.5/3)) says Index_Error; Backward raises
   --  Ada.Strings.Index_Error if From > Length (Source).

   function Count (Source : Rope; Pattern : Rope) return Natural;
   function Count (Source : Rope; Pattern : String) return Natural;
   --  The number of nonoverlapping occurrences of Pattern in Source,
   --  counted left to right, each search starting just after the
   --  previous match -- Ada.Strings.Unbounded.Count. Raises
   --  Ada.Strings.Pattern_Error if Pattern is empty (Null_Rope or
   --  ""), even when Source is also empty, as GNAT's Count does. Time
   --  as for Index, plus O(depth) per occurrence found.

   function Count (Source : Rope; Set : Ada.Strings.Maps.Character_Set) return Natural;
   --  The number of characters of Source that are in Set --
   --  Ada.Strings.Unbounded.Count's Character_Set overload. Linear in
   --  Length (Source).

   function Contains (Source, Pattern : Rope) return Boolean;
   function Contains (Source, Pattern : Rope; From : Positive) return Boolean;
   function Contains (Source : Rope; Pattern : Character) return Boolean;
   function Contains (Source : Rope; Pattern : Character; From : Positive) return Boolean;
   function Contains (Source : Rope; Pattern : String) return Boolean;
   function Contains (Source : Rope; Pattern : String; From : Positive) return Boolean;
   --  Whether Pattern occurs anywhere in Source (or at/after From, for
   --  the From overloads) -- a thin wrapper over Index (...) /= 0,
   --  always Going => Forward (there is no Going parameter here:
   --  "contains" is an existence question, not a search direction, and
   --  Rope.Mod's own Contains -- the Character/From overload's direct
   --  model -- has no Going option either). Genuinely a thin wrapper:
   --  the Rope and String overloads inherit Index's own
   --  Ada.Strings.Pattern_Error on an empty Pattern (Null_Rope or "")
   --  rather than softening it to some other answer.

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

   procedure Split (Source : Rope; Separator : Rope; Process : not null access function (Piece : Rope) return Boolean);
   procedure Split (Source : Rope; Separator : String; Process : not null access function (Piece : Rope) return Boolean);
   procedure Split (Source : Rope; Separator : Character; Process : not null access function (Piece : Rope) return Boolean);
   procedure Split
     (Source : Rope; Separator : Ada.Strings.Maps.Character_Set; Process : not null access function (Piece : Rope) return Boolean);
   --  As the Split functions above, but calling Process on each piece
   --  left to right instead of collecting them into a Rope_Array --
   --  Rope.Mod's own Visitor-based Split, dropped from the earlier
   --  Splitting phase in favor of only the array form, restored here
   --  now that there is a real motivating use (see PLAN.md's "Deferred
   --  / stretch" section): unlike the array form above, this never
   --  materializes more than one piece at a time and never makes the
   --  array form's separate counting pass, so it stays cheap even for
   --  a huge Source where most pieces are never needed. Stops early --
   --  without visiting any further pieces -- the first time Process
   --  returns False; returns normally once every piece has been
   --  visited (whether or not the last call to Process returned True,
   --  same as Rope.Mod's own Split: there is nothing left to stop
   --  early from at that point).

   type Cursor is private;

   function First (Source : Rope) return Cursor;
   function Next (Source : Rope; Position : Cursor) return Cursor;
   function Has_Element (Source : Rope; Position : Cursor) return Boolean;
   function Element (Source : Rope; Position : Cursor) return Character;
   --  Cursor-based traversal, giving "for Ch of Some_Rope loop ...
   --  end loop;" via the Iterable aspect on Rope's own declaration
   --  above -- Rope.Mod's
   --  heap-allocated Iterator object and its Get/Incr/Decr/Goto/Move/
   --  Peek/Source methods, replaced with the functional shape the
   --  Iterable aspect requires: Next returns a new Cursor rather than
   --  mutating one in place, and every operation takes Source
   --  explicitly, so a Cursor never needs to carry its own reference
   --  back to the rope or keep anything alive by itself -- it is only
   --  ever valid for use with the Rope it came from, same as any
   --  Ada.Containers Cursor. Rope.Mod's arbitrary-position Peek/Goto/
   --  Move/Decr/Source have no counterpart here; this is forward-only
   --  traversal, the Iterable aspect's whole scope.
   --
   --  First and Next each locate and cache the leaf covering the
   --  Cursor's position (Rope.Mod's Iterator.Locate) as part of
   --  producing their result, so Element/Has_Element are O(1) reads of
   --  an already-valid cache; Next itself is O(1) when the new
   --  position is still within the same leaf as the old one, and only
   --  pays Locate's O(log n) descent from the root on a leaf crossing
   --  -- the same amortized behavior Rope.Mod's Iterator has, just
   --  produced functionally instead of by mutating a heap object in
   --  place.

   Whitespace : constant Ada.Strings.Maps.Character_Set;
   --  Space, tab, line feed, form feed, carriage return -- Rope.Mod's
   --  IsSpace set.

   function Trim
     (Source : Rope; Left : Ada.Strings.Maps.Character_Set := Whitespace; Right : Ada.Strings.Maps.Character_Set := Whitespace)
      return Rope;
   --  Source with leading characters in Left and trailing characters
   --  in Right removed. Matches Ada.Strings.Fixed.Trim's two-
   --  Character_Set overload exactly (not the single-Trim_End-plus-
   --  blanks-only overload -- that one only trims a literal space,
   --  and Rope.Mod's IsSpace covers five characters). Rope.Mod's
   --  TrimLeft/TrimRight/Trim collapse into this one function, the
   --  same way Index collapsed Find/RFind/IndexChar/RIndexChar: a
   --  caller who wants only-left or only-right trimming passes
   --  Ada.Strings.Maps.Null_Set for the side they don't want touched,
   --  same as any Ada.Strings.Fixed client would.

   function Map (Source : Rope; Convert : not null access function (Ch : Character) return Character) return Rope;
   function Map_Indexed
     (Source : Rope; Convert : not null access function (Index : Positive; Ch : Character) return Character) return Rope;
   --  Source with Convert applied to every character, in increasing
   --  index order; Null_Rope if Source is Null_Rope. The result has
   --  the same tree shape as Source (same internal Depth, no
   --  rebalancing needed) -- Rope.Mod's Map/Mapi, Map_Indexed renamed
   --  from Mapi for clarity and taking a 1-based Positive index
   --  (matching this package's indexing convention) instead of
   --  Mapi's 0-based LONGINT.

   function To_Upper (Source : Rope) return Rope;
   function To_Lower (Source : Rope) return Rope;
   --  Source with every ASCII letter (respectively) uppercased or
   --  lowercased; other characters, including accented letters, are
   --  left unchanged -- implemented as Map using
   --  Ada.Characters.Handling.To_Upper/To_Lower (Character) as the
   --  conversion function, reusing Ada.Characters.Handling's own
   --  names and behavior instead of Rope.Mod's hand-rolled
   --  UppercaseAscii/LowercaseAscii (UpperChar/LowerChar's own A..Z/
   --  a..z range checks).

   function Capitalize (Source : Rope) return Rope;
   function Uncapitalize (Source : Rope) return Rope;
   --  Source with its first character (ASCII only) uppercased,
   --  respectively lowercased; the rest of Source is unchanged.
   --  Null_Rope if Source is Null_Rope. Rope.Mod's
   --  CapitalizeAscii/UncapitalizeAscii, renamed to drop the
   --  redundant "Ascii" suffix -- same reasoning as To_Upper/To_Lower
   --  above: there is no non-ASCII variant here to disambiguate from.
   --  No Ada.Strings precedent to match the name against (neither
   --  Ada.Strings.Fixed nor Ada.Characters.Handling has a
   --  "capitalize" operation).

   function Escape (Source : Rope) return Rope;
   --  Source with backslash, double quote, line feed, tab and carriage
   --  return replaced by their two-character backslash escapes, and
   --  any other non-printable character (Character'Pos < 32 or >= 127)
   --  replaced by a backslash followed by its three-digit decimal code
   --  -- Rope.Mod's Escaped, renamed (and renamed Escape in Rope.Mod
   --  too, at Phase 14; see PLAN.md): Ada string *literals* have no
   --  backslash-escape syntax at all (quote-doubling is the only
   --  escape Ada source has), so this is purely a debug/display
   --  convenience, not anything resembling Ada literal syntax.
   --  "Escape" reads as a verb, matching Trim/Capitalize's own naming,
   --  without "Escaped"'s passive-participle ambiguity or a
   --  "To_..._String"-shaped name implying a String result -- this
   --  still returns a Rope, printed like any other (rope_tool uses
   --  Ropes.Text_IO.Put_Line, RopeTool.Mod uses Rope.Write).

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

   --  Position, plus a cache of the leaf node covering it and that
   --  leaf's own 1-based starting index within the whole rope (Leaf =
   --  null and Leaf_Start = 1 together mean "not located" -- true for
   --  a Cursor produced by First/Next only when Pos is already past
   --  the rope's end, i.e. whenever Has_Element would be False).
   --  Deliberately NOT tagged, NOT Controlled -- see this file's
   --  header comment on Cursor, and AGENTS.md/PLAN.md's RM 3.9.3(10)
   --  note on why Cursor must stay untagged alongside a tagged Rope.
   --  Holds a borrowed Node_Access, not an owned one: safe only
   --  because every Cursor-consuming operation also takes Source
   --  explicitly, so the rope value the caller is iterating keeps the
   --  underlying nodes alive for as long as the Cursor is actually
   --  used, the same lifetime assumption any Ada.Containers Cursor
   --  makes about its own container.
   type Cursor is record
      Pos        : Positive    := 1;
      Leaf       : Node_Access := null;
      Leaf_Start : Positive    := 1;
   end record;

   Whitespace : constant Ada.Strings.Maps.Character_Set :=
     Ada.Strings.Maps.To_Set
       (' ' & Ada.Characters.Latin_1.HT & Ada.Characters.Latin_1.LF & Ada.Characters.Latin_1.FF & Ada.Characters.Latin_1.CR);

end Ropes;
