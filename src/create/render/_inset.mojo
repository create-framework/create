"""Inset shadows cut from masks: every kind but rectangles and circles.

A rectangle's or a circle's inset shadow is evaluated per pixel from its
equations (`InsetRegion`, `_cpu_replay._inset_shadow`, `emit_inset_shadow`).
Every other kind's interior has no such formula: a triangle's rounded
corners blur through no closed form, and a sector, a polygon or a stroke
along a curve has none to start from. So its shadow is built here, on the
CPU, as an alpha mask in device pixels, which both replays composite in the
shadow colour: the CPU with `blit_alpha`, the GPU as one texture drawn for
the frame (`GLRenderer._mask_shadow`).

The mask is the **interior** times what the **silhouette** leaves
uncovered. The interior is what the shadow is clipped to, under the
command's own matrix: a region's fill inside its stroke, or a line's or a
curve's stroke, which is all the inside it has. The silhouette is
the interior under the shadow transform, shrunk by the spread and blurred.
Both are rasterised from the same pieces the shape is drawn with, so the
shadow's edge lies on the fill's. A mask has no stable id to key a cache by,
so each one costs a rasterisation and a blur per frame, as a blurred
Bézier's shadow does.
"""

from std.math import max, min

from create.color.color import Color

from create.math.transform import Transform

from ._blur import BlurredMask, PlacedMask
from ._command import (
    ImagePayload,
    PolygonPayload,
    RenderCommand,
    SectorPayload,
    TextPayload,
    TrianglePayload,
)
from ._image_mapping import mask_mapping
from ._lower import shape_pieces
from ._pieces import Pieces, pieces_mask
from ._polygon import polygon_quads
from ._sector import sector_quads
from ._raster import blit_alpha, blit_alpha_mapped
from ._interned_image import _InternedImage
from ._shadow import _inradius, _spread, image_mask
from ._surface import MemorySurface
from ._text import PlacedGlyph, TextRenderer
from ._transform import (
    glyph_transform,
    pixel_scale,
    text_pixel_scale,
    text_upright,
)
from ._triangle import triangle_pieces


def inset_shadow_mask(
    c: RenderCommand,
    m: Transform,
    sm: Transform,
    scale: Float64,
    grid: Int,
    mut text: TextRenderer,
    images: Dict[Int, _InternedImage],
) raises -> PlacedMask:
    """`c`'s inset shadow as a mask to composite in its shadow colour: `c`
    casts one (`casts_inset_shadow`) but not analytically
    (`insets_analytically`), `m` is its device matrix and `sm` its shadow
    transform's (`shadow_transform`, under the same pre-matrix). `scale` is
    the fallback pixel scale for a transform that is not uniform, and
    `grid` the antialiasing's samples along each axis of a pixel
    (`Antialiasing._cpu_grid`), so the mask's edge is as smooth as the
    shape's. `text` lays out and rasterises a text command's glyphs, and
    `images` holds an image command's pixels."""
    if c.payload.isa[TextPayload]():
        # Blurred where it is laid out, at its own scale, as a text drop
        # shadow is; its glyphs are already antialiased.
        var blur = Int(c.paint.shadow_blur * text_pixel_scale(sm, scale) + 0.5)
        return _uncovered(
            _text_mask(text, c, m, scale, 0),
            _text_mask(text, c, sm, scale, blur),
        )
    var blur = Int(c.paint.shadow_blur * pixel_scale(sm, scale) + 0.5)
    if c.payload.isa[ImagePayload]():
        # An image has no spread to shrink it by, as for its drop shadow.
        ref image = c.payload[ImagePayload]
        if image.image not in images:
            return PlacedMask.empty()
        var src = images[image.image].pixels[].unsafe_ptr()
        return _uncovered(
            image_mask(c, m, src, grid),
            image_mask(c, sm, src, grid).blurred(blur),
        )
    var interior = pieces_mask(_interior(c, m, scale), grid)
    var silhouette = PlacedMask.empty()
    var shrunk = _shrunk(c, c.paint.shadow_spread)
    if shrunk:
        silhouette = pieces_mask(
            _interior(shrunk.value(), sm, scale), grid
        ).blurred(blur)
    return _uncovered(interior, silhouette)


def _interior(c: RenderCommand, m: Transform, scale: Float64) -> Pieces:
    """What `c`'s inset shadow is clipped to, mapped by `m`: a region's fill
    inside its stroke, whether or not the fill is visible, since the shadow
    is inside the shape, not on it; a line's or a curve's stroke."""
    if not c.is_region():
        return shape_pieces(c, m, scale)
    # Tiled with the fill hidden, so a stroke too wide to leave any fill
    # leaves no interior, rather than filling the shape with its colour.
    var hidden = c.copy()
    hidden.paint.fill_enabled = False
    var out: Pieces
    if c.payload.isa[SectorPayload]():
        out = sector_quads(hidden, m, scale)
    elif c.payload.isa[PolygonPayload]():
        out = polygon_quads(hidden, m, scale)
    else:
        out = triangle_pieces(hidden, m, scale)
    out.clear_stroke()
    return out^


def _shrunk(c: RenderCommand, d: Float64) -> Optional[RenderCommand]:
    """`c` with every edge of its interior moved in by `d` local units, out
    for a negative `d`: the reverse of an outer shadow's spread. A region's
    corners' radius drops by as much, and a line's or a curve's stroke
    thins by `d` either side, its round and square caps with it; a butt
    end stays where it is. `None` once nothing is left of it."""
    if not c.is_region():
        var thickness = c.paint.stroke_thickness - 2.0 * d
        if thickness <= 0.0:
            return None
        var out = c.copy()
        out.paint.stroke_thickness = thickness
        return out^
    if c.payload.isa[TrianglePayload]():
        # Shrunk past its inradius, a triangle would turn inside out.
        if d >= _inradius(c.payload[TrianglePayload].corners):
            return None
    var out = c.copy()
    _spread(out, -d, grow_triangle=True)
    return out^


def _text_mask(
    mut text: TextRenderer,
    c: RenderCommand,
    m: Transform,
    scale: Float64,
    blur: Int,
) raises -> PlacedMask:
    """The text command `c`'s glyphs, blurred by `blur` device pixels,
    composited into one alpha mask where `m` places them: laid out and
    blitted as `CpuReplay._text` draws them, so the mask covers what the
    text paints."""
    ref payload = c.payload[TextPayload]
    var sf = text_pixel_scale(m, scale)
    var wrap = payload.wrap_pixels(sf)
    var upright = text_upright(m)
    var glyphs: List[PlacedGlyph]
    var mapped = Transform()
    if upright:
        var p = m._apply_xy(payload.position.x, payload.position.y)
        glyphs = text.layout(
            payload.text, p[0], p[1], payload.style[], sf, blur, wrap
        )
    else:
        mapped = glyph_transform(m, payload.position.x, payload.position.y, sf)
        glyphs = text.layout(
            payload.text, 0.0, 0.0, payload.style[], sf, blur, wrap
        )
    var x0 = Int.MAX
    var y0 = Int.MAX
    var x1 = Int.MIN
    var y1 = Int.MIN
    for ref g in glyphs:
        if upright:
            x0 = min(x0, g.x)
            y0 = min(y0, g.y)
            x1 = max(x1, g.x + g.width)
            y1 = max(y1, g.y + g.height)
        else:
            var at = mask_mapping(mapped, g.x, g.y, g.width, g.height)
            if at.x1 > at.x0 and at.y1 > at.y0:
                x0 = min(x0, at.x0)
                y0 = min(y0, at.y0)
                x1 = max(x1, at.x1)
                y1 = max(y1, at.y1)
    if x1 <= x0 or y1 <= y0:
        return PlacedMask.empty()
    var scratch = MemorySurface(x1 - x0, y1 - y0)
    var s = scratch.surface()
    for ref g in glyphs:
        ref pixels = text.glyph_mask(g.key)
        if upright:
            blit_alpha(
                s,
                pixels.unsafe_ptr(),
                g.width,
                g.height,
                g.x - x0,
                g.y - y0,
                Color.WHITE,
            )
        else:
            blit_alpha_mapped(
                s,
                pixels.unsafe_ptr(),
                g.width,
                g.height,
                mask_mapping(mapped, g.x, g.y, g.width, g.height).translated(
                    -x0, -y0
                ),
                Color.WHITE,
            )
    return PlacedMask(BlurredMask(scratch.alpha(), x1 - x0, y1 - y0, 0), x0, y0)


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
