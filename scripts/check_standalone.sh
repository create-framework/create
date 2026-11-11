#!/bin/sh
# Builds the smoke test into a binary and runs it outside the pixi
# environment, as a `mojo build` program is run: no CONDA_PREFIX, no pixi
# PATH. It draws text, so it has to find FreeType through `load_library`'s
# fallbacks rather than the environment variable pixi sets.
#
#   pixi run check-standalone
set -eu

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

# Against a precompiled package, as the tests and examples are built. From
# an absolute path, since the package bakes it in for its packaged fonts and
# the binary draws text.
mojo precompile "$(pwd)/src/create" -o "$out/create.mojoc"
mojo build -I "$out" tests/core/test_smoke.mojo -o "$out/smoke"
env -i HOME="$HOME" PATH=/usr/bin:/bin SDL_VIDEODRIVER=dummy "$out/smoke"
