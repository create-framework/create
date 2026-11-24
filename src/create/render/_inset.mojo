"""Inset shadows cut from masks: every kind but rectangles and circles.

A rectangle's or a circle's inset shadow is evaluated per pixel from its
equations (`InsetRegion`, `_cpu_replay._inset_shadow`, `emit_inset_shadow`).
Every other kind's interior has no such formula: a triangle's rounded
corners blur through no closed form. So its shadow is built here, on the
CPU, as an alpha mask in device pixels, which both replays composite in the
shadow colour: the CPU with `blit_alpha`, the GPU as one texture drawn for
the frame (`GLRenderer._mask_shadow`).

The mask is the **interior** times what the **silhouette** leaves
uncovered. The interior is what the shadow is clipped to, under the
command's own matrix: a region's fill inside its stroke. The silhouette is
the interior under the shadow transform, shrunk by the spread and blurred.
Both are rasterised from the same pieces the shape is drawn with, so the
shadow's edge lies on the fill's. A mask has no stable id to key a cache by,
so each one costs a rasterisation and a blur per frame, as a blurred
Bézier's shadow does.
"""

from std.math import max

from create.math.transform import Transform

from ._blur import BlurredMask, PlacedMask
from ._command import RenderCommand, SectorPayload, TrianglePayload
from ._pieces import Pieces, pieces_mask
from ._sector import sector_quads
from ._shadow import _inradius, _spread
from ._transform import pixel_scale
from ._triangle import triangle_pieces


def inset_shadow_mask(
    c: RenderCommand, m: Transform, sm: Transform, scale: Float64, grid: Int
) -> PlacedMask:
    """`c`'s inset shadow as a mask to composite in its shadow colour: `c`
    casts one (`casts_inset_shadow`) but not analytically
    (`insets_analytically`), `m` is its device matrix and `sm` its shadow
    transform's (`shadow_transform`, under the same pre-matrix). `scale` is
    the fallback pixel scale for a transform that is not uniform, and
    `grid` the antialiasing's samples along each axis of a pixel
    (`Antialiasing._cpu_grid`), so the mask's edge is as smooth as the
    shape's."""
    var blur = Int(c.paint.shadow_blur * pixel_scale(sm, scale) + 0.5)
    var interior = pieces_mask(_interior(c, m, scale), grid)
    var silhouette = PlacedMask.empty()
    var shrunk = _shrunk(c, c.paint.shadow_spread)
    if shrunk:
        silhouette = pieces_mask(
            _interior(shrunk.value(), sm, scale), grid
        ).blurred(blur)
    return _uncovered(interior, silhouette)


def _interior(c: RenderCommand, m: Transform, scale: Float64) -> Pieces:
    """The region `c`'s fill inside its stroke, mapped by `m`, whether or not
    the fill is visible: the shadow is inside the shape, not on it."""
    # Tiled with the fill hidden, so a stroke too wide to leave any fill
    # leaves no interior, rather than filling the shape with its colour.
    var hidden = c.copy()
    hidden.paint.fill_enabled = False
    var out: Pieces
    if c.payload.isa[SectorPayload]():
        out = sector_quads(hidden, m, scale)
    else:
        out = triangle_pieces(hidden, m, scale)
    out.clear_stroke()
    return out^


def _shrunk(c: RenderCommand, d: Float64) -> Optional[RenderCommand]:
    """The region `c` with every edge moved in by `d` local units, out for a
    negative `d`, and its corners' radius less by as much: the reverse of an
    outer shadow's spread. `None` once nothing is left of it."""
    if c.payload.isa[TrianglePayload]():
        # Shrunk past its inradius, a triangle would turn inside out.
        if d >= _inradius(c.payload[TrianglePayload].corners):
            return None
    var out = c.copy()
    _spread(out, -d, grow_triangle=True)
    return out^


def _uncovered(interior: PlacedMask, silhouette: PlacedMask) -> PlacedMask:
    """`interior` wherever `silhouette` doesn't cover it, over the interior's
    pixels: each one's alpha times what the silhouette's leaves of it."""
    ref a = interior.mask
    ref s = silhouette.mask
    var out = List[UInt8](length=a.width * a.height, fill=0)
    var dx = interior.x - silhouette.x
    var dy = interior.y - silhouette.y
    for y in range(a.height):
        var sy = y + dy
        var row_inside = sy >= 0 and sy < s.height
        for x in range(a.width):
            var i = y * a.width + x
            var alpha = Int(a.pixels[i])
            if alpha == 0:
                continue
            var sx = x + dx
            var covered = 0
            if row_inside and sx >= 0 and sx < s.width:
                covered = Int(s.pixels[sy * s.width + sx])
            out[i] = UInt8((alpha * (255 - covered) + 127) // 255)
    return PlacedMask(
        BlurredMask(out^, a.width, a.height, 0), interior.x, interior.y
    )
