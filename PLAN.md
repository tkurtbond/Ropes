# Ropes: an Ada port of Boehm/Atkinson/Plass ropes

## Sources being ported

- **The paper**: Boehm, Atkinson, and Plass, "Ropes: an Alternative to
  Strings" (*Software—Practice and Experience* 25(12), 1315–1330,
  1995) — `~/Reference/Computer/Libraries/Ropes/rope-paper.pdf`.
  Defines the tree-of-concatenations representation, the short-leaf
  merge optimization, and the Fibonacci-forest rebalancing algorithm.
- **cord**, the paper authors' own C implementation, shipped with the
  Boehm-Demers-Weiser garbage collector —
  `/usr/local/sw/src/lang/C/bdwgc/cord/` (`cordbscs.c` the core,
  `cordxtra.c` the lazy/function/file-backed extras, `cordprnt.c` a
  printf-style formatter), public API in
  `/usr/local/sw/src/lang/C/bdwgc/include/gc/cord.h` +
  `cord_pos.h`. Confirms the paper's constants concretely
  (`SHORT_LIMIT`, `CORD_MAX_DEPTH`, `min_len`) and shows the fuller
  surface (lazy leaves, substring nodes, file-backed cords,
  `CORD_printf`) that this port deliberately does **not** chase — see
  below.
- **The direct model**: `~/Repos/Oberon/oberon-tools/Rope.Mod`, an
  Oberon-2 port of the same paper with two engineering choices taken
  from cord (short-leaf merge in `Cat`, the Fibonacci-forest rebalance)
  rather than from scratch. This is the actual scope contract for
  `Ropes`: a "core" rope — flat leaves and concatenation nodes only, no
  lazy/function leaves, no substring nodes, no file-backed ropes,
  `Substring` always copies. `Ropes` should export **the same
  functionality** as `Rope.Mod`, using Ada idioms in place of its
  Oberon-2 ones — not a bigger feature set, and not a mechanical
  transliteration of its calling conventions.
- **`Rope.Mod`'s own test suite and demo tool**, in the same directory:
  `RopeTest.Mod` (an internal battery of `Check(cond, name)` assertions,
  printed as `ok - NAME`/`not ok - NAME` plus a summary, `HALT(1)` on
  any failure) and `RopeTool.Mod` (a `arg_parser`-based CLI exposing
  each `Rope` operation as a subcommand, e.g. `ropetool sub S START
  LEN`). `~/Repos/Oberon/oberon-tools/tests/rope-*.test` are black-box
  fixtures run through `RopeTool` by `tests/run-tests.sh` (`program
  RopeTool` / `arg ...` / `status N` / expected `output`), plus
  `rope-selftest.test`, which just runs `RopeTest` itself and checks
  its whole `ok`-line output verbatim. Together these enumerate the
  edge cases every operation needs to handle — empty/`NIL` operands,
  negative/past-the-end positions, the short-leaf-merge and
  absorb-into-concat depth cases, the `LONGINT` overflow guard
  (`rope-bigcat-overflow.test`), etc. — and are the primary source for
  `Ropes`'s own test cases (see "Testing approach" below), **not** a
  case-by-case behavior contract: several of them assert the
  clamp-and-succeed behavior this plan deliberately replaces with
  `Ada.Strings.Index_Error`/`Length_Error` (see below), so the
  *expected outcome* changes even where the *scenario* carries over
  unchanged. **`RopeTool` itself is being ported too**, as `examples/
  rope_tool` — see "Command-line tool (rope_tool)" below.

## Why this is a real port, not a transliteration

Oberon-2 and Ada solve several of the same problems differently enough
that copying `Rope.Mod`'s shape verbatim would produce non-idiomatic
(and in a couple of places actively wrong) Ada. The differences that
actually change the design, not just the syntax:

- **Memory management.** Oberon-2 (voc) and cord (built on the Boehm
  GC) both rely on a tracing collector — a `Concat` node just holds
  `Left`/`Right` pointers and nothing ever frees anything explicitly.
  Ada has no such collector. The alternative to manual `Unchecked_Deallocation`
  bookkeeping (error-prone, and wrong for a value type meant to be
  freely shared/copied) is reference counting via
  `Ada.Finalization.Controlled`. Reference counting only fully
  reclaims memory when the reference graph has no cycles — true here
  because every node is built strictly bottom-up from already-built
  children and is never mutated afterward (see "Rope, Node, and memory
  management" below). This is the same shape `alibfyaml`'s
  `Buffer_Ref`/`Owner_Liveness` already use for a different problem
  (shared buffer lifetime, shared liveness flag) — see
  `~/Repos/Ada/alibfyaml/src/libfyaml-nodes.ads`'s `Owner_Ref` comment,
  reused here directly including the *reason* for wrapping the
  `Controlled` type inside a plain record rather than making `Rope`
  itself `new Controlled with private` (RM 3.9.3(10) — see below).
- **Fail-fast vs. clamp-and-HALT.** `Rope.Mod` mixes two failure
  conventions: `Fetch`/`Blit` `HALT(1)` on an out-of-range index,
  while `Substring`/`Insert`/`Remove` silently clamp. voc's `HALT` is a
  hard process abort with no recovery. Ada's idiom for "index out of
  range" and "operation would produce a too-long result" already
  exists and is exception-based:
  `Ada.Strings.Index_Error`/`Ada.Strings.Length_Error`, exactly what
  `Ada.Strings.Unbounded` itself raises. `Ropes` reuses those two
  exceptions rather than clamping or inventing new ones, so a caller
  already familiar with `Unbounded_String`'s failure modes needs to
  learn nothing new.
- **0-based vs. 1-based indexing.** Both the paper and `Rope.Mod` index
  from 0. Every other Ada string type (`String`, `Ada.Strings.Unbounded`,
  `Ada.Strings.Bounded`) indexes from 1. `Ropes` follows Ada, which
  means every index expression ported from `Rope.Mod` needs a deliberate
  off-by-one adjustment, not a verbatim copy — flagged per-operation
  below.
- **Named comparison/search pairs vs. operator overloading and
  `Ada.Strings.Direction`.** `Compare`/`Equal` become overloaded `"="`,
  `"<"`, etc. `Find`/`RFind` (and `IndexChar`/`RIndexChar`) collapse
  into one `Index` function taking `Ada.Strings.Direction` — the same
  collapse `Ada.Strings.Fixed.Index` already made. `Cat`/`AppendChar`
  become overloaded `"&"`. This is the single biggest idiom shift: Ada
  already has a standard vocabulary for "immutable string type" and
  `Ropes` should read as an extension of it, not a fresh one.
- **Callback types.** Oberon-2 has no way to say "this access value must
  not be `NIL`" — passing a `NIL` `Mapper` into `Map` is a caller bug
  that surfaces as a trap deep inside the traversal. Ada's `not null
  access` constraint catches this at the call boundary. Every
  callback-taking `Ropes` subprogram uses it.
- **Manual iterator object vs. the `Iterable` aspect.** `Rope.Mod`'s
  `Iterator` is a heap-allocated, mutable-state object with `Get`/
  `Incr`/`Decr`/`Goto`/`Move`/`Peek`/`Source` methods — needed in
  Oberon-2 because there's no language-level custom-iteration hook.
  Ada 2012's `Iterable` aspect gives `for Ch of R loop ... end loop;`
  directly, backed by a small value-type `Cursor` (not heap-allocated,
  not mutated in place — `Next` returns a new `Cursor`). See
  "Iteration" below for why `Cursor` must stay untagged.
- **Hand-rolled linked list vs. `Ada.Containers`.** `Rope.Mod`'s
  `SplitList` (a hand-rolled singly linked `Piece`/`PieceDesc`) exists
  because Oberon-2 has no generic container library at hand. Ada does
  (`Ada.Containers.Vectors`, `Doubly_Linked_Lists`); `Ropes.Split`
  returns a plain array (`Rope_Array`, mirroring `SplitArray`), and a
  caller who wants a list instantiates `Ada.Containers.Vectors` or
  `Doubly_Linked_Lists` over `Rope` themselves rather than `Ropes`
  reinventing one.
- **Hardcoded `MaxDepth` vs. computed from the type's actual range.**
  `Rope.Mod`'s `MaxDepth = 44` is explicitly derived from voc's 32-bit
  `LONGINT` (`minLength[44]` is the last Fibonacci-like value under
  `MAX(LONGINT) = 2147483647`; `minLength[45]` would overflow) — the
  module's own comment says so. `Ropes` computes the equivalent table
  and depth bound *at package elaboration*, growing the Fibonacci-like
  sequence until it would exceed `Natural'Last`, the same technique
  `Rope.Mod`'s `InitMinLength` uses but without hardcoding the
  assumption about the integer width — see "Balancing" below.
- **Ada already has most of the string vocabulary this needs.**
  Wherever an operation overlaps something `Ada.Strings.Unbounded` or
  `Ada.Strings.Fixed` already does, `Ropes` reuses that name and that
  contract shape (`Element`, `Slice`, `Insert`, `Delete`, `Index`,
  `Trim` with `Ada.Strings.Maps.Character_Set`,
  `Ada.Characters.Handling.To_Upper`/`To_Lower` for the per-character
  case mapping `Map` is built on) instead of inventing parallel names.
  A caller who already knows `Unbounded_String` should be able to
  guess most of `Ropes`'s API correctly.

## What's explicitly out of scope (v1)

Matching `Rope.Mod`'s own stated scope, not cord's full surface:

- No lazy/function-generator leaves (cord's `CORD_from_fn`).
- No lazy substring nodes — `Slice` always copies, like `Rope.Mod`'s
  `Substring` and unlike cord's substring-node optimization.
- No file-backed ropes (`CORD_from_file`/`_lazy`/`_eager`).
- No `CORD_printf`-style formatting.

These could become a separate child package (`Ropes.Lazy`, say) later
if a real need shows up; they are not part of this plan.

## Package layout

```
Ropes/
  ropes.gpr              -- library project
  src/
    ropes.ads / .adb      -- the whole public API; one package, matching
                              Rope.Mod's own single-MODULE scope
    ropes-test_support.ads / .adb  -- test-only internals accessor (Depth); see Phase 2
  test/
    test.gpr
    test_*.adb            -- one standalone program per concern (see Testing)
  examples/
    rope_tool.gpr
    src/
      rope_tool.adb              -- main procedure
      rope_tool_args.ads / .adb  -- command definitions (see below)
```

One flat package, not a `Ropes.*` hierarchy — `Rope.Mod` is a single
module and the API is small enough (on the order of `Ada.Strings.Unbounded`)
that splitting it up front would just add navigation overhead with no
present payoff. Revisit if it grows unwieldy, same policy `alibfyaml`'s
`PLAN.md` states for `Libfyaml.Nodes`.

## Command-line tool (rope_tool)

`examples/rope_tool` is the Ada port of `RopeTool.Mod` — a git-style
CLI exposing each `Ropes` operation as a subcommand (`rope_tool cat A
B`, `rope_tool len S`, ...), built on
[`arg_parser`](~/Repos/Ada/arg_parser) (installed under
`/usr/local/sw/versions/ada/`, referenced with a bare `with
"arg_parser.gpr";` — it's on `GPR_PROJECT_PATH`, the same way
`besm2_fmt`/`ova_fmt` reference it, not a relative path into the
source checkout) instead of Oberon-2's `ArgParser`. Modeled directly
on `arg_parser`'s own multi-command example
(`~/Repos/Ada/arg_parser/examples/src/compound_args.ads`, the
"commands like git" pattern): each subcommand is its own sub-parser
whose `Argument_Handler` is called once per positional argument and
accumulates them until it has enough to act — the exact shape
`RopeTool.Mod`'s own handlers already use, just re-based onto
`Arg_Parser` instead of the Oberon-2 `ArgParser`.

**Built incrementally, in lockstep with the phased plan below, not all
at once**: a `rope_tool` subcommand is added in the same phase that
adds its underlying `Ropes` operation, never before (no stub
subcommands for operations that don't exist yet) and never left
behind once one does. Phase 1 gave `rope_tool` three subcommands —
`cat` (`"&"`), `len` (`Length`), `fetch` (`Element`, 1-based per
`Ropes`'s own indexing convention, unlike `RopeTool.Mod`'s 0-based
`Fetch`) — matching `RopeTool.Mod`'s `cat`/`len`/`fetch` commands
exactly in shape, differing only where `Ropes` itself already differs
from `Rope.Mod` (1-based indexing, `Ada.Strings.Index_Error` on a bad
`fetch` index instead of `HALT`, `Positive'Value` instead of
`ArgParser.StrToInt`/`ParseInt`). Phase 3 added `slice`
(`RopeTool.Mod`'s `sub`, renamed to match `Slice`'s own name, 1-based
inclusive `LOW HIGH` instead of 0-based `START LEN`), `insert`
(`RopeTool.Mod`'s `insert`, 1-based `BEFORE`), `delete`
(`RopeTool.Mod`'s `remove`, renamed to match `Delete`'s own name,
1-based inclusive `FROM THROUGH` instead of 0-based `POS LEN`), and
`cmp` (`RopeTool.Mod`'s `cmp`, but built in `rope_tool_args.adb` from
the public `"="`/`"<"` operators rather than wrapping a public
`Compare` — `Ropes` doesn't have one, by design; see "Comparison"
above). Phase 4 added `index`/`rindex` (`RopeTool.Mod`'s `find`/
`rfind`, both wrapping `Ropes.Index`'s `Rope`-pattern overload with
`Going => Forward`/`Backward` respectively — kept as two commands, not
one with an optional direction argument, since `Arg_Parser`'s
fixed-arity accumulator model has no clean way to make a trailing
positional optional), `indexchar`/`rindexchar` (`RopeTool.Mod`'s own
names, wrapping `Ropes.Index`'s `Character`-pattern overload), and
`split` (`RopeTool.Mod`'s `split`, wrapping `Ropes.Split`'s `Rope`
separator overload, one piece per line). The rest of `RopeTool.Mod`'s
command set (`repeat`, `trim`/`triml`/`trimr`, `upper`/`lower`/
`capitalize`/`uncapitalize`, `escaped`, `make`, `bigcat`, `contains`)
lands piecemeal as the matching `Ropes` operation lands in Phases 5–7.

`~/Repos/Oberon/oberon-tools/tests/rope-*.test` (see "Sources being
ported" above) are black-box fixtures written against `RopeTool`, run
via `tests/run-tests.sh`'s `program`/`arg`/`status`/`output` format.
Once `rope_tool` covers enough of the command set to make it
worthwhile, these are a plausible source for a `examples/tests/
run-tests.sh`-style black-box test suite for `rope_tool` itself — same
"translate the scenario, not the expected outcome" caveat as
`Ropes`'s own tests (0-based → 1-based indices, `HALT`/clamp →
`Ada.Strings.Index_Error`, `rope-unknown-command.test`'s and
`rope-help.test`'s exact wording will differ since it's `Arg_Parser`'s
`Usage`/error text, not `ArgParser`'s). Not committed to for any
specific phase yet — revisit once there's enough surface to make a
black-box suite worth the setup.

## Core design

### `Rope`, `Node`, and memory management

`Rope` is a **plain (untagged) private type**, not `new
Ada.Finalization.Controlled with private`:

```ada
type Rope is private;
Null_Rope : constant Rope;   -- the empty rope; also Rope's default value
```

Internally, a sketch (not final — illustrative of the shape only):

```ada
type Node_Kind is (Leaf_Kind, Concat_Kind);
type Node (Kind : Node_Kind; Len : Positive) is record
   Depth     : Natural;
   Ref_Count : Natural := 1;
   case Kind is
      when Leaf_Kind =>
         Chars : String (1 .. Len);          -- exact length, no slack
      when Concat_Kind =>
         Left, Right : Node_Access;          -- never null
   end case;
end record;
type Node_Access is access Node;

type Rope_Ref is new Ada.Finalization.Controlled with record
   Data : Node_Access := null;
end record;
overriding procedure Adjust   (R : in out Rope_Ref);
overriding procedure Finalize (R : in out Rope_Ref);

type Rope is record
   Ref : Rope_Ref;
end record;

Null_Rope : constant Rope := (Ref => (Ada.Finalization.Controlled with Data => null));
```

Points worth calling out explicitly:

- **`Node` is a discriminated variant record**, not a small tagged
  hierarchy mirroring `Rope.Mod`'s `Leaf`/`Concat` type extension.
  Ada's idiom for "a closed, fixed set of two node shapes" is a
  `case`-variant, not inheritance — there is no dispatching need here
  (every consumer of a `Node` already knows both possible shapes and
  switches on `Kind`), so a tagged hierarchy would add a tag word and
  dispatch overhead for nothing.
- **A `Leaf` node's characters live in an embedded, discriminant-sized
  `String` component** (`Chars : String (1 .. Len)`), not a separate
  heap-allocated `POINTER TO ARRAY OF CHAR` one level removed the way
  `Rope.Mod`'s `LeafDesc` does it — one allocation per leaf instead of
  two.
- **Why `Rope` is untagged, wrapping a tagged `Controlled` component
  instead of deriving from it directly**: if `Rope` itself were `new
  Controlled with private` (tagged), the moment a `Cursor` type for
  iteration is added (see "Iteration" below) and any subprogram takes
  both a `Rope` and a `Cursor` parameter, RM 3.9.3(10) forbids that
  subprogram from being a dispatching primitive of two different
  tagged types declared in the same package. `alibfyaml` hit this for
  real (`Node`/`Owner_Liveness`, both needing `Wrap` — see
  `libfyaml-nodes.ads`'s `Owner_Ref` comment) and worked around it the
  same way proposed here: wrap the `Controlled` type as an *inner
  component* of a plain (untagged) record. RM 7.6 finalizes/adjusts a
  controlled component automatically even when the enclosing type
  isn't itself controlled or tagged, so refcounting still works
  exactly the same way, one level removed — and `Rope` stays untagged
  forever, sidestepping the whole problem class rather than hitting it
  once `Cursor` (or anything else tagged) is added later. This also
  matches `Ada.Strings.Unbounded.Unbounded_String`, which is untagged
  and has no dot-notation call syntax either — no idiom mismatch with
  the rest of the Ada string ecosystem.
- **The acyclic invariant is load-bearing.** Reference counting only
  reclaims a *tree* exactly; it leaks on a cycle. Every `Node` here is
  built strictly bottom-up (`Cat` takes two already-built ropes and
  produces a new node referencing them; nothing is ever mutated after
  construction to point at something built later, and there are no
  parent/back pointers). This must stay true forever — see the
  matching note in `AGENTS.md`.
- **`Ref_Count` is a plain `Natural`, not atomic.** Matches
  `Ada.Strings.Unbounded`'s and most `Ada.Containers` types' own lack
  of a task-safety guarantee: copying/finalizing the same `Rope` value
  concurrently from two tasks without external synchronization is not
  supported. Flagged as an open question below in case that's not an
  acceptable default for how this gets used.
- **Freeing a `Concat` node must recursively drop its children's
  refcounts** (not just `Unchecked_Deallocation` the node itself) —
  `Left`/`Right` are raw `Node_Access`, not themselves `Controlled`
  values, so `Finalize` on the top node has to walk down. Recursion
  depth here is bounded by `Max_Depth` (below) for anything built
  through the public API (`Cat` is the only two-rope constructor and
  it always rebalances past `Max_Depth`), so this isn't a stack-depth
  risk in practice — worth a comment at the implementation site so a
  future change to how nodes get built doesn't quietly reintroduce
  one.

### Indexing and length conventions

- `function Length (Source : Rope) return Natural` — `Natural`, matching
  `Ada.Strings.Unbounded.Length`. This caps a single rope at
  `Natural'Last` characters (≈2.1×10⁹ on GNAT's default 32-bit
  `Integer`) — the same ceiling `Unbounded_String` already has, so this
  isn't a new limitation `Ropes` introduces. See the open question below
  if that turns out to matter.
- All positions are `Positive`, 1-based — **every index expression
  ported from `Rope.Mod` or the paper needs a +1/-1 adjustment**, not a
  verbatim copy. This is the easiest place to introduce an off-by-one
  bug while porting; call it out at each site during implementation.
- Out-of-range index → `Ada.Strings.Index_Error` (not `Constraint_Error`,
  not a clamp, not `HALT`).
- A concatenation/insert whose result would exceed `Natural'Last` →
  `Ada.Strings.Length_Error`, via an explicit checked-add
  (`if Left.Length > Natural'Last - Right.Length then raise
  Ada.Strings.Length_Error;`) before computing the sum — the same
  overflow check `Rope.Mod`'s `AddLen` does (there, because voc
  silently wraps on overflow instead of trapping), reusing the
  standard exception instead of `HALT(1)`.

### Balancing

`Short_Leaf_Length` (merge-on-`Cat` threshold, `Rope.Mod`'s
`ShortLeafLength`) stays a plain tunable constant, `16`, same value,
same rationale (keeps repeated single-character `&` from growing a
deep skinny tree).

`Max_Depth` and the `Min_Length` table are **computed once at package
elaboration**, not hardcoded:

```ada
Min_Length : array (0 .. <computed>) of Natural;
Max_Depth  : constant Natural := <last index filled in>;
```

grown the same way `Rope.Mod`'s `InitMinLength` does
(`Min_Length(0) = 1`, `Min_Length(1) = 2`, `Min_Length(d) =
Min_Length(d-1) + Min_Length(d-2)`), but stopping at the largest `d`
such that the next value would exceed `Natural'Last`, rather than
assuming a 32-bit integer up front and hardcoding `44`. This makes the
bound correct automatically if `Ropes` is ever built where
`Standard.Natural` has a different range, instead of silently
inheriting an assumption borrowed from voc's `LONGINT` the way a
literal `44` would.

The Fibonacci-forest rebalance itself (`BalanceInsert`/`BalanceWalk`/
`ConcatForest` in `Rope.Mod`) ports essentially as-is — it's index-free
tree-shape logic, not string-index arithmetic, so it isn't one of the
0-vs-1-based-indexing risk spots above. **[Phase 2, done.]** The one
real port-time difference is refcounting: `Rope.Mod`'s forest is a
plain `ARRAY OF Rope` under a tracing collector, so `forest[i] := NIL`
just drops a GC reference; `Ropes.Balance_Insert`/`Concat_Forest`
explicitly `Decr_Ref` a forest slot at the same point `Rope.Mod` nulls
it out, immediately after folding its content into the running `Sum`
via `New_Simple_Cat` (which borrows both operands, per the usual
`Node_Access` contract — see `ropes.adb`'s "Node-level reference
counting" section).

### Construction and concatenation

```ada
function "&" (Left, Right : Rope) return Rope;
function "&" (Left : Rope; Right : Character) return Rope;
function "&" (Left : Character; Right : Rope) return Rope;
function "&" (Left : Rope; Right : String) return Rope;
function "&" (Left : String; Right : Rope) return Rope;

function From_String (Source : String) return Rope;
function From_Character (Source : Character) return Rope;
function To_String (Source : Rope) return String;

function From_Unbounded_String (Source : Ada.Strings.Unbounded.Unbounded_String) return Rope;
function To_Unbounded_String (Source : Rope) return Ada.Strings.Unbounded.Unbounded_String;

function Repeat (Source : Rope; Count : Natural) return Rope;  -- O(log Count), binary doubling like Rope.Mod's Repeat
function Make (Length : Natural; Fill : Character) return Rope;
```

`"&"` replaces `Cat`/`AppendChar`/`FromChar` together — this is *the*
idiom substitution for a "cheap concatenation" type in Ada (mirrors
`String "&" String`, `Unbounded_String`'s own `"&"` suite exactly).
`From_Unbounded_String`/`To_Unbounded_String` have no `Rope.Mod`
counterpart (Oberon-2 has no unbounded string type) — added because
Ada does, and a rope library that can't interop with the type most Ada
code already uses for "a string that grows" would be an odd omission.

### Access and slicing

```ada
function Element (Source : Rope; Index : Positive) return Character;   -- Ada.Strings.Unbounded naming; Rope.Mod's Fetch
function Is_Empty (Source : Rope) return Boolean;
function Slice (Source : Rope; Low : Positive; High : Natural) return Rope;  -- inclusive bounds, Unbounded_String's own Slice convention/signature exactly; Rope.Mod's Substring(start, len)
```

`Slice` takes **inclusive `Low`/`High`**, matching
`Ada.Strings.Unbounded.Slice` exactly (including its exact signature —
`Low : Positive`, not `Natural`, confirmed against GNAT's
`a-strunb.ads`) — not `Rope.Mod`'s `(start, len)` pair. This is a real
shape change, not just a rename; every call site doing `Substring (R,
Start, Len)` becomes `Slice (R, Start + 1, Start + Len)` (plus the
0-to-1-based shift), not a find-and-replace.

`Rope.Mod`'s permissive clamping (`Substring`/`Insert`/`Remove` all
silently clamp an out-of-range `start`/`len`/`pos`) is **not** carried
over wholesale: `Slice`/`Insert`/`Delete` raise `Ada.Strings.Index_Error`
on a bad bound, matching `Ada.Strings.Unbounded`'s own behavior for the
same operations exactly — which is not *uniformly* "never clamp,
always raise". `Ada.Strings.Unbounded.Delete` itself still clamps a
too-large `Through` to `Length (Source)` (only `From` is
strictly checked, and only when `From <= Through`); `Slice`'s `High`
has no such clamp and always raises past the end. `Ropes` matches each
one precisely rather than picking one rule and applying it everywhere
— see each function's own doc comment in `ropes.ads` for its exact
boundary behavior. `[Phase 3, done.]`

### Modification (still non-destructive — every operation returns a new `Rope`)

```ada
function Insert (Source : Rope; Before : Positive; New_Item : Rope) return Rope;  -- Rope.Mod's Insert
function Delete (Source : Rope; From, Through : Natural) return Rope;             -- Rope.Mod's Remove
```

Names and parameter shapes taken directly from
`Ada.Strings.Unbounded.Insert`/`.Delete`. `Overwrite`/`Head`/`Tail`
(which `Unbounded_String` also has, and `Rope.Mod` doesn't) are a
plausible stretch addition — not in v1, see "Deferred / stretch" below.

### Comparison

```ada
function "="  (Left, Right : Rope) return Boolean;
function "<"  (Left, Right : Rope) return Boolean;
function "<=" (Left, Right : Rope) return Boolean;
function ">"  (Left, Right : Rope) return Boolean;
function ">=" (Left, Right : Rope) return Boolean;
```

Lexicographic, character-by-character, then by length on a common
prefix — exactly `Rope.Mod`'s `Compare` semantics, just exposed as the
six standard operators instead of a `-1/0/1` function plus a derived
`Equal`. No `strcmp`-style three-way function — nothing else in
`Ada.Strings` exposes one, and nothing here needs it.

### Search

```ada
function Index
  (Source : Rope; Pattern : Rope; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
function Index
  (Source : Rope; Pattern : Rope; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward)
   return Natural;

function Index
  (Source : Rope; Pattern : Character; Going : Ada.Strings.Direction := Ada.Strings.Forward) return Natural;
function Index
  (Source : Rope; Pattern : Character; From : Positive; Going : Ada.Strings.Direction := Ada.Strings.Forward)
   return Natural;
```

Collapses `Rope.Mod`'s four functions (`Find`, `RFind`, `IndexChar`,
`RIndexChar`) into two, reusing `Ada.Strings.Direction` the same way
`Ada.Strings.Fixed.Index` does. **Returns `0` for "not found", not
`-1`** — `Ada.Strings.Fixed.Index`'s own convention, not `Rope.Mod`'s.
**`[Phase 4, done.]`**

**Correction from the sketch above** (caught while verifying against
GNAT's actual `a-strsea.adb`, the same discipline used for `Slice`/
`Insert`/`Delete` in Phase 3): a single overload with `From : Positive
:= 1` as one shared default can't work for both directions — `From =>
1` is a sensible "search the whole rope" default for `Forward`, but
for `Backward` it would mean "search only within position 1", not
"search the whole rope from the end". `Ada.Strings.Fixed.Index` itself
solves this with **two separate overloads per pattern kind**, not one
overload with a default: a no-`From` version that searches the entire
source (first match for `Forward`, last for `Backward`), and a
`From`-bounded version with `From` as a required parameter. `Ropes`
does the same — four `Index` functions total (two pattern kinds ×
with/without `From`), matching `Ada.Strings.Fixed.Index`'s own shape
exactly rather than approximating it with a single default.

The no-`From` overload is a thin wrapper: `Forward` delegates to the
`From`-bounded overload with `From => 1`; `Backward` delegates with
`From => Length (Source)` — mathematically equivalent to searching the
unbounded whole source in each direction, confirmed against
`a-strsea.adb`'s own no-`From` `Index`.

**Empty-pattern decision** (the discrepancy flagged as an open
question in an earlier draft of this section): `Ropes.Index` raises
`Ada.Strings.Pattern_Error` for a `Null_Rope` `Pattern`, exactly
matching real `Ada.Strings.Search.Index` — **not** `Rope.Mod`'s
`Find`/`RFind`, which instead treat an empty pattern as always
matching at `from`/`before` (clamped into `[0, Length (r)]`). This
follows the house rule (`AGENTS.md`) of reusing `Ada.Strings`
vocabulary and behavior precisely rather than preserving `Rope.Mod`'s
own convention where the two diverge. The `Character` overload has no
analogous case (a `Character` is never "empty").

A further subtlety, also verified against `a-strsea.adb` rather than
assumed, and locked in by `test_index.adb`'s "Both Source and Pattern
empty" checks: the *order* of the empty-Source and empty-Pattern
checks differs between the two overloads. The `From`-bounded overload
checks `Source`'s emptiness **first** and returns `0` immediately,
even when `Pattern` is also empty (so `Index (Null_Rope, Null_Rope,
From => 1, Going => Forward) = 0`, no exception). The no-`From`
overload checks `Pattern`'s emptiness **first**, unconditionally, so
`Index (Null_Rope, Null_Rope)` (no `From`) raises `Pattern_Error` even
though `Source` is also `Null_Rope`. This is exactly what real
`Ada.Strings.Search.Index` does — the `From`-bounded version's
`Source'Length = 0` short-circuit runs before it would ever delegate
to (and hit the `Pattern = ""` check inside) the base function; a bare
call with no `From` goes straight to the base function, whose `Pattern
= ""` check has no such short-circuit.

Also verified rather than assumed: the `From`/`Going` boundary
asymmetry. `Forward` never raises for an out-of-range `From` — `Source
(From .. Length (Source))` is simply empty if `From` is too large, so
the search just finds nothing (`From < Source'First` can't happen
here since `From : Positive` and `Source'First` is always `1`).
`Backward` raises `Ada.Strings.Index_Error` if `From > Length
(Source)`.

`Rope.Mod`'s `RFind`'s own bound convention does **not** carry over
unchanged: `RFind`'s `before` clamps so that a match's *start*
position is `<= before`; `Ada.Strings.Fixed.Index`'s `Backward`
requires a match to fit **entirely** within `Source (First .. From)`,
i.e. start `<= From - Pattern'Length + 1` — one stricter by `Pattern'
Length - 1`. These coincide for a length-1 pattern (so `IndexChar`/
`RIndexChar`'s test scenarios translate to the `Character` overload
directly, 0-based → 1-based only) but genuinely differ for a longer
one, so `RFind`'s own multi-character scenarios in `test_index.adb`
use different `From`/expected values, chosen under the real formula,
not copied from `Rope.Mod`'s numbers.

`Contains (Source, Pattern) return Boolean` remains undecided —
still not added; still low-stakes, still a plausible thin wrapper over
`Index (...) /= 0` if a future phase wants it.

### Splitting

```ada
type Rope_Array is array (Positive range <>) of Rope;

function Split (Source : Rope; Separator : Rope) return Rope_Array;
function Split (Source : Rope; Separator : String) return Rope_Array;
function Split (Source : Rope; Separator : Character) return Rope_Array;
function Split
  (Source : Rope; Separator : Ada.Strings.Maps.Character_Set) return Rope_Array;
```

Four overloads, one splitting rule shared by all of them (`Rope.Mod`'s
`Split`/`SplitArray`/`SplitList` rule: maximal runs between
non-overlapping separator occurrences; leading/trailing/doubled
separator gives an empty piece — Python `str.split`'s convention):

- `Separator : Rope` / `Separator : String` — a (possibly
  multi-character) literal substring separator; the `String` overload
  is pure ergonomics over the `Rope` one (no `From_String` wrapping
  needed at the call site) and both share one internal substring-search
  implementation. An empty separator (`Null_Rope`, or `""`) never
  splits — one piece, the whole source — matching `Rope.Mod`'s own
  empty-separator convention.
- `Separator : Character` — a single-character separator (`Rope.Mod`
  has no direct equivalent; this is the natural counterpart to
  `Index`'s `Character` overload above). Always exactly one character
  wide, so there is no empty-separator case to special-case here.
- `Separator : Ada.Strings.Maps.Character_Set` — splits at each
  occurrence of *any* character in the set, one character at a time
  (**not** collapsing a run of several separator-set characters into
  one delimiter — a run of N consecutive matching characters produces
  N−1 empty pieces between them, the same non-collapsing behavior the
  `Character` and literal-separator overloads already have, and the
  same convention Python's `re.split(r'[,;]', ...)` uses for a
  character-class pattern). `Ada.Strings.Maps.Null_Set` is this
  overload's empty-separator case — never splits, matching the
  `Rope`/`String` overloads' `""` case. This overload has no
  `Rope.Mod` counterpart either, but fits naturally once `Trim` already
  needs `Character_Set` (see below) — a caller splitting on "any of
  these delimiter characters" (e.g. any whitespace) shouldn't have to
  build a set-of-single-char `Split` calls or reach for a regex engine.

Implementation note: all four share one private piece-walking loop
(`Rope.Mod`'s `NextPiece`/`CountPieces`), parameterized only by "find
the next separator occurrence at or after position P, and how wide is
it" — a substring search for the two literal forms, a single-character
equality test for `Character`, a single-character
`Ada.Strings.Maps.Is_In` test for `Character_Set`. Write this as one
shared private function/generic, not four independent copies.
**`[Phase 4, done]`**, but not quite as sketched — see below.

**What actually got built**: a local generic function,

```ada
generic
   Sep_Width : Positive;
   with function Find_Next (Source : Rope; From : Positive) return Natural;
function Split_Generic (Source : Rope) return Rope_Array;
```

holding the two-pass count-then-build walk (`Rope.Mod`'s
`CountPieces` + `NextPiece`/`SplitArray` shape, kept as two passes
rather than a single dynamic-array pass, for the same reason —
faithful to the source, not a scope change). Each `Split` overload
instantiates it **locally**, inside its own body, with `Sep_Width` and
a nested `Find_Next` function that closes over that overload's own
`Separator` parameter by ordinary lexical scoping:

- `Separator : Rope` — `Find_Next` calls the `Index` (`Pattern :
  Rope`) overload above; `Sep_Width => Length (Separator)`. The empty
  case (`Is_Empty (Separator)`) is checked *before* instantiating (a
  generic formal `Positive` can't be `0`), returning `(1 => Source)`
  directly.
- `Separator : String` — a one-line expression function, `Split
  (Source, From_String (Separator))`: this literally *is* the "share
  the Rope overload's implementation" the sketch called for, simpler
  than giving it its own instantiation.
- `Separator : Character` — `Find_Next` calls the `Index` (`Pattern :
  Character`) overload; `Sep_Width => 1`. No empty case.
- `Separator : Ada.Strings.Maps.Character_Set` — `Find_Next` is a
  small nested linear scan using `Ada.Strings.Maps.Is_In` (there is no
  public `Character_Set`-based `Index` to call — `Ropes`'s public
  `Index` only has `Rope`/`Character` pattern overloads, so this one
  case doesn't reuse `Index` the way the other three reuse either
  `Index` or the `Rope` `Split` overload); `Sep_Width => 1`. Empty case
  is `Ada.Strings.Maps.Null_Set`.

Binding `Find_Next` as a **generic formal subprogram** (not an
access-to-subprogram value) was a deliberate choice made during
implementation: a nested function closing over a local `Separator`
can't safely be turned into an `access function ...` value pointing
out of a package-level type without hitting Ada's accessibility rules
(the classic reason to reach for `Unrestricted_Access`, which this
codebase avoids elsewhere). A **local** generic instantiation sidesteps
that entirely — the formal subprogram is bound by name at compile
time, not through a runtime access value, so ordinary lexical closure
over `Separator` just works, no accessibility question ever arises.
Local (subprogram-nested) generic instantiation is ordinary, legal
Ada, re-elaborated each call, at the cost of paying that elaboration
once per `Split` call — irrelevant next to the search itself.

Non-collapsing behavior for the `Character_Set` overload requires no
special-casing: the shared walk always resumes searching starting
exactly at the position just past the previous match (`Found +
Sep_Width`), so if that position itself matches again, it's found
immediately, producing the empty piece in between — this falls out of
the walk's own structure, not an extra check.

Only the array form is ported (`Rope.Mod`'s `SplitArray`); the
push-based early-stopping `Visitor` form (`Split` in `Rope.Mod`) and
the hand-rolled linked list form (`SplitList`) are dropped — see "Why
this is a real port" above for why the list form specifically doesn't
need porting. A lazy/early-stop iterator form is a plausible stretch
addition if a caller ever needs to avoid materializing every piece of
a huge split up front; not v1.

### Whitespace / trimming

```ada
Whitespace : constant Ada.Strings.Maps.Character_Set;  -- space, tab, CR, LF, FF -- Rope.Mod's IsSpace set

function Trim
  (Source : Rope;
   Left   : Ada.Strings.Maps.Character_Set := Whitespace;
   Right  : Ada.Strings.Maps.Character_Set := Whitespace) return Rope;
```

Mirrors `Ada.Strings.Fixed.Trim`'s two-`Character_Set` overload
exactly (not the single-`Trim_End`-plus-blanks-only overload, since
that one only trims a literal space and `Rope.Mod`'s `IsSpace` covers
five characters). A caller who wants only-space trimming passes
`Ada.Strings.Maps.To_Set (' ')` explicitly, same as they would with
`Ada.Strings.Fixed`.

### Case mapping

```ada
function Map
  (Source : Rope;
   Convert : not null access function (Ch : Character) return Character) return Rope;

function Map_Indexed
  (Source : Rope;
   Convert : not null access function (Index : Positive; Ch : Character) return Character) return Rope;

function To_Upper (Source : Rope) return Rope;  -- Map (Source, Ada.Characters.Handling.To_Upper'Access)
function To_Lower (Source : Rope) return Rope;  -- Map (Source, Ada.Characters.Handling.To_Lower'Access)

function Capitalize (Source : Rope) return Rope;    -- Rope.Mod's CapitalizeAscii
function Uncapitalize (Source : Rope) return Rope;  -- Rope.Mod's UncapitalizeAscii
```

`To_Upper`/`To_Lower` (not `Rope.Mod`'s `UppercaseAscii`/
`LowercaseAscii`) reuse `Ada.Characters.Handling`'s own names, and are
implemented *as* a `Map` call using `Ada.Characters.Handling.To_Upper`/
`To_Lower (Character)` as the conversion function — no separate
hand-rolled `A..Z`/`a..z` range check the way `Rope.Mod`'s
`UpperChar`/`LowerChar` do it. `Map_Indexed` is `Rope.Mod`'s `Mapi`,
renamed for clarity and taking a `Positive` index (1-based, per the
indexing convention above) instead of `LONGINT`.

`Capitalize`/`Uncapitalize` — first character
uppercased/lowercased (ASCII-range only, via
`Ada.Characters.Handling.To_Upper`/`To_Lower (Character)`), rest of the
rope unchanged — are **promoted from an earlier deferred/stretch idea
to core v1**: both `RopeTest.Mod` and `RopeTool.Mod` exercise
`CapitalizeAscii`/`UncapitalizeAscii` as ordinary first-class
operations (not edge cases), so matching `Rope.Mod`'s scope means
keeping them in, just renamed to drop the redundant `Ascii` suffix
(there's no non-ASCII variant to disambiguate from — same reasoning
`To_Upper`/`To_Lower` above already apply). No `Ada.Strings` precedent
to match the name against (neither `Ada.Strings.Fixed` nor
`Ada.Characters.Handling` has a "capitalize" operation), so these keep
names close to `Rope.Mod`'s own, just Ada-cased.

### Iteration

**`[Phase 5, done.]`**

```ada
type Rope is private with
  Iterable => (First => First, Next => Next, Has_Element => Has_Element, Element => Element);

type Cursor is private;  -- plain record: position + cached leaf + leaf-start offset; NOT tagged, NOT Controlled

function First (Source : Rope) return Cursor;
function Next (Source : Rope; Position : Cursor) return Cursor;
function Has_Element (Source : Rope; Position : Cursor) return Boolean;
function Element (Source : Rope; Position : Cursor) return Character;
```

**Correction from the sketch this section originally had**: the
`Iterable` aspect must be spelled `with Iterable => (...)` directly on
`type Rope is private`, not as a separate `for Rope use Iterable =>
(...)` clause given later (after `First`/`Next`/`Has_Element`/
`Element` are declared) — GNAT rejects the latter with "invalid
representation clause", tried both in the visible part and in the
private part (same error either place). `with`-on-the-declaration
works because Ada resolves the aspect's forward references to
`First`/`Next`/etc. at `Rope`'s freeze point, by which time they're
declared; `for ... use` is ordinary representation-clause syntax and
doesn't get that forward-reference allowance. Confirmed against every
actual `Iterable`-using type on this machine (GNAT's own
`g-lists.ads`/`g-sets.ads`/etc., and third-party code under
`/usr/local/sw/src/lang/Ada/alire/`) — all of them use `with
Iterable => (...)` on the type declaration; none use `for ... use`.

Gives `for Ch of Some_Rope loop ... end loop;` directly — the Ada
replacement for `Rope.Mod`'s heap-allocated `Iterator` object and its
`Get`/`Incr`/`Decr`/`Goto`/`Move`/`Peek`/`Source` methods.  `Cursor`
caches the current leaf and its start offset the same way `Rope.Mod`'s
`Iterator` does (`Locate`), giving the same O(1)-amortized/O(log
n)-on-leaf-crossing behavior — but functionally: `Next` returns a new
`Cursor` value rather than mutating one in place, matching the
`Iterable` aspect's contract (every one of `First`/`Next`/
`Has_Element`/`Element` takes the `Rope` container explicitly on every
call, so `Cursor` never needs to carry its own reference back to the
rope or keep anything alive by itself).

**`Cursor` must stay untagged** — this is the concrete case the
RM 3.9.3(10) note under "`Rope`, `Node`, and memory management" above
is about. If `Cursor` were `tagged` (e.g. `new Controlled with
private`), `Next (Source : Rope; Position : Cursor) return Cursor`
would be a subprogram with parameters of two different tagged types
declared in this same package, illegal per RM 3.9.3(10) — exactly what
`alibfyaml` hit with `Node`/`Owner_Liveness` and resolved by keeping
one of the two types a plain record. `Cursor` doesn't need to be
controlled anyway (see above — nothing about the `Iterable` aspect
contract requires it to independently own anything), so this costs
nothing.

`Element (Source, Index : Positive)` (direct indexed access, O(log n))
and `Element (Source, Position : Cursor)` (cursor access, O(1)
amortized) coexist as overloads, disambiguated by the second
parameter's type.

### Deferred / stretch (not v1)

- `Overwrite`, `Head`, `Tail` (`Unbounded_String` has them, `Rope.Mod`
  doesn't — plausible additions, not required to match scope).
- `Escaped` (`Rope.Mod`'s backslash-escape utility) — kept as an idea,
  not committed to a name yet. Needs a clear doc note that Ada string
  *literals* don't use backslash escapes at all (quote-doubling is the
  only escape Ada source syntax has), so this would be a debug/display
  convenience, not anything resembling Ada literal syntax — call it
  something that doesn't imply otherwise (`Escaped` on its own reads
  ambiguously; maybe `To_Display_String` or similar — decide at
  implementation time).
- A lazy/early-stopping `Split` iterator (see "Splitting" above).
- Wider-than-`Natural` length type for ropes over ~2×10⁹ characters
  (see the open question below).

## Open questions (flagging for review, not blocking the plan)

1. **Task-safety of the refcount.** Plain `Natural`, not atomic — same
   default as `Ada.Strings.Unbounded` and most `Ada.Containers` types.
   Fine unless `Ropes` values need to be copied/dropped concurrently
   from multiple tasks without external synchronization; revisit only
   if that's a real requirement.
2. **`Natural`-bounded length (≈2.1×10⁹ characters).** Matches
   `Ada.Strings.Unbounded`'s own ceiling, so not a new limitation — but
   worth confirming that parity with `Unbounded_String` is the right
   call here rather than a wider `Rope_Length` type, given that
   "scales past what a flat array handles well" is part of ropes'
   whole point.
3. **`Escaped`/display-string naming** — see "Deferred / stretch" above.

## Phased implementation plan

- **Phase 0 (this):** `AGENTS.md` + `PLAN.md`. Done by this task.
- **Phase 1 [done]:** `Rope`/`Node`/`Rope_Ref` skeleton, refcounting
  (`Adjust`/`Finalize`), `Null_Rope`, `Length`, `Is_Empty`, plain `"&"`
  (short-leaf merge only — `Rope.Mod`'s `SimpleCat`; no depth check/
  rebalance yet), `From_String`/`To_String`, `Element (Rope,
  Positive)`. Implemented in `src/ropes.ads`/`.adb`;
  `test/test_construction.adb` (19 checks, translated from
  `RopeTest.Mod`'s `CheckConstruction`/`CheckLengthAndFetch`/`CheckCat`
  content assertions per "Testing approach" below) all pass and run
  clean under valgrind (29 allocs / 29 frees, 0 errors) — confirms the
  `New_Simple_Cat` absorb-branch's `Decr_Ref (Merged)` (dropping the
  local temporary's reference after `New_Concat` takes its own) is
  correct, the single trickiest refcounting spot in this phase.
  `examples/rope_tool` also gained its `cat`/`len`/`fetch` subcommands
  in this phase — see "Command-line tool (rope_tool)" above.
- **Phase 2 [done]:** `Max_Depth`/`Min_Length` elaboration-time
  computation (`Compute_Max_Depth`/`Compute_Min_Length`, growing the
  Fibonacci-like sequence until the next term would exceed
  `Natural'Last` — 44 on a 32-bit `Natural`, matching `Rope.Mod`'s
  hardcoded value), `"&"`'s depth check, `Balance` (`Balance_Insert`/
  `Balance_Walk`/`Concat_Forest`, the Fibonacci-forest algorithm,
  ported directly from `Rope.Mod`'s `BalanceInsert`/`BalanceWalk`/
  `ConcatForest` with explicit `Incr_Ref`/`Decr_Ref` bookkeeping in
  place of what GC handles implicitly there). `Balance`/`Min_Length`/
  `Max_Depth` stay internal to `ropes.adb` — not exposed publicly, per
  "Core design" above never listing `Depth`/`IsBalanced`/`Balance` as
  public `Ropes` operations. A new child package,
  `Ropes.Test_Support` (`function Depth (Source : Rope) return
  Natural`), exists solely so tests can confirm depth stays bounded
  without exposing `Depth` on the real public API — documented as
  test-only in its own header comment. `test/test_balance.adb` (5
  checks, translated from `RopeTest.Mod`'s `CheckStressAndBalance`
  content/depth assertions) confirms a 2000-character
  one-character-at-a-time `"&"`-loop round-trips correctly and stays
  at `Depth < 60` (well below the ~125 a short-leaf-merge-only,
  never-rebalanced tree would reach) — all pass, valgrind-clean (0
  errors, 0 definite/indirect leaks; 5,952 allocs / 5,951 frees, the
  1-block difference being the same pre-existing GNAT-runtime
  "still reachable" block `test_construction` also shows, not a leak
  in `Ropes` itself).
- **Phase 3 [done]:** `Slice`, `Insert`, `Delete`, the five comparison
  operators. Implementation shares two new internal helpers with each
  other and with `Element`: `Fetch` (extracted from `Element`'s
  former nested function, now also used by `Compare`) and
  `Node_Slice` (Rope.Mod's `SubstrHelper`, 0-based internally, with a
  whole-node sharing shortcut extended to leaves too — a strict
  improvement over `Rope.Mod`, which only takes that shortcut for a
  `Concat`). `Insert`/`Delete` are themselves both implemented as one-
  or two-line compositions of `Slice` and `"&"` (matching `Rope.Mod`'s
  own `Insert`/`Remove`, which are `Substring` + `Cat` compositions),
  not hand-rolled tree surgery. `Delete`'s `Through`-past-the-end
  clamp and `Slice`'s `High`-past-the-end `Index_Error` are
  deliberately different (see "Access and slicing"/`ropes.ads`'s
  `Delete` comment for why — `Ada.Strings.Unbounded.Delete` and
  `.Slice` themselves differ the same way). `test/test_slice.adb` (8
  checks), `test_insert.adb` (8), `test_delete.adb` (9), and
  `test_compare.adb` (13) — 38 checks total, translated from
  `RopeTest.Mod`'s `CheckSubstring`/`CheckInsert`/`CheckRemove`/the
  `Compare`/`Equal` half of `CheckCompareFindRepeat` — all pass,
  valgrind-clean. Several `Rope.Mod` clamp-cases had no direct
  translation at all (a negative `Low`/`Before`/`From`), since those
  parameters are `Positive` — not a differently-handled case, just not
  a representable call; each test file's header comment says so.
  `examples/rope_tool` gained `slice`/`insert`/`delete`/`cmp` in this
  phase too — see "Command-line tool (rope_tool)" above.
- **Phase 4 [done]:** `Index` (`Rope`/`Character` patterns, each with a
  no-`From` and a `From`-bounded overload, both directions — four
  functions total, not the two-with-a-default originally sketched; see
  "Search" above for why), all four `Split` overloads (`Rope`/`String`/
  `Character`/`Character_Set`, via a local generic `Split_Generic`
  instantiated per overload — see "Splitting" above). Both `Index`'s
  empty-pattern behavior (`Ada.Strings.Pattern_Error`, not `Rope.Mod`'s
  clamp-and-match) and its `Backward` bound convention (a match must
  fit entirely within `Source (1 .. From)`, not `Rope.Mod`'s `RFind`
  looser "start `<= before`") were resolved by reading GNAT's actual
  `a-strsea.adb` rather than assumed — same discipline as Phase 3's
  `Slice`/`Insert`/`Delete` verification against `a-strunb.ads`/`.adb`.
  `test/test_index.adb` (25 checks, translated from `RopeTest.Mod`'s
  `CheckCompareFindRepeat`'s `Find` cases and `CheckIndexCharAndRFind`,
  plus new checks locking in the empty-Source/empty-Pattern check
  ordering and the `Forward`-never-raises/`Backward`-raises-past-the-
  end asymmetry — none of which `Rope.Mod` had reason to test, since
  its own `Find`/`RFind` don't have these behaviors) and
  `test/test_split.adb` (15 checks, translated from `RopeTest.Mod`'s
  `CheckSplit`, minus its visitor-early-stop and `SplitList` cases,
  which don't translate — no visitor/list API exists here) — 40 checks
  total, all pass, valgrind-clean across every test binary (0 errors,
  0 definite/indirect leaks). `Rope.Mod`'s `Contains` has no `Ropes`
  counterpart yet (see "Search" above — still optional/undecided).
  `examples/rope_tool` gained `index`/`rindex` (`Rope` pattern, the
  `Going => Forward`/`Backward` split into two commands since
  `Arg_Parser`'s fixed-arity accumulator model doesn't have a clean way
  to make a trailing positional argument optional — `RopeTool.Mod`'s
  own `find`/`rfind` split the same way, for an unrelated reason: it
  never had a unified `Index`), `indexchar`/`rindexchar` (`Character`
  pattern, `RopeTool.Mod`'s own names carried over unchanged — there's
  no better `Ada.Strings`-vocabulary name for a CLI subcommand
  distinguishing "search for one character" from `index`), and `split`
  (`Rope` separator overload, one piece per line, matching
  `RopeTool.Mod`'s own `split` description) in this phase.
- **Phase 5 [done]:** `Cursor` + `Iterable` aspect. `Cursor` is a plain
  (non-tagged, non-`Controlled`) private record — `Pos`, plus a cached
  `Leaf`/`Leaf_Start` (`Rope.Mod`'s `Iterator.Locate`, ported
  functionally: `First`/`Next` each *produce* a `Cursor` whose cache
  already covers its own `Pos`, rather than mutating a heap object in
  place the way `Rope.Mod`'s `Iterator.Get`/`Incr`/`Decr` do). The
  `Iterable` aspect itself had to be given as `with Iterable => (...)`
  directly on `type Rope is private`, not as a separate `for Rope use
  Iterable => (...)` clause the way `PLAN.md`'s original sketch showed
  — GNAT rejects the latter ("invalid representation clause") because
  `First`/`Next`/`Has_Element`/`Element` are declared *after* `Rope`
  in the same package, and only the `with`-on-the-declaration form
  resolves that forward reference (confirmed against every
  `Iterable`-using type actually in this machine's GNAT/Alire tree —
  none use `for ... use`). A new private helper, `Locate_Leaf`
  (`Fetch`'s descent shape, threading an extra `Base` accumulator to
  recover the covering leaf's absolute start position), backs both
  `First` and `Next`; `Next` only re-descends from the root
  (`Locate_Leaf`, O(log n)) when the new position has left the old
  `Cursor`'s cached leaf, otherwise it's O(1) — `Element` and
  `Has_Element` never call `Locate_Leaf` at all, just read the
  already-valid cache. `Rope.Mod`'s arbitrary-position `Peek`/`Goto`/
  `Move`/`Decr`/`Source` have no counterpart — the `Iterable` aspect's
  scope is forward-only `First`/`Next`/`Has_Element`/`Element`, so
  there is nothing to port them to; `test/test_iterator.adb`'s header
  comment says so rather than silently dropping them.
  `test/test_iterator.adb` (12 checks, translated from `RopeTest.Mod`'s
  `CheckIterator` — its `Get`/`Incr` stepping and its "walking forward
  matches `Fetch` at every position" loop, both against the same
  two-leaf test rope shape so the leaf-boundary crossing at position
  16/17 is actually exercised) confirms `for Ch of R loop` itself
  (empty rope, short rope, content order), `Has_Element` at both ends,
  and a `First`/`Next` walk matching `Element (Rope, Positive)`
  everywhere. It also has one generously-tolerant wall-clock check (a
  10×-larger rope's full traversal takes under 25× as long) —
  the first timing-based check in this test suite, a deliberate
  departure from every earlier phase's purely structural/deterministic
  style (Phase 2's `Depth`-bound check being the closest precedent),
  chosen because "amortized O(1) stepping, not just correctness" is
  explicitly this phase's own stated goal above and a depth-style
  structural proxy doesn't exist for traversal *speed* the way it does
  for balance. All pass, valgrind-clean. `examples/rope_tool` gained
  `chars` (`chars S` — prints each character of `S`, one per line,
  via `for Ch of S loop`) — this one has no `RopeTool.Mod` counterpart
  to port at all (confirmed: no "iterate"/"walk"/etc. in its command
  list), unlike every other `rope_tool` subcommand so far, which wraps
  an existing `RopeTool.Mod` command. `for Ch of R loop` is a language
  construct, not a `Ropes` operation in the usual sense, but leaving
  the new `Iterable` aspect with no `rope_tool` demonstration at all
  would have been a real gap in what `rope_tool` is *for* (see this
  file's "Command-line tool (rope_tool)" section) — a first miss,
  caught by the user rather than by this phase's own "add the matching
  subcommand" checklist, since that checklist had implicitly narrowed
  to "wrap an existing `RopeTool.Mod` command" rather than "demonstrate
  the phase's `Ropes` addition, `RopeTool.Mod` precedent or not".
- **Phase 6:** `Map`/`Map_Indexed`, `To_Upper`/`To_Lower`,
  `Capitalize`/`Uncapitalize`, `Trim`.
- **Phase 7 (stretch):** `From_Unbounded_String`/`To_Unbounded_String`,
  whatever "deferred" items above turn out to be worth adding.

Each phase gets its own `test_*.adb`(s) before moving to the next,
rather than one big test file added at the end. Each phase also adds
the matching `rope_tool` subcommand(s) — see "Command-line tool
(rope_tool)" above for the current/planned mapping.

## Testing approach

Mirrors `alibfyaml`'s `test/` convention (see its `AGENTS.md`): one
`test_*.adb` per concern, each its own standalone `Main` in `test.gpr`
(not a single monolithic test runner), printing `ok   - <label>` /
`FAIL - <label>` per check and a trailing summary line. No `AUnit`
dependency — nothing else in this repo (`ulid_try`, `uuid_test`, the
`alibfyaml`/`besm2_fmt`/`ova_fmt` family) pulls one in either, and a
library this size doesn't need the extra machinery.

**Source the actual test cases from `RopeTest.Mod` and
`~/Repos/Oberon/oberon-tools/tests/rope-*.test`** (see "Sources being
ported" above) — they already enumerate the edge cases per operation
(`NIL`/empty operands, negative and past-the-end positions, the
short-leaf-merge and absorb-into-concat depth cases in `CheckCat`, the
2000-character `AppendChar`-loop depth-and-`Balance` stress test in
`CheckStressAndBalance`, the `LONGINT`-boundary overflow case in
`CheckOverflowGuard`/`rope-bigcat-overflow.test`). Translate each
check, but **do not translate the expected outcome verbatim where this
plan changed it**: every `RopeTest.Mod` case that asserts clamping
(`"Substring clamps a negative start"`, `"Insert clamps a too-large pos
to the end"`, `"Remove clamps a negative len to 0"`, and their
`.test`-fixture counterparts) becomes a case asserting
`Ada.Strings.Index_Error` is raised instead, per "Indexing and length
conventions" and "Access and slicing" above; a case phrased around
`Rope.Mod`'s 0-based indices or `(start, len)` `Substring` needs its
numbers reworked for 1-based `Slice (Low, High)`, not just copied.
Content-only checks (`Cat` merging/depth behavior, `Map`/`Mapi`
threading, `Trim`, `Compare` ordering, `Split`'s piece-count and
empty-piece rules) carry over close to as-is.

**Run anything touching `Adjust`/`Finalize`/node-freeing under
valgrind**, not just its own pass/fail assertions — `alibfyaml`'s
`AGENTS.md` documents this as "not optional polish" after real
ownership bugs there passed their own tests while quietly reading
freed memory, and the exact same class of bug (a refcount decremented
wrong, a child node freed while still referenced from elsewhere) is
possible here for the same underlying reason: manual reference
counting has no compiler backstop the way GC-backed `Rope.Mod`/cord
do.
