"""Internal leaf: resolving a path a program passes against its source file."""

from std.reflection import call_location


@always_inline
def _caller_relative(path: String) -> String:
    """`path` resolved against the directory of the source file that called
    the function calling this one; an absolute path is returned as it is.

    Every public function taking a file path resolves it with this, called
    directly from its own `@always_inline` body: `call_location` sees two
    inlined calls up, past this function and the public one, to the program's
    call. So `Image.load("assets/hero.png")` called in `game/main.mojo` opens
    `game/assets/hero.png`, wherever the program is run from, and a path the
    library passes on is already absolute and not resolved twice.

    The compiler bakes the caller's path in as an absolute path, so `mojo run`
    and `mojo build` agree, and a built binary finds its files from any
    directory while they stay where they were at build time.
    """
    if path.startswith("/"):
        return path
    var file = String(call_location[inline_count=2]().file_name())
    return String(file[byte = : file.rfind("/") + 1]) + path
