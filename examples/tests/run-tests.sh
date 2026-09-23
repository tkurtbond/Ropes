#!/bin/bash
# Run the fixtures in this directory against rope_tool and report how
# many passed. With -v, also announce each test and its outcome as it
# goes. With -o, do that and also show what rope_tool actually printed
# (everything it wrote, exactly as it wrote it, and its exit status),
# whether the test passed or not. Any other arguments name the tests to
# run, instead of all of them; each may be a bare NAME, NAME.test, or
# tests/NAME.test.
# rope_tool is run from BINDIR, relative to the directory above
# (default: that directory itself, i.e. examples/), so a build made
# elsewhere can be tested too.
#
#   examples/tests/run-tests.sh -o cat rope-split
#
# A fixture is tests/NAME.test, with these lines, in this order:
#
#   program NAME     the program to run, in the directory above (always
#                    "rope_tool" here, but kept as its own line for the
#                    same reason the source this was ported from does)
#   arg VALUE        one command line argument; repeat for each argument
#                    (a bare "arg" is an empty argument)
#   env NAME=VALUE   set an environment variable for the program; repeat
#                    for each variable (optional)
#   dir DIRECTORY    run the program in this directory (optional)
#   input FILE       the program's standard input, relative to DIRECTORY
#                    (optional; default /dev/null, so no test can hang
#                    waiting on the terminal)
#   status N         the expected exit status
#   output           everything after this line is the expected output
#
# Lines starting with # before "output" are comments. Trailing white
# space is ignored when comparing output. Both the output and the error
# output are compared, mixed together.
#
# This is a direct port of ~/Repos/Oberon/oberon-tools/tests/
# run-tests.sh -- see PLAN.md's "Command-line tool (rope_tool)"
# section. The harness itself needed no changes at all (it is already
# generic over "program" and "bindir"); only the fixtures are
# rope_tool's own (translated from Rope.Mod's own tests/rope-*.test,
# not copied -- see each fixture's own header comment where the
# scenario or its expected outcome differs from the Oberon original:
# 0-based -> 1-based indices, HALT/clamp -> an Ada.Strings exception
# with this CLI's own "Error: ..." wording, and rope-help.test's /
# rope-unknown-command.test's exact wording, which is Arg_Parser's own
# Usage/error text, not ArgParser's). One addition since the port: the
# "input" line, added at Phase 11 for rope_tool's "lines -" (the
# original has no way to feed a program standard input, and ran it with
# the harness's own).

verbose=0
show=0
while getopts vo opt; do
  case $opt in
    v) verbose=1 ;;
    o) verbose=1; show=1 ;;
    *) echo "usage: $0 [-v] [-o] [TEST...]" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

bindir=${BINDIR:-.}

cd "$(dirname "$0")/.." || exit 2
root=$PWD

fixtures=()
if [ $# -eq 0 ]; then
  fixtures=(tests/*.test)
else
  for arg; do
    fixture=tests/$(basename "$arg" .test).test
    if [ ! -f "$fixture" ]; then
      echo "$0: no such test: $arg" >&2
      exit 2
    fi
    fixtures+=("$fixture")
  done
fi

ok=0
failed=0
failures=()

strip () { sed -e 's/[[:space:]]*$//'; }

# Show what the program printed, for -o.
show_output () {
  echo "  output (exit status $got):"
  if [ -n "$raw" ]; then
    printf '%s\n' "$raw" | sed 's/^/    /'
  else
    echo "    (none)"
  fi
}

for fixture in "${fixtures[@]}"; do
  name=$(basename "$fixture" .test)
  program=
  status=
  dir=.
  input=/dev/null
  args=()
  envs=()
  while IFS= read -r line; do
    case $line in
      '#'*)      ;;
      'program '*) program=${line#program } ;;
      arg)       args+=("") ;;
      'arg '*)   args+=("${line#arg }") ;;
      'env '*)   envs+=("${line#env }") ;;
      'dir '*)   dir=${line#dir } ;;
      'input '*) input=${line#input } ;;
      'status '*)  status=${line#status } ;;
      output)    break ;;
    esac
  done < "$fixture"

  expected=$(sed '1,/^output$/d' "$fixture" | strip)
  case $bindir in
    /*) exe=$bindir/$program ;;
    *)  exe=$root/$bindir/$program ;;
  esac
  raw=$(cd "$dir" && env "${envs[@]}" "$exe" "${args[@]}" < "$input" 2>&1)
  got=$?
  raw=${raw//"$exe"/$program}
  actual=$(printf '%s\n' "$raw" | strip)

  if [ "$got" = "$status" ] && [ "$actual" = "$expected" ]; then
    ok=$((ok + 1))
    if [ "$verbose" -eq 1 ]; then
      echo "ok: $name"
      [ "$show" -eq 1 ] && show_output
    fi
  else
    failed=$((failed + 1))
    failures+=("$name")
    echo "FAILED: $name  ($program ${args[*]})"
    [ "$show" -eq 1 ] && show_output
    [ "$got" = "$status" ] || echo "  exit status: expected $status, got $got"
    diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") | sed 's/^/  /'
  fi
done

echo
echo "$ok ok, $failed failed"
[ "$failed" -eq 0 ]
