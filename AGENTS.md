# AGENTS.md

`Ropes` is an Ada port of Boehm/Atkinson/Plass ropes. This file holds
working notes for an agent in this repo: what exists, how to build and
test it, and the rules this project has learned. **`PLAN.md` is the
design doc and the history.** It has the design rationale, the
operation-by-operation mapping from `Rope.Mod` to Ada, and one entry
per phase (Phases 1–26) with the full account behind each rule below.

## Status

Every planned phase is done. Several phases (9, 10, 12, 14 and 26)
changed only the sibling Oberon repo, `~/Repos/Oberon/oberon-tools`,
feeding this repo's additions back into `Rope.Mod`.

- `src/ropes.ads`/`.adb` is the library. It has
  reference-counted, balanced ropes and most of `Ada.Strings.Unbounded`'s
  surface as functions: `Slice`, `Insert`, `Delete`, `Overwrite`,
  `Replace_Slice`/`Replace_Element`, `Index`, `Count`, `Contains`,
  `Find_Token`, `Trim`, `Translate`, `"*"`, the comparisons, `Hash`
  and the case-insensitive functions. It also has `Split`, `Map`,
  `Escape`, `Cursor`/`Iterable` and `Process_Chunks`. `ropes.ads` is
  the reference for the current surface.
- `src/ropes-text_io` provides `Put`/`Put_Line`/`Get_Line`, and
  `src/ropes-stream_io` provides whole-file, byte-for-byte
  `Read`/`Write`.
- `src/ropes-test_support` is a test-only child package that exposes
  `Depth`.
- `test/test_*.adb` are in-process checks; `examples/rope_tool` is a
  CLI demo with black-box fixtures in `examples/tests/`. `make test`
  runs both and prints the total. All pass, including under valgrind.

## Build / test

```sh
make test                  # build everything, run test/ and examples/tests/, print the total
make build | build-test | build-examples | clean
cd test && ./test_<name>   # one test program
cd examples && ./tests/run-tests.sh   # the rope_tool fixtures alone
```

- **A new `test/test_*.adb` needs two more edits**: add it to
  `test/test.gpr`'s `for Main use`, and add its binary to `.gitignore`.
- **Run valgrind on anything touching `Adjust`/`Finalize`/node
  freeing.** A refcount bug can pass every check while it touches
  freed memory.
  `valgrind --leak-check=full --show-leak-kinds=definite,indirect --error-exitcode=99 ./test_<name>`
- **Format with `gnatpp -M132`.** There is no formatter config file.
  `gnatpp` can't format an iterated component association
  (`[for Ch in Character => ...]`): it fails with "null template:
  IteratedAssoc" and leaves the whole file unformatted, so write a
  loop instead (Phase 25).
- `rope_tool.gpr` has a bare `with "arg_parser.gpr";`, resolved
  through `GPR_PROJECT_PATH`, not through a path into
  `~/Repos/Ada/arg_parser`. `lines -` needs `arg_parser` `264a098` or
  later, because older versions drop a bare `-`.
- `ropes.gpr` keeps `-gnata`, so a violated `Pre =>` raises a clean
  `Assertion_Error`.

## Source material

- **The direct model, to read first**:
  `~/Repos/Oberon/oberon-tools/Rope.Mod`, plus its `RopeTest.Mod`
  checks, its `RopeTool.Mod` CLI and its `tests/rope-*.test`
  fixtures. `Ropes` exports the same functionality in Ada idioms. It
  is not a transliteration: check `PLAN.md`'s mapping before assuming
  a name or signature carries over, since most don't.
- The paper is at `~/Reference/Computer/Libraries/Ropes/rope-paper.pdf`.
  It has 16 pages, so read it with `pages`.
- cord is at `/usr/local/sw/src/lang/C/bdwgc/cord/`. `cordbscs.c` is
  the core; the API is in `include/gc/cord.h` and `cord_pos.h`.
  `cordxtra.c`/`cordprnt.c` (lazy, file-backed, printf) are out of
  scope.
- **When porting a test, translate the scenario, not the assertion.**
  `Ropes` raises `Index_Error` where `Rope.Mod` clamps, indexes from
  1, and takes `Slice (Low, High)` where `Rope.Mod` takes
  `(start, len)`. Porting in the other direction, to `Rope.Mod`
  (Phases 9, 12 and 26), translates into that module's clamp-or-HALT
  conventions. The `voc` pitfalls behind those ports are in their
  `PLAN.md` entries: `Out` never flushes at exit, `Out.String` stops
  at 0X, and assigning a `LeafWalk` shares its stack, so use
  `CopyWalk`.

## Conventions

- **`Rope` is deliberately untagged**: a private record wrapping one
  `Controlled` component for the refcount. A tagged `Rope` and
  `Cursor` in one package would hit RM 3.9.3(10), as `alibfyaml`'s
  `Node`/`Owner_Liveness` did. **`Cursor` stays untagged too.** Work
  out the 3.9.3(10) consequences before making either type tagged.
- **The acyclic invariant is load-bearing.** Nodes are built
  bottom-up and never mutated: there are no parent or back pointers,
  and no mutable field that could point at a later node. That is what
  lets plain reference counting reclaim everything.
- **Indexing is 1-based**; the paper and `Rope.Mod` are 0-based. Every
  ported index expression needs a deliberate off-by-one check.
- **Reuse `Ada.Strings` vocabulary.** That means
  `Index_Error`/`Length_Error`, `Unbounded`'s names and shapes,
  `Going => Forward | Backward`, `Character_Set`/`Character_Mapping`,
  and `"*"` in place of `Rope.Mod`'s `Make`/`Repeat`. **Check for an
  operator match, not just a function name**: `"*"` was found only
  at Phase 7.
- **`Ropes` follows the RM. GNAT's `Ada.Strings` is the test oracle
  only where the two agree** (Phase 20). Where they differ (the `From`
  overloads of `Index`/`Index_Non_Blank`, and `Unbounded.Find_Token`),
  tests wrap the oracle (`RM (Source, From, Fixed_Result)`). Before
  citing GNAT's behavior, read both the spec's contracts and its
  `Assertion_Policy`: `a-strunb.ads` states the RM's rules as
  preconditions and then sets `Pre => Ignore` (Phase 19).
- **Mappings apply to `Source` only, never to `Pattern`** (RM
  A.4.2(54)). Every `Character_Mapping_Function` parameter is
  `not null`, and a function for one must be library-level (Phases
  22 and 25).
- **`Hash` equals `Ada.Strings.Hash (To_String (K))` under GNAT
  only**, because it computes GNAT's sdbm recurrence and the RM leaves
  the value implementation-defined. `Hash` and the case-insensitive
  functions are in `Ropes`, not in child units as in the RM, because
  they walk leaves through `ropes.adb` internals (Phase 24).
- **`Count` is hidden by `Ada.Text_IO.Count`** when both are
  use-visible (RM 8.4(11)). Write `Ropes.Count`, or don't `use
  Ada.Text_IO` (Phase 17).
- **Don't add an operation that walks the rope with `Fetch` or
  `Element` per character.** Walk leaves with `Leaf_Walk`, as
  `Compare`, `Index`, `Count`, `Split` and `Hash` do. In Ada, copying
  a walk (`V_Walk : Leaf_Walk := W`) is a real copy, which is how a
  match crossing leaves is checked without losing the scan's place
  (Phases 11, 18 and 21).
- **`Iterable` must be a `with` aspect on `type Rope is private`.** A
  later `for Rope use Iterable` is rejected (Phase 5).
- **`Process_Chunks`'s `Hold : constant Rope := Source` is
  load-bearing.** `Rope` is by-reference, so a `Process` that assigns
  to `Source`'s variable would otherwise free the tree mid-walk (Phase
  11).
- **Large output goes through `Ropes.Text_IO`, never `Put_Line
  (To_String (R))`**, which overflows the stack on large ropes. Byte
  I/O uses `Ropes.Stream_IO`, because `Text_IO` can't round-trip
  bytes (Phases 11 and 13).
- **`Ropes.Test_Support` is where test-only access goes.** Add to it
  rather than growing the public API for a test.

## Testing lessons

- **Prove each test can fail.** Plant the bug it targets, one bug at a
  time, and watch it fail (Phases 18 and 25). A trap or crash counts
  as caught, so look at the exit status, not only at `FAIL`/`not ok`
  lines (Phase 26). The mutation has to make a difference: a mapping
  test missed a bug that also mapped `Pattern` until it used a mapping
  that changes the pattern's own characters (Phase 25).
- **A guard can be untested while every test passes.** Remove it once
  and see that a test notices. The separator-ends-the-rope case of
  `Split` was the gap found this way (Phases 20 and 21).
- **To test that a pin or guard matters, delete the declaration**;
  merely not reading through it keeps it working. **Build the expected
  value separately**, because a copy of the rope under test keeps the
  tree alive and hides the bug (Phase 11, `test_text_io`'s `Clobber`).
- **Test "is it linear" on many small leaves, not only on one long
  rope.** An `O(leaves × depth)` walk looks fine on the second (Phase
  11).
- **Test multi-leaf ropes.** Leaves of 16 characters or fewer merge,
  so tests build from 9- or 17-character chunks and check every
  difference position across leaf boundaries.
- **Test index arithmetic on a caller's `String` ending at
  `Positive'Last`**, not only one with `'First /= 1`
  (Phase 16 caught an overflow this way).
- **A constant `null` actual for a `not null` formal draws a
  compile-time warning.** Tests that pass one on purpose use
  `pragma Warnings (Off, ...)`.
- **Generate fixtures from Python argument lists, never with shell
  `eval`**, which collapses spaces inside quoted arguments (Phase
  19). When splicing Ada text through Python, quote with `'''`, since
  Ada's `""` breaks `"""`.

## Keeping docs honest

- **Fix a misleading comment when you spot it**, even in a file the
  current phase doesn't otherwise touch (Phase 10).
- **Check a design doc's "what got built" against the code and `git
  log -S`** (Phase 21 found a `Split_Generic` in `PLAN.md` that never
  existed).
- **When a scope list groups items, check each item against the
  source** before ruling the whole group out (Phase 13:
  `CORD_from_file_eager` is not file-backed).
- **An explicit user decision overrides "match `Rope.Mod`'s scope."**
  Do what was asked, and record why the old reasoning no longer
  applies. Don't record it as though that reasoning had been wrong
  (Phase 8 onward).

## `rope_tool`

`examples/rope_tool` ports all of `RopeTool.Mod` and demonstrates the
rest of `Ropes`. `./rope_tool -h` lists the commands, and
`tests/rope-help.test` records the list.

- **Every phase asks "does `rope_tool` demonstrate this addition?"**
  This is separate from "does `RopeTool.Mod` have a command to port?"
  (Phase 5 first shipped with no demo). Add the command in the same
  phase as the operation, never as a stub ahead of it.
- An operation that takes a function (`Map`, the function forms of
  `Translate`) has no command, because a function can't be given on
  the command line. An optional trailing argument becomes two commands
  (`index`/`rindex`), because `Arg_Parser` has fixed arity.
- To add a command: declare its handler and add its entry to the
  command table in `examples/src/rope_tool_args.ads`, then write the
  handler in `rope_tool_args.adb`. Add fixtures in
  `examples/tests/` covering both results and errors, then regenerate
  `rope-help.test` and `rope-unknown-command.test` from real runs,
  since both embed the usage text. Fixture lines are `program`, `arg`,
  `status` and `output`, plus an optional `input FILE` for standard
  input.
