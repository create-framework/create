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
#
# Skipped when the library was last built from the same source, by the same
# compiler and this script: a hash of all three is kept beside it, in libcreate.so.stamp. The
# library is then touched instead, since a program refuses a library older
# than the source it was compiled from, and a checkout (git switch, say) makes
# the source newer without changing it.
set -eu

out=${1:-build}
case "$(uname)" in
    Darwin) name=libcreate.dylib ;;
    *) name=libcreate.so ;;
esac
library="$out/$name"
mkdir -p "$out"

if command -v sha256sum > /dev/null; then
    hash() { sha256sum | cut -d ' ' -f 1; }
else
    hash() { shasum -a 256 | cut -d ' ' -f 1; }
fi
# Taken apart from the pipe below, so a missing compiler stops the script.
version=$(mojo --version)
stamp=$({
    echo "$version"
    cat "$0"
    find src/create src/native -name '*.mojo' | LC_ALL=C sort | while read -r f; do
        echo "$f"
        cat "$f"
    done
} | hash)

if [ -f "$library" ] && [ "$(cat "$library.stamp" 2> /dev/null)" = "$stamp" ]; then
    touch "$library"
else
    # Debug line tables, so a crash inside the library shows the file and
    # line: its machine code is the same as without them (full debug info
    # changes it, so it isn't used), for about 6 MB more.
    mojo build --emit shared-lib -D CREATE_LIBRARY_BUILD \
        --debug-level=line-tables -I src \
        src/native/libcreate.mojo -o "$library"
    echo "$stamp" > "$library.stamp"
fi
echo "$library"
