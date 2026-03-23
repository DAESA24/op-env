#!/bin/bash
# Minimal assertion helper for op-env tests

TESTS=0
FAILURES=0

assert_eq() {
  TESTS=$((TESTS + 1))
  if [ "$1" != "$2" ]; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $3 — expected '$1', got '$2'" >&2
  fi
}

assert_contains() {
  TESTS=$((TESTS + 1))
  if ! echo "$1" | grep -qF -- "$2"; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $3 — output does not contain '$2'" >&2
  fi
}

assert_not_contains() {
  TESTS=$((TESTS + 1))
  if echo "$1" | grep -qF -- "$2"; then
    FAILURES=$((FAILURES + 1))
    echo "FAIL: $3 — output should not contain '$2'" >&2
  fi
}

report() {
  echo ""
  if [ "$FAILURES" -gt 0 ]; then
    echo "FAILED: $((TESTS - FAILURES))/$TESTS passed ($FAILURES failures)" >&2
    exit 1
  else
    echo "PASSED: $TESTS/$TESTS tests passed"
    exit 0
  fi
}
