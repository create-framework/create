#!/bin/sh
# Builds the compiled library, libcreate (src/native/libcreate.mojo), into the
# directory given, build/ by default, and prints its path.
#
#   pixi run native                  -> build/libcreate.so (.dylib on macOS)
#   sh scripts/build_native.sh DIR   -> DIR/libcreate.so
#
# A program built against a precompiled `create` package calls into this
# library for the run loops, the window, both replays, text layout and the
# captures, so the two must be built from the same source; see
# src/create/_native.mojo. CREATE_LIBRARY_BUILD tells the source it is being
# built as the library, so its call sites call the machinery directly.
set -eu

out=${1:-build}
case "$(uname)" in
    Darwin) name=libcreate.dylib ;;
    *) name=libcreate.so ;;
esac
mkdir -p "$out"
mojo build --emit shared-lib -D CREATE_LIBRARY_BUILD -I src \
    src/native/libcreate.mojo -o "$out/$name"
echo "$out/$name"
