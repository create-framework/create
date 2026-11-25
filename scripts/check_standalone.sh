#!/bin/sh
# Builds the smoke test into a binary and runs it outside the pixi
# environment, as a `mojo build` program is run: no CONDA_PREFIX, no pixi
# PATH. It draws text, so it has to find FreeType through `load_library`'s
# fallbacks rather than the environment variable pixi sets. It names the
# compiled library with CREATE_LIBRARY, which nothing else would find.
#
#   pixi run check-standalone
set -eu

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

# Against a precompiled package, as the tests and examples are built.
mojo precompile src/create -o "$out/create.mojoc"
library=$(sh scripts/build_native.sh "$out")
mojo build -I "$out" tests/app/test_smoke.mojo -o "$out/smoke"
# A source checkout has nowhere the program would find the compiled library
# on its own, so it is named; an installed package keeps it in the
# environment's lib directory, on the binary's run path.
env -i HOME="$HOME" PATH=/usr/bin:/bin SDL_VIDEODRIVER=dummy \
    CREATE_LIBRARY="$library" "$out/smoke"
