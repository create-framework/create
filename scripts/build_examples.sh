#!/bin/sh
# Builds every example and benchmark entrypoint, several at a time.
#
#   pixi run build-examples
#
# A consumer build type-checks only the `def` bodies it reaches, so this
# catches API drift in examples and benchmarks that neither precompile nor
# the tests see. --emit llvm stops after type-checking and IR generation:
# the binaries were never used, and skipping optimisation and linking saves
# about a third.
#
# The library is precompiled once and every entrypoint imports the result,
# as the tests do: against src each build would parse and elaborate the whole
# package again, most of its time.
#
# A warning fails the build too: an unused result is how a discarded
# `shape.move_to(...)` (a verb returning a new value) shows, and nothing else
# would catch it.
set -u

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

entrypoints=$(grep -rlE '^def main' examples benchmarks --include='*.mojo' \
    | sort)
if [ -z "$entrypoints" ]; then
    echo "No example or benchmark entrypoints found." >&2
    exit 1
fi
if ! mojo precompile src/create -o "$out/create.mojoc" > "$out/precompile.log" 2>&1
then
    cat "$out/precompile.log"
    echo "The library does not compile; no examples were built."
    exit 1
elif grep -q "warning:" "$out/precompile.log"; then
    cat "$out/precompile.log"
    echo "FAIL the library (warnings)"
    exit 1
fi

jobs=$(nproc 2>/dev/null || echo 4)
[ "$jobs" -gt 8 ] && jobs=8
export OUT="$out"
# Each path reaches the worker as $1 rather than through -I: BSD xargs (macOS)
# caps a command assembled by -I at 255 bytes, and this one is longer.
echo "$entrypoints" | xargs -n 1 -P "$jobs" sh -c '
    name=$(echo "$1" | tr / _)
    if ! mojo build -I "$OUT" --emit llvm "$1" -o "$OUT/$name.ll" \
        > "$OUT/$name.log" 2>&1; then
        echo "FAIL $1"
        cat "$OUT/$name.log"
        exit 1
    elif grep -q "warning:" "$OUT/$name.log"; then
        echo "FAIL $1 (warnings)"
        cat "$OUT/$name.log"
        exit 1
    else
        echo "PASS $1"
    fi' sh
