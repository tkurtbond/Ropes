# Ropes for Ada

This software is developed with the aid of AI.

`Ropes` is an Ada 2022 implementation of *ropes*, the immutable,
tree-structured strings described by Hans-J. Boehm, Russ Atkinson, and
Michael Plass in "Ropes: an Alternative to Strings" (*Software—Practice
and Experience* 25(12), 1995). A rope is a binary tree of flat string
leaves joined by concatenation nodes. That makes concatenation,
slicing, insertion and deletion cheap on long strings, because they
share structure with the original rope instead of copying characters.

It is a port of the Oberon-2 `Rope.Mod` module (from `oberon-tools`),
reworked with Ada idioms:

- **Immutable values.** Every operation returns a new `Rope`, so
  ropes can be shared and copied freely; a copy costs O(1) (a
  reference-count bump). Memory is reclaimed by reference counting.
  Because ropes are acyclic, that reclaims everything.
- **Balanced automatically.** `"&"` merges short leaves and rebalances
  when the tree gets too deep, using the paper's Fibonacci-forest
  algorithm.
- **`Ada.Strings` vocabulary.** Indexing is 1-based. The operations
  are named and shaped after `Ada.Strings.Unbounded` and
  `Ada.Strings.Fixed`, as functions returning a new `Rope`. They take
  `Character_Set`s and `Character_Mapping`s from `Ada.Strings.Maps`,
  and raise `Ada.Strings.Index_Error` on bad bounds. Where GNAT's
  runtime is laxer than the RM (the `From` parameter of `Index`, for
  instance), `Ropes` follows the RM.
- **Iterable.** `for Ch of Some_Rope loop ... end loop;` works directly.

The full API is in [`src/ropes.ads`](src/ropes.ads). It covers:

- **Construction:** `From_String`, `From_Character`, `"&"`, `"*"`
  (repeating a `Character`, `String` or `Rope`),
  `From_/To_Unbounded_String` and `To_String`.
- **Access:** `Length`, `Is_Empty`, `Element`, `Slice`, and
  `Copy_Slice` into part of an existing `String`.
- **Editing:** `Insert`, `Delete`, `Overwrite`, `Replace_Slice`,
  `Replace_Element`, `Head` and `Tail`.
- **Comparison:** `=`, `<`, `<=`, `>` and `>=` between ropes, or
  between a rope and a `String`, plus `Equal_Case_Insensitive`,
  `Less_Case_Insensitive`, `Hash` and `Hash_Case_Insensitive` (for
  hashed containers).
- **Searching:** `Index` (for a rope, `String`, `Character` or
  `Character_Set`, in either direction and optionally from a given
  position), `Index_Non_Blank`, `Contains`, `Count` and `Find_Token`.
  The pattern searches take an optional `Mapping`, for
  case-insensitive search among other uses.
- **Transformation:** `Split` (array-returning or callback), `Trim`,
  `Translate`, `Map`/`Map_Indexed`, case conversion (`To_Upper`,
  `To_Lower`, `Capitalize`, `Uncapitalize`) and `Escape`.
- **`Process_Chunks`**, which hands each leaf to a callback so that a
  rope can be written anywhere without flattening it.

Searches, comparisons and hashing walk the rope's leaves directly, so
they take linear time however the rope was built.

[`src/ropes-text_io.ads`](src/ropes-text_io.ads) (`Ropes.Text_IO`)
adds `Put`, `Put_Line` and `Get_Line`, mirroring
`Ada.Text_IO.Unbounded_IO`. Prefer them to `Put_Line (To_String (R))`:
`To_String` builds its copy on the stack, so a large enough rope
overflows it, while `Put` writes leaf by leaf and `Get_Line` reads a
line of any length in chunks.

[`src/ropes-stream_io.ads`](src/ropes-stream_io.ads) (`Ropes.Stream_IO`)
adds whole-file I/O, byte for byte: `Read_File (Name)`/`Write_File
(Name, Item)`, and `Read`/`Write` on an `Ada.Streams.Stream_IO`
file. Use it, not a `Get_Line` loop, to load or save a whole document:
`Text_IO` is line-oriented, so it can't tell whether the last line had
a line feed, and treats form feeds as page terminators.

## Example

```ada
with Ada.Strings;
with Ada.Text_IO; use Ada.Text_IO;
with Ropes;       use Ropes;
with Ropes.Text_IO;

procedure Hello_Ropes is
   R : constant Rope := From_String ("Hello") & ", " & From_String ("world");
   S : constant Rope := Insert (R, Before => 8, New_Item => From_String ("big "));
begin
   Ropes.Text_IO.Put_Line (S);                   --  Hello, big world
   Put_Line (Natural'Image (Length (S)));        --  16
   Put_Line (To_String (Slice (S, 8, 10)));      --  big
   Put_Line (Natural'Image (Index (S, 'o', Going => Ada.Strings.Backward)));  --  13
   for Ch of S loop
      Put (Ch);
   end loop;
   New_Line;
end Hello_Ropes;
```

To use the library from your own project, `with "path/to/ropes.gpr";`
in your `.gpr` file.

## Building

Requirements: a GNAT that supports Ada 2022, plus `gprbuild`. The
`rope_tool` example also needs
[`arg_parser`](https://github.com/tkurtbond/arg_parser), installed
somewhere on `GPR_PROJECT_PATH`.

Build the library (a static library, `lib/libropes.a`):

```sh
gprbuild -P ropes.gpr -p
```

Build everything and run all the tests: the unit tests in `test/`
(standalone programs, one per area, each printing `ok   - ...` /
`FAIL - ...` per check) and the `rope_tool` fixtures in
`examples/tests/`. It finishes by printing the total:

```sh
make test
```

`make build`, `make build-test` and `make build-examples` build the
parts separately. To run one test program by itself:

```sh
cd test && ./test_index
```

The `rope_tool` command-line demo runs one `Ropes` operation per
subcommand on its arguments. To build it, try it, and run its
black-box test suite by itself:

```sh
cd examples
gprbuild -P rope_tool.gpr -p
./rope_tool cat foo bar       # foobar
./rope_tool split a,b,c ,     # a / b / c, one per line
./rope_tool lines tests/data/lines.txt   # each line's length, then the line
./rope_tool readfile tests/data/exact.bin  # length, then every byte, escaped
./rope_tool countci "The cat and the hat" the   # 2
./rope_tool --help            # list every subcommand
./tests/run-tests.sh
```

## Further reading

- [`PLAN.md`](PLAN.md) covers the design rationale, how each
  `Rope.Mod` operation maps to Ada, and the phased implementation
  history.
- [`AGENTS.md`](AGENTS.md) has working notes: how to build and test,
  the codebase's conventions, and the lessons learned along the way.
- [`oberon-tools`](https://github.com/tkurtbond/oberon-tools)'s
  `Rope.Mod` is the Oberon-2 original. Many of this port's additions
  have been ported back to it.

This project began in
[`ada-experiments`](https://github.com/tkurtbond/ada-experiments) and
was moved here with its full history.
