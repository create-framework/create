"""Byte decoding shared by the file and FFI readers: little-endian integers,
C strings and base64.

A leaf module: it imports nothing and nothing re-exports it. Both the image
decoders in `image` and the freetype struct readers in `render` need to
assemble bytes into an `Int`, and neither may depend on the other, so the one
copy of that loop lives here.

Deliberately absent from every `__init__.mojo` — this is internal, not part of
the public surface.
"""


def le_uint[o: Origin](p: Pointer[UInt8, o], off: Int, count: Int) -> Int:
    """Read `count` little-endian bytes at `off` as an unsigned integer.

    Takes a bare pixel-style pointer rather than a buffer type, for the same
    reason `raster` does: the caller may hold a `List`, an `Array`, or
    memory copied out of a C struct, and none of that matters here.
    """
    var v = 0
    for i in range(count):
        v |= Int(p[unsafe_offset=off + i]) << (i * 8)
    return v


def sign_extend_32(v: Int) -> Int:
    """Reinterpret a 32-bit unsigned value as signed two's complement."""
    return v - 0x100000000 if v >= 0x80000000 else v


def cstr(s: String) -> List[UInt8]:
    """A NUL-terminated byte buffer for `s`, for passing to C.

    `String.unsafe_ptr()` is not guaranteed NUL-terminated at `len(s)`, so a C
    API that scans for the terminator can read past the buffer into whatever
    follows it. Building the terminator explicitly sidesteps that.

    Here rather than beside any one FFI wrapper because `audio`, `render` and
    `image` all hand paths to C libraries and none of them may depend on the
    others.
    """
    var bytes = List[UInt8]()
    for b in s.as_bytes():
        bytes.append(b)
    bytes.append(0)
    return bytes^


def decode_base64(text: StringSlice) -> List[UInt8]:
    """The bytes `text` encodes in standard base64, padded to a whole number
    of four-character groups, with no line breaks: how the library carries
    the files it is compiled with (the packaged fonts).

    Not validated, since its only input is the library's own: a character
    outside the alphabet decodes as zero bits. Writes through raw pointers,
    since appending byte by byte costs five times as long, and the packaged
    fonts are four megabytes.
    """
    var table = Array[UInt8, 256](fill=0)
    var alphabet = (
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    ).as_bytes()
    for i in range(64):
        table[Int(alphabet[i])] = UInt8(i)
    var source = text.as_bytes()
    var length = len(source)
    var padding = 0
    if length >= 1 and source[length - 1] == UInt8(ord("=")):
        padding += 1
    if length >= 2 and source[length - 2] == UInt8(ord("=")):
        padding += 1
    var bytes = List[UInt8](length=length // 4 * 3, fill=0)
    var input = source.unsafe_ptr()
    var output = bytes.unsafe_ptr()
    var o = 0
    for i in range(0, length - length % 4, 4):
        var group = (
            (UInt32(table.unsafe_get(Int(input[unsafe_offset=i]))) << 18)
            | (UInt32(table.unsafe_get(Int(input[unsafe_offset=i + 1]))) << 12)
            | (UInt32(table.unsafe_get(Int(input[unsafe_offset=i + 2]))) << 6)
            | UInt32(table.unsafe_get(Int(input[unsafe_offset=i + 3])))
        )
        output[unsafe_offset=o] = UInt8(group >> 16)
        output[unsafe_offset=o + 1] = UInt8((group >> 8) & 0xFF)
        output[unsafe_offset=o + 2] = UInt8(group & 0xFF)
        o += 3
    bytes.resize(len(bytes) - padding, 0)
    return bytes^
