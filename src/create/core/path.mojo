from create._path import _caller_relative


@always_inline
def source_path(relative: String) -> String:
    """`relative`, resolved against the directory of the calling source file;
    an absolute path is returned as it is.

    Create's own loaders and savers already resolve a relative path this way
    (`Image.load("assets/image.png")`), so this is for paths handed to
    anything else: the standard library's `open()`, `listdir`, `makedirs`.
    Called from a helper, it resolves against the helper's file — the same
    rule as Python's `__file__`.

    The caller's path is baked in at compile time, which is why this has to be
    inlined: `call_location` reports the site it is inlined into. So `mojo run`
    and `mojo build` agree on the answer, and since the compiler makes the
    path absolute, a built binary finds its files from any directory, as long
    as they stay where they were at build time.
    """
    return _caller_relative(relative)
