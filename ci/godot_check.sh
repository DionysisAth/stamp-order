#!/usr/bin/env bash
# Runs a headless Godot command and fails if it exits non-zero, times out or
# prints a script error (GDScript errors do not change the exit code).
#   ci/godot_check.sh <timeout-seconds> <godot args...>
set -uo pipefail
limit="$1"
shift
log="$(mktemp)"
timeout "$limit" godot --headless "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if [ "$status" -eq 124 ]; then
  echo "::error::godot $* timed out after ${limit}s"
  exit 1
fi
if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
  echo "::error::godot $* printed script errors"
  exit 1
fi
exit "$status"
