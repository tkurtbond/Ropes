# AGENTS.md

`Ropes` is an Ada port of Boehm/Atkinson/Plass ropes (see `PLAN.md`'s
"Sources being ported"). This file is operational notes for an agent
working in this repo, not a design doc — see `PLAN.md` for the full
design rationale, the API-by-API mapping from the Oberon-2 model to
Ada idioms, open questions, and the phased implementation plan.

## Status

**Phase 1 done** (see `PLAN.md`'s phased plan): `Rope`/`Node`/
`Rope_Ref` skeleton, refcounting, `Null_Rope`, `Length`, `Is_Empty`,
plain `"&"` (short-leaf merge only, no rebalancing), `From_String`/
`To_String`, `Element`. `src/ropes.ads`/`.adb` exist and build;
`test/test_construction.adb` (19 checks) passes clean, including under
valgrind. Work through the remaining phases in order — each gets its
own tests before moving to the next. Don't skip ahead to a later
phase's API surface (e.g. `Index`/`Split`/iteration) before Phase 2's
balancing is in place and tested — everything later depends on
`Cat`/`Balance` actually bounding tree depth.

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
  operation as a subcommand — **not** being ported; `Ropes` is a
  library, no CLI tool is in this plan), plus the black-box fixtures at
  `~/Repos/Oberon/oberon-tools/tests/rope-*.test`. This is where
  `Ropes`'s own test cases come from — see `PLAN.md`'s "Testing
  approach". **Do not copy an expected outcome verbatim** where
  `PLAN.md` changed the behavior (clamping → `Index_Error`, 0-based →
  1-based, `(start, len)` `Substring` → inclusive `Slice (Low, High)`)
  — translate the scenario, not the assertion.

## Build / test

```sh
gprbuild -P ropes.gpr -p
cd test
gprbuild -P test.gpr -p
./test_<name>          # run individually; see PLAN.md's Testing section
```

`test/test.gpr`'s `for Main use (...)` currently lists only
`test_construction.adb` — **adding a new `test_*.adb` requires adding
it there too**, the same easy-to-miss two-edit rule `alibfyaml`'s
`AGENTS.md` documents for its own `test.gpr`.

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
  `Map`-based case conversion. See `PLAN.md` for the full per-operation
  mapping before adding anything that duplicates existing `Ada.Strings`
  vocabulary under a new name.
- **`with Pre =>` contracts, checked via `-gnata`** (once written) —
  keep `-gnata` in `ropes.gpr`'s `Compiler` switches, same reasoning as
  `alibfyaml`'s `libfyaml_ada.gpr` comment: a precondition violation
  should surface as a clean `Assertion_Error`, not silently fall through.
- **Run anything touching `Adjust`/`Finalize`/node-freeing under
  valgrind**, not just its own test assertions — see `PLAN.md`'s
  Testing section for why (the exact bug class `alibfyaml` documents
  hitting for real: a lifetime/refcount bug that passes its own
  pass/fail logic while quietly touching freed memory).
