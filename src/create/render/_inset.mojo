"""Inset shadows, built on the CPU for both replays.

An inset shadow lies over its command, inside it: the shadow colour wherever
the **silhouette** (the interior moved by the shadow's offset, shrunk by its
spread and blurred) leaves the **interior** uncovered. The interior is a
region's fill inside its stroke, a line's or a curve's stroke, text's letters
or an image's opaque pixels.

**The shadow composites with its command, not after it.** An antialiased
edge pixel is covered only partly by the interior. Painting the shadow over
the finished pixel at that share would leave the command's own colour
showing through the shadow there, as a fringe. So the shadow is mixed into
what the command paints, and composited in the same pass:

- A region or a curve is drawn with the shadow mixed into its paint, pixel
  by pixel (`FillPaint`'s inset): its fill, or a curve's stroke. What it
  needs is how much of each pixel the silhouette leaves uncovered,
  `inset_uncovered`. On the GPU, a rectangle or a circle is evaluated
  analytically instead (`emit_inset_shadow`), and every other region or
  curve draws its interior again, over itself, through that same mask as a
  texture (`interior_pieces`); multisampling then covers each sample once,
  as the CPU's mixing does.
- Text and images are drawn off the device with their shadow mixed in
  (`inset_layer`), and both replays composite those pixels in place of the
  command.

A rectangle's or a circle's silhouette is evaluated from its equations
(`InsetRegion`, `BlurredSilhouette`); every other one is rasterised from the
same pieces the shape is drawn with and blurred. A mask has no stable id to
key a cache by, so each one costs a rasterisation, and a blur when soft, per
frame, as a blurred Bézier's shadow does.
"""

from std.math import floor, max, min

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
from ._interned_image import _InternedImage
from ._lower import shape_pieces
from ._pieces import Pieces, pieces_bounds, pieces_mask
from ._polygon import polygon_quads
from ._raster import blit_alpha, blit_alpha_mapped
from ._sector import sector_quads
from ._shadow import (
    BlurredSilhouette,
    _inradius,
    _spread,
    image_layer,
    image_mask,
    inset_interior,
    insets_analytically,
    local_stroke_thickness,
)
from ._surface import MemorySurface, PlacedSurface
from ._text import PlacedGlyph, TextRenderer
from ._transform import (
    glyph_transform,
    pixel_scale,
    text_pixel_scale,
    text_upright,
)
from ._triangle import triangle_pieces


def inset_uncovered(
    c: RenderCommand, m: Transform, sm: Transform, scale: Float64, grid: Int
) -> Optional[PlacedMask]:
    """How much of each pixel of the region or curve `c`'s interior its
    silhouette leaves uncovered, 255 for all of it, over the device pixels
    the interior lies in: where its inset shadow shows, and how strongly.
    `None` when `c` has no interior, and so casts no inset shadow.

    `m` is `c`'s device matrix and `sm` its shadow transform's
    (`shadow_transform`, under the same pre-matrix). `scale` is the fallback
    pixel scale for a transform that is not uniform, and `grid` the
    antialiasing's samples along each axis of a pixel
    (`Antialiasing._cpu_grid`), so a rasterised silhouette's edge is as
    smooth as the shape's.
    """
    var blur = Int(c.paint.shadow_blur * pixel_scale(sm, scale) + 0.5)
    if insets_analytically(c):
        return _analytic_uncovered(c, m, sm, scale, blur)
    var box = pieces_bounds(interior_pieces(c, m, scale))
    if not box:
        return None
    var silhouette = PlacedMask.empty()
    var shrunk = _shrunk(c, c.paint.shadow_spread)
    if shrunk:
        silhouette = pieces_mask(
            interior_pieces(shrunk.value(), sm, scale), grid
        ).blurred(blur)
    var x0, y0, width, height = box.value()
    var out = List[UInt8](length=width * height, fill=255)
    ref s = silhouette.mask
    for y in range(height):
        var sy = y0 + y - silhouette.y
        if sy < 0 or sy >= s.height:
            continue
        for x in range(width):
            var sx = x0 + x - silhouette.x
            if sx >= 0 and sx < s.width:
                out[y * width + x] = 255 - s.pixels[sy * s.width + sx]
    return PlacedMask(BlurredMask(out^, width, height, 0), x0, y0)


def _analytic_uncovered(
    c: RenderCommand, m: Transform, sm: Transform, scale: Float64, blur: Int
) -> Optional[PlacedMask]:
    """`inset_uncovered` for a rectangle or a circle, its silhouette
    evaluated at each pixel's centre: blurred by the style's blur, or cut
    hard when the blur comes to no whole device pixel."""
    var interior = inset_interior(c, local_stroke_thickness(c, m, scale))
    if interior.empty:
        return None
    var cut = interior.shrunk(c.paint.shadow_spread)
    var soft = BlurredSilhouette(cut, c.paint.shadow_blur)
    var lb = interior.bounds()
    var x0 = Int.MAX
    var y0 = Int.MAX
    var x1 = Int.MIN
    var y1 = Int.MIN
    for corner in range(4):
        var p = m._apply_xy(
            lb[2] if corner == 1 or corner == 2 else lb[0],
            lb[3] if corner >= 2 else lb[1],
        )
        x0 = min(x0, Int(floor(p[0])))
        y0 = min(y0, Int(floor(p[1])))
        x1 = max(x1, Int(floor(p[0])) + 2)
        y1 = max(y1, Int(floor(p[1])) + 2)
    var width = x1 - x0
    var height = y1 - y0
    var sminv = sm.inverse()
    var out = List[UInt8](length=width * height, fill=255)
    for y in range(height):
        for x in range(width):
            var l = sminv._apply_xy(
                Float64(x0 + x) + 0.5, Float64(y0 + y) + 0.5
            )
            var covered: Float64
            if blur > 0:
                covered = soft.coverage(l[0], l[1])
            else:
                covered = 1.0 if cut.contains(l[0], l[1]) else 0.0
            out[y * width + x] = UInt8(Int(255.0 * (1.0 - covered) + 0.5))
    return PlacedMask(BlurredMask(out^, width, height, 0), x0, y0)


def interior_pieces(c: RenderCommand, m: Transform, scale: Float64) -> Pieces:
    """What the region or curve `c`'s inset shadow is clipped to, mapped by
    `m`: a region's fill inside its stroke, whether or not the fill is
    visible, since the shadow is inside the shape, not on it; a line's or a
    curve's stroke. A rectangle's or a circle's is its `InsetRegion`
    instead."""
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


def inset_layer(
    c: RenderCommand,
    m: Transform,
    sm: Transform,
    scale: Float64,
    grid: Int,
    mut text: TextRenderer,
    images: Dict[Int, _InternedImage],
) raises -> PlacedSurface:
    """The text or image command `c` drawn on its own with its inset shadow
    mixed in, to composite in its place: `m`, `sm`, `scale` and `grid` as
    for `inset_uncovered`. `text` lays out a text command's glyphs, and
    `images` holds an image command's pixels. Neither has a spread to
    shrink it by, as for its drop shadow."""
    if c.payload.isa[TextPayload]():
        # Blurred where it is laid out, at its own scale, as a text drop
        # shadow is; its glyphs are already antialiased.
        var blur = Int(c.paint.shadow_blur * text_pixel_scale(sm, scale) + 0.5)
        var ink = c.payload[TextPayload].style[].text_color
        return _shadowed(
            _text_layer(text, c, m, scale, 0, ink),
            _text_layer(text, c, m, scale, 0, Color.WHITE).mask(),
            _text_layer(text, c, sm, scale, blur, Color.WHITE).mask(),
            c.paint.shadow_color,
        )
    ref image = c.payload[ImagePayload]
    if image.image not in images:
        return PlacedSurface.empty()
    var blur = Int(c.paint.shadow_blur * pixel_scale(sm, scale) + 0.5)
    var src = images[image.image].pixels[].unsafe_ptr()
    return _shadowed(
        image_layer(c, m, src, grid),
        image_mask(c, m, src, grid),
        image_mask(c, sm, src, grid).blurred(blur),
        c.paint.shadow_color,
    )


def _text_layer(
    mut text: TextRenderer,
    c: RenderCommand,
    m: Transform,
    scale: Float64,
    blur: Int,
    color: Color,
) raises -> PlacedSurface:
    """The text command `c`'s glyphs, blurred by `blur` device pixels, in
    `color` on transparent pixels where `m` places them: laid out and
    blitted as `CpuReplay._text` draws them."""
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
        return PlacedSurface.empty()
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
                color,
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
                color,
            )
    return PlacedSurface(scratch^, x0, y0)


def _shadowed(
    var ink: PlacedSurface,
    interior: PlacedMask,
    silhouette: PlacedMask,
    shadow: Color,
) -> PlacedSurface:
    """`ink`, a command drawn on its own, with its inset shadow mixed in:
    the `shadow` colour over each pixel's `interior` share, by as much as
    `silhouette` leaves uncovered. `interior` lies on `ink`'s pixels.

    In premultiplied terms the interior's share `c` of a pixel turns from
    the ink's colour into the shadow over it, so with the shadow's alpha
    `a` there, the pixel `L` becomes `L (1 - a) + c a S`: exactly what
    drawing the command and then its shadow, sample by sample, leaves."""
    ref data = ink.pixels.data
    ref s = silhouette.mask
    var width = ink.pixels.width
    var dx = ink.x - silhouette.x
    var dy = ink.y - silhouette.y
    var sigma = Float64(shadow.a) / 255.0
    for i in range(width * ink.pixels.height):
        var inside = Float64(interior.mask.pixels[i]) / 255.0
        if inside <= 0.0:
            continue
        var sx = i % width + dx
        var sy = i // width + dy
        var covered = 0.0
        if sx >= 0 and sy >= 0 and sx < s.width and sy < s.height:
            covered = Float64(s.pixels[sy * s.width + sx]) / 255.0
        var a = sigma * (1.0 - covered)
        if a <= 0.0:
            continue
        var alpha = Float64(data[i * 4 + 3]) / 255.0
        var total = alpha * (1.0 - a) + inside * a
        if total <= 0.0:
            continue
        for ch in range(3):
            var shadow_ch = Float64(
                shadow.r if ch == 0 else (shadow.g if ch == 1 else shadow.b)
            )
            var mixed = (
                Float64(data[i * 4 + ch]) * alpha * (1.0 - a)
                + shadow_ch * inside * a
            ) / total
            data[i * 4 + ch] = UInt8(min(Int(mixed + 0.5), 255))
        data[i * 4 + 3] = UInt8(min(Int(total * 255.0 + 0.5), 255))
    return ink^
