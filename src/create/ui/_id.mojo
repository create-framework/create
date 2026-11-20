"""Internal: widget IDs, from the place a widget is called and a key."""

from std.reflection import SourceLocation


@always_inline
def _mix(seed: UInt64, value: UInt64) -> UInt64:
    """`value` folded into `seed`, so that the order of the values counts."""
    return seed ^ (value + 0x9E3779B97F4A7C15 + (seed << 6) + (seed >> 2))


def _site(parent: UInt64, location: SourceLocation) -> UInt64:
    """The ID of a call site: its file, line and column, inside `parent`, the
    key of the enclosing `ui.id` block (0 outside one)."""
    var site = _mix(parent, hash(location.file_name()))
    site = _mix(site, UInt64(location.line()))
    return _mix(site, UInt64(location.column()))
