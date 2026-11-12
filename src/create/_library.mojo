"""Shared libraries by platform-neutral name.

A leaf module: it imports nothing from `create` and nothing re-exports it.
Every FFI binding (`image`, `text`, `render`, `audio`, `_window`) opens its
library through `load_library`, so the platform's file naming and search
rules are decided in one place.

A library is named by its stem and the version in its soname, `libpng16`
and 16, and the platform spells the file: `libpng16.so.16` on Linux,
`libpng16.16.dylib` on macOS. That is the name a program linked against the
library would ask for, so it pins the ABI the bindings were written for, and
it is what the runtime package installs. The unversioned `libpng16.so` is a
development symlink, missing from a system without the `-devel` packages.

Where the library is found differs by platform. On Linux an executable's
run path covers `dlopen` as well: `mojo`'s (`$ORIGIN/../lib`) and a `mojo
build` binary's (the environment's `lib`, absolute) both find the pixi
environment's copy from a bare name. macOS applies an executable's
`LC_RPATH` only to `@rpath/` names, so a bare name searches just the default
fallback directories and misses the environment. So:

1. The environment's `lib` directory, from `CONDA_PREFIX` (set by `pixi run`
   and `pixi shell`), on every platform.
2. On macOS, `@rpath/` and the name: a built binary run outside the
   environment, through the run path `mojo build` gave it.
3. The bare name, left to the platform's own search.
"""

from std.ffi import _DLHandle
from std.os import getenv
from std.os.path import exists
from std.sys.info import CompilationTarget


def load_library(stem: String, version: Int) raises -> _DLHandle:
    """Open the shared library `stem` at soname `version` (`libSDL3` 0,
    `libfreetype` 6, ...).

    Refcounted by the platform loader, so opening one already open is cheap
    and returns the same library.
    """
    var name: String
    comptime if CompilationTarget.is_macos():
        name = String(stem, ".", version, ".dylib")
    else:
        name = String(stem, ".so.", version)
    var prefix = getenv("CONDA_PREFIX")
    if prefix:
        var path = prefix + "/lib/" + name
        if exists(path):
            return _DLHandle(path)
    comptime if CompilationTarget.is_macos():
        try:
            return _DLHandle("@rpath/" + name)
        except:
            pass
    return _DLHandle(name)
