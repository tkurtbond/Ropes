# Build and test Ropes.  See AGENTS.md's "Build / test".
#
#   make build           the Ropes library (ropes.gpr)
#   make build-test      the test/test_* programs (test/test.gpr)
#   make build-examples  rope_tool (examples/rope_tool.gpr)
#   make test            run every test/test_* program and the
#                        examples/tests/ rope_tool fixtures, then print
#                        the total of checks ok and failed
#   make clean           gprclean each of those three projects

TESTS := $(patsubst %.adb,%,$(notdir $(wildcard test/test_*.adb)))

.PHONY: all build build-test build-examples test clean

all: build

build:
	gprbuild -P ropes.gpr -p

build-test: build
	cd test && gprbuild -P test.gpr -p

build-examples: build
	cd examples && gprbuild -P rope_tool.gpr -p

# Each test/test_* program prints one "ok   - " or "FAIL - " line per
# check; a program that exits nonzero without printing any FAIL line
# (a crash, an unhandled exception) counts as one more failure, so it
# can't go unnoticed.  run-tests.sh ends with its own "N ok, M failed".
test: build-test build-examples
	@ok=0; failed=0; \
	for t in $(TESTS); do \
	  out=$$(cd test && ./$$t 2>&1); status=$$?; \
	  o=$$(printf '%s\n' "$$out" | grep -c '^ok   - '); \
	  f=$$(printf '%s\n' "$$out" | grep -c '^FAIL - '); \
	  printf '%s\n' "$$out" | grep '^FAIL - ' | sed "s/^/$$t: /"; \
	  if [ $$status -ne 0 ] && [ $$f -eq 0 ]; then \
	    echo "$$t: exited with status $$status"; f=1; \
	  fi; \
	  ok=$$((ok + o)); failed=$$((failed + f)); \
	done; \
	echo "test/: $$ok ok, $$failed failed"; \
	out=$$(cd examples && ./tests/run-tests.sh 2>&1); \
	printf '%s\n' "$$out" | grep '^FAILED: '; \
	summary=$$(printf '%s\n' "$$out" | tail -n 1); \
	echo "examples/tests/: $$summary"; \
	eo=$$(echo "$$summary" | sed -n 's/^\([0-9]*\) ok, \([0-9]*\) failed$$/\1/p'); \
	ef=$$(echo "$$summary" | sed -n 's/^\([0-9]*\) ok, \([0-9]*\) failed$$/\2/p'); \
	if [ -z "$$eo" ]; then eo=0; ef=1; fi; \
	ok=$$((ok + eo)); failed=$$((failed + ef)); \
	echo "Total: $$ok ok, $$failed failed"; \
	[ $$failed -eq 0 ]

clean:
	cd examples && gprclean -P rope_tool.gpr
	cd test && gprclean -P test.gpr
	gprclean -P ropes.gpr
