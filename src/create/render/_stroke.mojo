"""Stroke alignment: a region's stroke moved out from its edge.

Every region kind draws its stroke as an inset ring, inside the shape's
edge. `CENTER` and `OUTSIDE` reuse that: the shape is grown by how far the
stroke moves out (`stroke_offset`), and the inset ring of the grown shape is
the aligned stroke, its fill the grown shape eroded by the thickness. Both
replays align a command once, before its shadows and the shape itself
(`Backend._one`, `GLRenderer._command`), so the shape, its hard, blurred and
inset shadows, pixel reads and captures all see the same geometry, and no
rasteriser knows about alignment.
"""

from create.math.matrix import Matrix

from ._command import (
    CMD_CIRCLE,
    CMD_POLYGON,
    CMD_RECT,
    CMD_SECTOR,
    RenderCommand,
)
from ._shadow import local_stroke_thickness
from .stroke_align import StrokeAlign


def stroke_offset(c: RenderCommand, m: Matrix[3, 3], scale: Float64) -> Float64:
    """How far `c`'s stroke moves out past its edge, in local units: 0 when
    nothing is to align — `INSIDE`, no visible stroke, or a kind without an
    inside. A fraction of the stroke as the rasterisers draw it under the
    device matrix `m`, whole pixels, so `OUTSIDE` puts its inner edge on
    the shape's exactly."""
    if not (
        c.kind == CMD_RECT
        or c.kind == CMD_CIRCLE
        or c.kind == CMD_SECTOR
        or c.kind == CMD_POLYGON
    ):
        return 0.0
    var fraction = c.style.stroke_alignment._offset_fraction()
    if fraction == 0.0 or not c.style._stroke_visible():
        return 0.0
    return fraction * local_stroke_thickness(c, m, scale)


def aligned_stroke(c: RenderCommand, offset: Float64) -> RenderCommand:
    """`c` grown by `offset` (from `stroke_offset`), so its inset stroke
    is the aligned one, and marked `INSIDE` so nothing grows it twice.

    A rounded rectangle's radius grows with it, so the stroke's outer edge
    stays parallel to the shape's; a sharp one stays sharp, as a mitred
    stroke's corner is. `stroke_grow` records the grow, so `_fill_box` keeps
    a gradient where the shape is. A sector and a polygon grow through
    their own slot, which a shadow's spread adds to.
    """
    var a = c.copy()
    a.style.stroke_alignment = StrokeAlign.INSIDE
    a.stroke_grow = offset
    if c.kind == CMD_RECT:
        a.geom[2] += 2.0 * offset
        a.geom[3] += 2.0 * offset
        if c.corner_radius > 0.0:
            a.corner_radius += offset
    elif c.kind == CMD_CIRCLE:
        a.geom[2] += offset
    elif c.kind == CMD_SECTOR:
        a.geom[5] += offset
    elif c.kind == CMD_POLYGON:
        a.geom[0] += offset
    return a^
