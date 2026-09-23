# AGENTS.md

`Ropes` is an Ada port of Boehm/Atkinson/Plass ropes (see `PLAN.md`'s
"Sources being ported"). This file is operational notes for an agent
working in this repo, not a design doc — see `PLAN.md` for the full
design rationale, the API-by-API mapping from the Oberon-2 model to
Ada idioms, open questions, and the phased implementation plan.

## Status

**All phases done** (see `PLAN.md`'s phased plan, Phases 1-8, the last
two both stretch phases): `Rope`/`Node`/`Rope_Ref` skeleton, refcounting,
`Null_Rope`, `Length`, `Is_Empty`, `"&"` (short-leaf merge plus
depth-triggered auto-rebalance — `Balance`/`Balance_Insert`/
`Balance_Walk`/`Concat_Forest`, the Fibonacci-forest algorithm), plus
`"&"`'s `Character`/`String` overloads, `From_String`/`From_Character`/
`To_String`, `From_Unbounded_String`/`To_Unbounded_String`, `Element`,
`Slice`, `Insert`, `Delete`, `Overwrite`/`Head`/`Tail`, the five
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
real find" note below), and `Escape`. `src/ropes.ads`/`.adb` exist and
build; `test/test_construction.adb` (19), `test_balance.adb` (5),
`test_slice.adb` (8), `test_insert.adb` (8), `test_delete.adb` (9),
`test_compare.adb` (13), `test_index.adb` (25), `test_split.adb` (15),
`test_iterator.adb` (12), `test_map.adb` (4), `test_case.adb` (8),
`test_trim.adb` (7), `test_concat_overloads.adb` (12),
`test_unbounded.adb` (4), `test_repeat.adb` (8), `test_escape.adb`
(5), `test_overwrite.adb` (6), `test_head_tail.adb` (10),
`test_contains.adb` (9), and `test_split_visitor.adb` (13) — 200
checks total — all pass clean, including under valgrind. Plus a
black-box `rope_tool` test suite, `examples/tests/` (`run-tests.sh` +
38 `.test` fixtures, ported from
`~/Repos/Oberon/oberon-tools/tests/rope-*.test`) — `38 ok, 0 failed`.
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
`make`/`bigcat`/`contains`/`escaped`, matching all of `Ropes`'s API
through Phase 8 (`cmp` is built from `"="`/`"<"` in
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
own `bigcat` does; `contains` now calls the real `Ropes.Contains`
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
  operation as a subcommand — **being ported**, as `examples/
  rope_tool`, built on `~/Repos/Ada/arg_parser`; see `PLAN.md`'s
  "Command-line tool (rope_tool)"), plus the black-box fixtures at
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
see recent commits in this repo's git log). No formatter config file
exists elsewhere in this tree; `-M132` is passed on the command line.

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
