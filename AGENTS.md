# AGENTS.md

`Ropes` is an Ada port of Boehm/Atkinson/Plass ropes (see `PLAN.md`'s
"Sources being ported"). This file is operational notes for an agent
working in this repo, not a design doc — see `PLAN.md` for the full
design rationale, the API-by-API mapping from the Oberon-2 model to
Ada idioms, open questions, and the phased implementation plan.

## Status

**All phases done** (see `PLAN.md`'s phased plan, Phases 1-22, Phases
7-8, 11 and 13 stretch phases and Phases 9-10, 12 and 14 not really
`Ada`-side changes — see below): `Rope`/`Node`/`Rope_Ref` skeleton, refcounting,
`Null_Rope`, `Length`, `Is_Empty`, `"&"` (short-leaf merge plus
depth-triggered auto-rebalance — `Balance`/`Balance_Insert`/
`Balance_Walk`/`Concat_Forest`, the Fibonacci-forest algorithm), plus
`"&"`'s `Character`/`String` overloads, `From_String`/`From_Character`/
`To_String`, `From_Unbounded_String`/`To_Unbounded_String`, `Element`,
`Slice`, `Copy_Slice` (Phase 15, `Rope.Mod`'s `Blit`), `Insert`,
(Phase 16: `String` overloads of `Index`/`Contains`/`Insert`/`Overwrite` and of
all five comparison operators, both operand orders; Phase 17:
`Replace_Slice`, `Index` with a `Character_Set`, and `Count`; Phase 19:
`Index_Non_Blank` and `Find_Token`; Phase 22: `Translate` with a
`Character_Mapping` or a `Character_Mapping_Function`),
`Delete`, `Overwrite`/`Head`/`Tail`, the five
comparison operators (`"="`/`"<"`/`"<="`/`">"`/`">="`), `Index`
(`Rope`/`Character` patterns, each with a no-`From` and a
`From`-bounded overload, both directions), `Contains` (a thin wrapper
over `Index (...) /= 0`, same 4 overloads), `Split` (`Rope`/`String`/
`Character`/`Character_Set` separators — array-returning, plus a
Process-callback form restoring `Rope.Mod`'s own dropped `Visitor`
`Split`), `Cursor` + the `Iterable` aspect (`for Ch of Some_Rope
loop`), `Trim` (`Ada.Strings.Maps.Character_Set`-based, collapsing
`Rope.Mod`'s separate `TrimLeft`/`TrimRight`/`Trim`), `Map`/
`Map_Indexed`, `To_Upper`/`To_Lower`/`Capitalize`/`Uncapitalize`, `"*"`
(`Natural, Character`/`Rope`, collapsing `Rope.Mod`'s `Make`/`Repeat`
into `Ada.Strings.Fixed`'s own `"*"` vocabulary — see the "`"*"` is a
real find" note below), `Escape`, and (Phase 11) `Process_Chunks` plus
the `Ropes.Text_IO` child package (`Put`/`Put_Line`/`Get_Line`).
`src/ropes.ads`/`.adb`, `src/ropes-text_io.ads`/`.adb` and (Phase 13)
`src/ropes-stream_io.ads`/`.adb` (whole-file `Read`/`Write`/
`Read_File`/`Write_File`, byte for byte) exist and build; `test/test_construction.adb` (19), `test_balance.adb` (5),
`test_slice.adb` (8), `test_insert.adb` (8), `test_delete.adb` (9),
`test_compare.adb` (19), `test_index.adb` (27), `test_split.adb` (17),
`test_iterator.adb` (12), `test_map.adb` (4), `test_case.adb` (8),
`test_trim.adb` (7), `test_concat_overloads.adb` (12),
`test_unbounded.adb` (4), `test_repeat.adb` (8), `test_escape.adb`
(5), `test_overwrite.adb` (6), `test_head_tail.adb` (10),
`test_contains.adb` (9), `test_split_visitor.adb` (16), and
`test_text_io.adb` (17), `test_stream_io.adb` (11), `test_copy_slice.adb` (11), `test_string_overloads.adb` (25), `test_replace_slice.adb` (10),
`test_index_set.adb` (10), `test_count.adb` (10), `test_search_walk.adb` (31), `test_find_token.adb` (14), `test_translate.adb` (12) — 364 checks total — all pass clean, including under valgrind. Plus a
black-box `rope_tool` test suite, `examples/tests/` (`run-tests.sh` +
69 `.test` fixtures, mostly ported from
`~/Repos/Oberon/oberon-tools/tests/rope-*.test`) — `69 ok, 0 failed`.
`Balance`/`Max_Depth`/`Min_Length` are internal to `ropes.adb`, not
public — `src/ropes-test_support.ads`/`.adb` is a small test-only
child package (`function Depth`) so tests can confirm depth stays
bounded without adding `Depth` to the real public API.

**Phase 8 deliberately expands past `Rope.Mod`'s own scope, at
explicit user direction** — every earlier phase, including Phase 7's
"stretch" work, stayed within "port what `Rope.Mod` has," and Phase 7
itself reviewed `Overwrite`/`Head`/`Tail` and left them out for exactly
that reason (see `PLAN.md`'s Phase 7 entry). That reasoning was sound
and still is — there was and is no `Rope.Mod` counterpart to point to.
The user asked for these anyway, plus `Contains` and a lazy/callback
`Split`, plus the black-box `rope_tool` test suite that had been
flagged as "not committed to for any specific phase yet." **A
deliberate scope decision from the user overrides this file's own
"match `Rope.Mod`'s scope" instinct — it doesn't retroactively make
the earlier scope call wrong.** If a future request asks for something
this file's own conventions would otherwise rule out, treat it the
same way: do it, and record *why* the ruling-out reasoning no longer
applies (here: explicit override), not as if the reasoning was flawed
all along.

**Phase 9 fed Phase 8's additions back into `Rope.Mod` itself, not
into this repo.** At explicit user request, `Overwrite`, `Head`/`Tail`,
and a pattern-based `Contains` (`ContainsPattern`, named separately
since Oberon-2 has no overloading to pair it with the existing
char-based `Contains`) were ported back into
`~/Repos/Oberon/oberon-tools/Rope.Mod` — translated into that module's
own clamp-not-trap conventions, not copied verbatim from `Ropes`'s
`Ada.Strings`-flavored exception behavior, the same "translate the
scenario, not the assertion" discipline this repo's own `AGENTS.md`
and `PLAN.md` state for the Oberon→Ada direction, just run in reverse.
`RopeTest.Mod` grew from 134 to 164 checks; `RopeTool.Mod` gained
`overwrite`/`head`/`tail`/`containspattern`; `tests/rope-selftest.test`,
`rope-help.test`, and `rope-unknown-command.test` were regenerated
from real runs rather than hand-edited, since each embeds the full
check list or usage text verbatim. `oberon-tools`'s own test suite:
`296 ok, 0 failed`; committed there as `512963b`. **Nothing in this
repo changed as a result** — no `src/`/`test/`/`examples/` file is
part of Phase 9 — so if a future session goes looking for what Phase 9
"added" here, the answer is nothing; the change lives entirely in the
sibling `oberon-tools` checkout. The operator overloads and
`From_Unbounded_String`/`To_Unbounded_String` did **not** make the
trip back (no Oberon-2 counterpart to either), nor did the
Process-callback `Split` (it was already restoring `Rope.Mod`'s own
pre-existing `Split` visitor, so there was nothing new to send back).

**Phase 10 caught a misleading comment, and a real test gap it led
to.** `examples/src/rope_tool_args.adb`'s `chars` comment said `chars`
was "the one rope_tool command with no RopeTool.Mod counterpart (it
has no iterator-related subcommand at all)" — true of `RopeTool.Mod`
specifically, but easily misread as "`Rope.Mod` has nothing
iterator-related", which is false: `Rope.Mod` has *two*
character-level iteration APIs (`Iterate`, a push-based `Visitor`
callback with early-stop support, and the `Iterator` type, a stateful
`Get`/`Incr`/`Decr`/`Goto`/`Move`/`Peek`/`Source` cursor) — both there
all along. `RopeTool.Mod` just never had a subcommand demonstrating
either. Fixed the comment, and — at explicit user request — added
`iterate`/`iterator` subcommands to `RopeTool.Mod` (each printing a
rope's characters one per line, matching `chars`'s own output, as two
*separate* commands for `Rope.Mod`'s two separate iteration APIs, not
one standing in for both). Investigating this surfaced a real,
previously-unnoticed gap: `Rope.Iterate` had zero test coverage in
`RopeTest.Mod` (only the `Iterator` type was checked) — closed with a
new `CheckIterate`, 164 → 167 checks. All in `oberon-tools` (commit
`6676de6`); the only change in this repo is the comment fix itself —
see `PLAN.md`'s Phase 10 entry for the full account. **A misleading
comment is worth fixing the moment it's spotted, even in a file this
project doesn't otherwise touch for a phase** — catching "technically
true, easily misread" wording is exactly the kind of review this
project's own discipline (verify against the real source, don't
assume) should also apply to its own prose, not just to `Ropes`'s Ada
code.

**Phase 11 added output/input that never flattens a rope** — another
scope expansion at explicit user request, like Phase 8 (`Rope.Mod`
has no output operations at all, only `ToString`/`Blit`). The
motivation is a real failure, not just convenience: `To_String`
builds its result as a stack-allocated `String (1 .. Length)` and
copies it again to return it, so printing a large rope via `Put_Line
(To_String (R))` raises `STORAGE_ERROR` — confirmed, not assumed:
`rope_tool make 20000000 x` crashed that way before this phase and
prints all 20,000,001 bytes after it. `Process_Chunks` (in `Ropes`)
is the general primitive — one callback per leaf, shaped like
`Ada.Containers`' `Iterate`/`Query_Element` — and `Ropes.Text_IO` is
built on it, mirroring `Ada.Text_IO.Unbounded_IO`'s
`Put`/`Put_Line`/`Get_Line` exactly (the child-package name is GNAT's
own `Ada.Strings.Unbounded.Text_IO` precedent). A child package, not
`with Ada.Text_IO` in `Ropes`'s own body, so programs that never do
rope I/O don't depend on it through `Ropes`. `rope_tool` now prints
every rope result with `Ropes.Text_IO.Put_Line` instead of `Put_Line
(To_String (...))`.

**`Process_Chunks` holds its own reference to `Source` for the whole
walk (`Hold : constant Rope := Source`), and that is load-bearing**:
`Rope` has a controlled part, so it is a by-reference type (RM 6.2),
and a `Process` that assigns to the very variable passed as `Source`
would otherwise free the tree mid-walk — confirmed under valgrind
(`Invalid read`s) with the pin removed. Two traps hit while
confirming it, worth knowing for any future "does this guard matter"
experiment: (1) merely no longer *reading through* `Hold` doesn't
unpin anything — the declaration alone keeps the reference, so the
experiment has to delete the declaration; (2) a test whose expected
value is a *copy* of the rope being clobbered (`Expected := R`) keeps
the tree alive itself and can never catch the bug — build the
expected value separately. `test_text_io.adb`'s `Clobber` check does
both correctly, and fails under valgrind if the pin is removed.

**Phase 11 also made `Compare` linear** (so `"="`/`"<"`/... are):
it used to `Fetch` every character from the root, O(n log n) — ~7 s
to compare two 20-million-character ropes, found while writing
`test_text_io.adb`. It now walks both ropes' leaves in step with an
explicit-stack pre-order walk (`Leaf_Walk`/`Next_Leaf` in
`ropes.adb`, stack bounded by the root's own `Depth + 1`), comparing a
run at a time as `String` slices, and returns 0 at once for two ropes
sharing a root. The first version re-descended from the root with
`Locate_Leaf` at each leaf crossing — linear in characters but still
`O(leaves × depth)`, and `"*"`'s ropes have 10–20-character leaves, so
it only got 7 s down to ~1.5 s; the stack walk got it to ~0.1 s. **"Is
it linear" needs checking against a rope with many small leaves, not
just a long one.** `test_compare.adb` gained checks that the old
suite (all one-leaf ropes) could never have caught a run-logic bug
with: every one-character difference position and every prefix length
across two different leaf chunkings, checked against `String`
comparison as an oracle.

`examples/tests/run-tests.sh` gained an `input FILE` fixture line
(standard input for the program, default `/dev/null`) for `lines -`
— the one change to the harness since it was ported, since the
original then had no way to feed a program input at all (Phase 12 gave
it the same line).

**Phase 12 fed Phase 11 back into `Rope.Mod`, like Phase 9 did for
Phase 8 — nothing under `src/`/`test/`/`examples/` changed for it
except one stale harness comment.** At explicit user request,
`~/Repos/Oberon/oberon-tools` (commit `eb449c2`) gained `IterateChunks`
(`Process_Chunks`, as a Boolean-returning `ChunkVisitor` to match
`Rope.Mod`'s own `Visitor`/`Visitor2` early-stop convention),
`Write`/`WriteRider` and `ReadLine`/`ReadLineRider` (`Ropes.Text_IO`,
translated: `Files.Rider`-based rather than `Files.File`-based, since
the Rider is what carries the position in Oberon's `Files` — a
`File` variant would have had to invent a position policy — and
Boolean-returning reads, since Oberon has no exceptions to raise at
end of input), and the linear `Compare`. Two voc facts shaped it,
both confirmed by experiment rather than assumed: **voc's `Out` never
flushes at program exit** (anything after the last line feed is
silently lost, so `Write` ends with `Out.Flush`), and **`Out.String`
stops at 0X** (leaves have no terminator and may contain 0X, so
`Write` goes through `Out.Char`, and `WriteRider` through
`Files.WriteBytes`). The backport also found `RopeTool`'s own version
of the bug Phase 11 fixed here: it printed through `ToString` into an
`ArgParser.MaxStringLength` (4095) buffer, silently truncating longer
results — Oberon's fixed buffers cut short where Ada's stack copy
overflowed. `RopeTest.Mod` 167 → 186 checks; `oberon-tools`' suite
`302 ok, 0 failed`. The Oberon `ArgParser` already passed a bare `-`
through, so its `lines -` never needed the `-- -` workaround.

**Phase 13 added whole-file, byte-for-byte I/O in both repos** — at
explicit user request, in `Ropes.Stream_IO` here and `Rope.Mod`'s
`ReadAll`/`ReadFile`/`WriteFile` in `oberon-tools`. **Built on
`Ada.Streams.Stream_IO`, not `Text_IO`, on purpose**: `Text_IO` is
line-oriented and can't round-trip bytes (form feeds are page
terminators; closing an output file with an unfinished last line adds
a terminator), so there is deliberately no `Text_IO.File_Type`
overload even though that was the shape first suggested. It also
turned up a loose grouping in `PLAN.md`'s out-of-scope list:
`CORD_from_file_eager` had been filed under "file-backed ropes", but
it reads the whole file and returns an ordinary cord (checked in
cord's own `cordxtra.c`, not assumed) — that is what Phase 13 adds;
genuinely file-backed ropes (`CORD_from_file`/`_lazy`) stay out of
scope. **When a scope list groups things, check each member against
the source before treating the whole group as ruled out.**

**Phase 16 added the `String` overloads `Ada.Strings.Unbounded` has
and `Ropes` lacked** — at explicit user request, after asking what
`Ada.Strings.Fixed`/`Unbounded` functionality `Ropes` was missing:
`Index` (`Pattern : String`, with and without `From`), `Insert`/
`Overwrite` (`New_Item : String`), and `"="`/`"<"`/`"<="`/`">"`/`">="`
for `(Rope, String)` and `(String, Rope)`. `Index`/`Insert`/`Overwrite`
just wrap `From_String` (like `Split`'s `String` overload already
did); the comparisons have their own `Compare (Node_Access, String)`,
walking only the rope's leaves, so the String is never copied. Its
check against a `String` ending at `Positive'Last` caught a real
overflow in the first version (`Right'First + Offset + Run - 1`
overflows before the `- 1`) — **index arithmetic on a caller's
`String` needs testing at `Positive'Last`, not only at `'First /= 1`**.
`Contains` got the matching `String` pair (with and without `From`)
as a follow-up request. `rope_tool`'s `insert`/`overwrite`/`cmp` now
pass their argument straight to these overloads (`contains` stays
`Character`-based, matching `RopeTool.Mod`'s own).

**Phase 17 added `Replace_Slice`, `Index` with a `Character_Set`,
and `Count`** — the next three from the same "what's missing from
`Ada.Strings.Fixed`/`Unbounded`" list, at explicit user request. Each
matches `Ada.Strings.Unbounded`'s own signature, and each test uses
`Ada.Strings.Fixed` itself as the oracle across multi-leaf ropes,
exception cases included. Two things worth knowing: (1) **the
`From`-bounded `Index` overloads follow GNAT, not the RM's wording** —
RM A.4.3(56.2/3, 58.5/3) says `Index_Error` whenever `From` is outside
`Source'Range`, but GNAT's `a-strsea.adb` raises only for `Forward`
with `From < 'First` (impossible for a rope) and `Backward` with `From
> 'Last`. `Ropes` already did this for `Rope`/`Character` patterns;
the new `Character_Set` overload does the same, and `ropes.ads` now
says so. (2) **`Count` clashes with `Ada.Text_IO.Count`** — with both
packages use-visible, a bare `Count` is hidden (RM 8.4(11)), as it
would be for `Ada.Strings.Unbounded.Count`; `rope_tool` writes
`Ropes.Count`, and `test_count.adb` doesn't `use Ada.Text_IO`.

**Phase 18 made every `Index` and `Count` walk leaves instead of
calling `Fetch` per character** (25–130× faster on 2-million-character
ropes), on a `Leaf_Walk` that now has a direction and can start
anywhere (`Start_Walk_At`), and documented why the `From` rule follows
GNAT rather than the RM (see `ropes.ads`'s `Index` comment and
PLAN.md's "`From` past the end"). **A walk copied mid-search is how a
pattern match crossing leaves is checked without losing the scan's
place** — `Leaf_Walk` is a plain record, so `V_Walk : Leaf_Walk := W`
is the whole trick. **Proving a search test can fail is part of
writing it**: `test_search_walk.adb` was checked by planting three
bugs, one at a time, and seeing it fail each.

**Phase 22 added `Translate`, both of
`Ada.Strings.Unbounded`'s function forms** — `Character_Mapping` and
`Character_Mapping_Function` — each a wrapper over `Map`. The function
form first shipped as a comment saying "call `Map` itself"; the user
wanted a real overload so calls read in `Ada.Strings`' vocabulary.
**A null `Character_Mapping_Function` raises `Constraint_Error`**
(`Map`'s `Convert` is `not null`): the RM doesn't say, and GNAT's
`Ada.Strings.Fixed.Translate` states `Mapping /= null` only as a
precondition its `Assertion_Policy (Pre => Ignore)` turns off. **A
`Character_Mapping_Function` can't designate a nested function** (its
access type is library-level), so tests use
`Ada.Characters.Handling.To_Upper'Access`. `rope_tool translate S FROM
TO` demonstrates the `Character_Mapping` form; the function form has no
command, like `Map`.

**Phase 21 put the `Character`/`Character_Set` `Split`s on the
leaf-walking `Index`** (they had each kept a per-character `Element`
loop), and found `PLAN.md` describing a `Split_Generic` that never
existed in `src/`. Their new `Find_Next` guards were untested at
first too, like Phase 20's — the separator-ends-the-rope case existed
only for `Rope`/`String` separators. **A design doc's "what actually got built" needs
checking against `git log -S` as much as any comment does.**

**Phase 20 made every `From` overload of `Index` follow the RM**:
`Index_Error` for `From > Length (Source)` in either direction (a
non-empty `Source`), where it had copied GNAT's unchecked `Forward`
behavior (returning 0). **`Ropes` follows the RM; GNAT's `Fixed` is
the test oracle only where the two agree** — where they don't, the
tests wrap it (`RM (Source, From, Fixed_Result)`). PLAN.md's Phase 20
entry has the full RM/GNAT survey: the `From` overloads of `Index`/
`Index_Non_Blank` and GNAT's `Unbounded.Find_Token` are the only
conflicts. **A guard can be untested even when every test passes** —
`Split`'s new one wasn't, until a separator-ends-the-rope case was
added; remove a guard once to see that some test notices.

**Phase 19 added `Index_Non_Blank` and `Find_Token`, and settled the
`From` rule as "do what GNAT's `Ada.Strings.Fixed` does"** (replaced
by the RM at Phase 20) — laxer than the RM for `Index`, exactly the RM
for `Find_Token`. Checking it
found that **GNAT's `a-strunb.ads` states the RM's `From` rule as
preconditions and then ignores them** (`pragma Assertion_Policy (Pre
=> Ignore)`): read a GNAT runtime spec's contracts *and* its
`Assertion_Policy` before citing either as GNAT's behavior. **Don't
generate fixtures through `eval` on an unquoted variable** — it
collapses runs of spaces inside quoted arguments; build argument lists
in Python (or an array) instead.

**Phase 14 made `Rope.Mod`'s `Blit` and `Escaped` linear and renamed
`Escaped` to `Escape`** (`oberon-tools` `a41f0a7`) — the two
per-character-`Fetch` operations Phase 12 had left alone there. Only
`ropes.ads`'s `Escape` comment changed here. See `PLAN.md`'s Phase 14
entry.

**`"*"` is a real find, not in the original design sketch**: `Rope.Mod`'s
`Repeat`/`Make` were originally sketched as functions of those names,
but `Ada.Strings.Fixed` already has `"*" (Natural, Character)`/`"*"
(Natural, String)` operators doing exactly this for `String` —
discovered only at Phase 7 implementation time. Reusing that
vocabulary (`Natural * Rope`, `Natural * Character`) instead of
inventing `Repeat`/`Make` names is the same "Reuse `Ada.Strings`
vocabulary" convention already applied to `Index`/`Trim`/`Slice` in
earlier phases — it just wasn't noticed until later, since `"*"` is a
far less obvious place to look for `Ada.Strings.Fixed` precedent.
**Before assuming a design sketch's names are final, check
`Ada.Strings` for an operator/function match, not just a function
name.**

**`Iterable`'s aspect spelling caught a real gotcha** (see `PLAN.md`'s
"Iteration" section): it must be `with Iterable => (...)` directly on
`type Rope is private`, not a separate `for Rope use Iterable =>
(...)` clause after `First`/`Next`/etc. are declared — GNAT rejects
the latter ("invalid representation clause") since only the
`with`-on-the-declaration form gets the forward-reference allowance
Ada gives this aspect. Confirmed against every real `Iterable` user on
this machine before fixing, not guessed.

**A `rope_tool` subcommand isn't only "wrap the matching `RopeTool.Mod`
command"** — Phase 5 initially shipped with no `rope_tool` addition at
all, reasoning that `RopeTool.Mod` has no iterator subcommand to port.
The user pushed back: `rope_tool` exists to demonstrate `Ropes`'s
surface, and leaving a whole phase's addition (`Cursor`/`Iterable`)
with zero CLI demonstration was a real gap even with no
`RopeTool.Mod` precedent to point to. Fixed by adding `chars` (`for Ch
of S loop`, one character per line) — the first `rope_tool` command
with no `RopeTool.Mod` counterpart at all. **Every future phase should
ask "does `rope_tool` demonstrate this phase's addition?" as its own
question**, separate from "does `RopeTool.Mod` have a command to
port" — the two only coincide when `Ropes` doesn't add capability
`RopeTool.Mod` itself lacked (true for Phases 1–4, not automatically
true going forward).

`examples/rope_tool` (the Ada port of `RopeTool.Mod`, built on
`arg_parser` — see `PLAN.md`'s "Command-line tool (rope_tool)") has
`cat`/`len`/`fetch`/`slice`/`insert`/`delete`/`overwrite`/`head`/`tail`/
`cmp`/`index`/`rindex`/`indexchar`/`rindexchar`/`split`/`chars`/`trim`/
`triml`/`trimr`/`upper`/`lower`/`capitalize`/`uncapitalize`/`repeat`/
`make`/`bigcat`/`contains`/`escaped`/`lines`/`readfile`/`copyslice`/
`replaceslice`/`count`/`countset`/`indexset`/`rindexset`/`nonblank`/
`rnonblank`/`findtoken`/`translate`, matching all of `Ropes`'s API
through Phase 22 (`translate S FROM TO` is Phase 22's, with
`To_Mapping (FROM, TO)` — the `Character_Mapping_Function` form has
no command, like `Map`, since a function can't be given on the
command line, and `upper`/`lower` already show function-based mapping; Phase 19's are `Index_Non_Blank`/`Find_Token` demos, `findtoken`
printing `FIRST LAST`; Phase 17's five are
`Replace_Slice`/`Count`/`Index`-with-a-`Character_Set` demos, each set
given as a string of its members, `indexset`/`rindexset` split by
`Going` like `index`/`rindex`; `copyslice S LOW HIGH T POS` is
Phase 15's `Copy_Slice` demo, printing T after the copy so its
untouched rest shows; `readfile FILE` is Phase 13's
`Ropes.Stream_IO.Read_File` demo, printing the contents `Escape`d so
that every byte shows in a fixture; `lines FILE` is Phase 11's `Ropes.Text_IO.Get_Line`
demo, the one command that reads input — `-` for standard input; this
needs `arg_parser` `264a098` or later, since older `Arg_Parser`s
silently dropped a bare `-`, and `lines` briefly required `-- -` until
that was fixed upstream; `cmp` is built from `"="`/`"<"` in
`rope_tool_args.adb` itself, since `Ropes` has no public `Compare`
function to wrap — see PLAN.md's "Comparison"; `index`/`rindex` and
`indexchar`/`rindexchar` are each one `Ropes.Index` overload called
with a fixed `Going`, split into two commands since `Arg_Parser`'s
fixed-arity model can't make a trailing argument optional; `chars`
demonstrates `Cursor`/`Iterable` via `for Ch of S loop` and has no
`RopeTool.Mod` counterpart at all — see the gotcha note above;
`overwrite`/`head`/`tail` likewise have no `RopeTool.Mod` counterpart
(Phase 8's own scope-expansion, see the Status note above); `triml`/
`trimr` pass `Ada.Strings.Maps.Null_Set` for the untouched side of
`Ropes`'s one `Trim` function, since `Ropes` collapsed `RopeTool.Mod`'s
three separate trim commands; no `map`/`map_indexed` subcommand, since
`Map`'s `Convert` is a function pointer with no CLI-string-argument
shape and `RopeTool.Mod` itself has none either; `bigcat` prints
`Length (N1 * CH1 & N2 * CH2)`, exercising `"*"`'s binary-doubling
sharing and `New_Concat`'s overflow guard the same way `RopeTool.Mod`'s
own `bigcat` does; every rope-valued result is printed via `Ropes.Text_IO.Put_Line`
(Phase 11), never `Put_Line (To_String (...))`, so large results no
longer overflow the stack; `contains` now calls the real `Ropes.Contains`
rather than the inline `Index (...) /= 0` it used when first added at
Phase 7, before `Ropes.Contains` existed; `split`'s `Rope`-separator
case demonstrates the Process-callback `Split` overload, not just the
array-returning one). **This completes `rope_tool`'s port of
`RopeTool.Mod`'s entire command set** — every `RopeTool.Mod` command
now has a `rope_tool` counterpart, plus `chars`/`overwrite`/`head`/
`tail`, which don't go the other way. Add a `rope_tool` subcommand in
the same phase that adds its underlying `Ropes` operation — never a
stub ahead of the operation existing, and don't let `rope_tool` drift
behind `Ropes`'s current surface from one phase to the next; this
includes a phase like 5 that adds no new `RopeTool.Mod`-sourced
command, since the demo angle ("does `rope_tool` show off this phase's
addition") is separate from the porting angle ("does `RopeTool.Mod`
have a matching command") — and, per Phase 8, also separate from "is
this a `Rope.Mod`-scope addition at all."

There is also a black-box `rope_tool` test suite,
`examples/tests/run-tests.sh` + `examples/tests/*.test` (see
`PLAN.md`'s "Testing approach" and "Command-line tool (rope_tool)"
sections) — a direct port of
`~/Repos/Oberon/oberon-tools/tests/run-tests.sh` and its
`tests/rope-*.test` fixtures, run via `cd examples &&
./tests/run-tests.sh`. This exercises `rope_tool` itself as a
subprocess (exit status + combined stdout/stderr), distinct from
`test/test_*`'s in-process `Ropes` library checks above.

## Source material

- The paper: `~/Reference/Computer/Libraries/Ropes/rope-paper.pdf`
  (16 pages; read with the `pages` parameter, it's too large for one
  `Read` call).
- cord (the paper authors' own C implementation):
  `/usr/local/sw/src/lang/C/bdwgc/cord/` — `cordbscs.c` is the core
  (short-leaf merge, `CORD_MAX_DEPTH`, `min_len` table); its public API
  is `/usr/local/sw/src/lang/C/bdwgc/include/gc/cord.h` +
  `cord_pos.h`. `cordxtra.c`/`cordprnt.c` are the lazy/file-backed/
  printf extras that are explicitly **not** in scope here.
- **The direct model — read this first**:
  `~/Repos/Oberon/oberon-tools/Rope.Mod`. It already resolved the
  algorithmic questions (short-leaf merge threshold, Fibonacci-forest
  rebalance) and defines the scope `Ropes` should match. `Ropes`
  should export the same functionality, using Ada idioms in place of
  its Oberon-2 calling conventions, naming, and 0-based indexing — not
  a bigger feature set, and not a transliteration. See `PLAN.md`'s
  per-operation mapping before assuming a `Rope.Mod` function name or
  signature carries over unchanged; most don't.
- `Rope.Mod`'s own test suite: `~/Repos/Oberon/oberon-tools/RopeTest.Mod`
  (internal `ok`/`not ok` check battery) and
  `~/Repos/Oberon/oberon-tools/RopeTool.Mod` (a CLI demo exposing each
  operation as a subcommand — **fully ported** as of Phase 7, as
  `examples/rope_tool`, built on `~/Repos/Ada/arg_parser`; see
  `PLAN.md`'s "Command-line tool (rope_tool)"), plus the black-box fixtures at
  `~/Repos/Oberon/oberon-tools/tests/rope-*.test`. This is where
  `Ropes`'s own test cases come from — see `PLAN.md`'s "Testing
  approach". **Do not copy an expected outcome verbatim** where
  `PLAN.md` changed the behavior (clamping → `Index_Error`, 0-based →
  1-based, `(start, len)` `Substring` → inclusive `Slice (Low, High)`)
  — translate the scenario, not the assertion. This is exactly what
  `examples/tests/*.test` did with these fixtures at Phase 8 — see
  `PLAN.md`'s "Testing approach" section for the real divergences that
  discipline caught.

## Build / test

```sh
gprbuild -P ropes.gpr -p
cd test
gprbuild -P test.gpr -p
./test_<name>          # run individually; see PLAN.md's Testing section
```

`test/test.gpr`'s `for Main use (...)` lists every `test_*.adb` by
name (see `test.gpr` itself for the current list, rather than a
snapshot here that would only go stale again as phases add more files
— it drifted out of date exactly this way once already, listing just
`test_construction.adb`/`test_balance.adb` long after later phases had
added a dozen more) — **adding a new `test_*.adb` requires adding it
there too**, the same easy-to-miss two-edit rule `alibfyaml`'s
`AGENTS.md` documents for its own `test.gpr`.

```sh
cd examples
gprbuild -P rope_tool.gpr -p
./rope_tool <command> arguments...   # e.g. ./rope_tool cat foo bar
```

`rope_tool.gpr` depends on the installed `arg_parser.gpr` via a bare
`with "arg_parser.gpr";` (resolved through `GPR_PROJECT_PATH`, already
set to `/usr/local/sw/versions/ada/share/gpr` — same pattern
`besm2_fmt`/`ova_fmt` use for `arg_parser.gpr`/`libfyaml_ada.gpr`), not
a relative path into `~/Repos/Ada/arg_parser`'s source checkout.

Run anything touching `Adjust`/`Finalize`/node-freeing under valgrind
before considering a change done, not just via the test's own ok/FAIL
output:

```sh
valgrind --leak-check=full --show-leak-kinds=definite,indirect --error-exitcode=99 ./test_<name>
```

Format with `gnatpp -M132` (matches this user's other Ada projects —
e.g. `~/Repos/Ada/ada-experiments`' git log, where `Ropes` lived
before moving to this standalone repo). No formatter config file
exists in this repo; `-M132` is passed on the command line.

## Conventions specific to this codebase

- **`Rope` is deliberately untagged** — a plain private record wrapping
  one `Ada.Finalization.Controlled` component for reference counting,
  not `new Controlled with private`. This sidesteps RM 3.9.3(10) (a
  subprogram can't be a dispatching primitive of two different tagged
  types declared in the same package), which `~/Repos/Ada/alibfyaml`
  hit for real with `Node`/`Owner_Liveness` (see its
  `src/libfyaml-nodes.ads`, the `Owner_Ref` comment) and which `Ropes`
  would hit too the moment the iteration `Cursor` type exists alongside
  a tagged `Rope`. **`Cursor` must stay untagged for the same reason**
  — see `PLAN.md`'s "Iteration" section. If a future change makes
  either type tagged, work out the RM 3.9.3(10) consequences before
  writing it, not after the compiler rejects it.
- **The acyclic invariant is load-bearing.** Every `Node` is built
  strictly bottom-up from already-built children and never mutated
  afterward — no parent/back pointers, ever. This is what makes plain
  (non-cycle-collecting) reference counting exactly reclaim every
  rope's memory. Never add a mutable field to `Node` that could later
  be assigned to point at something built after it.
- **Indexing is 1-based (`Positive`)**, matching
  `Ada.Strings.Unbounded` — both the paper and `Rope.Mod` are 0-based.
  When porting an algorithm or index expression from either source,
  treat it as needing a deliberate off-by-one adjustment, not a
  verbatim copy. This is the easiest place to introduce a bug while
  implementing any phase in `PLAN.md`.
- **Reuse `Ada.Strings` vocabulary instead of inventing parallel
  names/exceptions.** `Ada.Strings.Index_Error`/`Length_Error` instead
  of new exceptions or `Rope.Mod`'s clamp-or-`HALT` mix;
  `Element`/`Slice`/`Insert`/`Delete`/`Length` named and shaped after
  `Ada.Strings.Unbounded`'s own operations (note `Slice` takes
  inclusive `Low`/`High`, not `Rope.Mod`'s `start, len`);
  `Index (..., Going => Forward | Backward)` instead of separate
  `Find`/`RFind` functions; `Ada.Strings.Maps.Character_Set` for
  `Trim`; `Ada.Characters.Handling.To_Upper`/`To_Lower` underlying
  `Map`-based case conversion; `"*" (Natural, Character)`/`(Natural,
  Rope)` instead of `Rope.Mod`'s `Make`/`Repeat` names, matching
  `Ada.Strings.Fixed`'s own `"*" (Natural, Character)`/`"*" (Natural,
  String)` operators exactly (found only at Phase 7 implementation
  time — check `Ada.Strings` for an operator match, not just a
  same-shaped function name, before assuming a sketch's own name is
  final). See `PLAN.md` for the full per-operation mapping before
  adding anything that duplicates existing `Ada.Strings` vocabulary
  under a new name.
- **`with Pre =>` contracts, checked via `-gnata`** (once written) —
  keep `-gnata` in `ropes.gpr`'s `Compiler` switches, same reasoning as
  `alibfyaml`'s `libfyaml_ada.gpr` comment: a precondition violation
  should surface as a clean `Assertion_Error`, not silently fall through.
- **Run anything touching `Adjust`/`Finalize`/node-freeing under
  valgrind**, not just its own test assertions — see `PLAN.md`'s
  Testing section for why (the exact bug class `alibfyaml` documents
  hitting for real: a lifetime/refcount bug that passes its own
  pass/fail logic while quietly touching freed memory).
- **`Ropes.Test_Support`** (`src/ropes-test_support.ads`/`.adb`) is the
  pattern for when a test genuinely needs to see something `Ropes`
  deliberately doesn't expose publicly (currently just `Depth`, for
  Phase 2's balance-stays-bounded check) — a small child package, not
  a change to `Ropes`'s own public API. Add to it, don't grow the real
  API to satisfy a test.
