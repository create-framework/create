"""A `RenderCommand`'s shadow, as another `RenderCommand`.

Both replays paint an outer shadow by rendering the command this builds
before the command itself, so what a shadow *is* — where it lands, which
silhouette it takes, how spread grows it — is decided once, here, and the CPU
and GL paths cannot drift on it.

**One layer.** A shadow is a single silhouette in `shadow_color`, never a
fill-shadow plus a stroke-shadow: those overlap along the stroke, and a
translucent shadow colour would darken the overlap twice. With the fill
visible the silhouette is the whole shape out to the stroke's outer edge;
with only the stroke visible it is the ring.

**Growing a shape by `d`** (the stroke's outward extent plus spread) is the
Minkowski sum with a disc of radius `d`: every edge moves out by `d` and every
corner rounds by `d` more, centred on the original vertex. That is exactly
what a larger `corner_radius` on the grown rectangle or triangle renders, so
no new shape kind is needed, and the growth is exact.
A sector or polygon has no corner radius, so it carries the growth itself
(a sector's or a polygon's `grow`) and `sector_quads` or
`polygon_quads` tiles the Minkowski sum exactly.

**Blur** is a Gaussian of standard deviation `sigma = shadow_blur / 2`, as in
CSS, evaluated analytically per pixel rather than by blurring an image: the
coverage functions at the bottom of this file give the blurred silhouette's
alpha at a point from its distances to the silhouette's edges. They are
spelled out again in the GL shader, so keep the two in step.
"""

from std.math import abs, asin, cos, exp, max, min, sin, sqrt

from create.math.matrix import Matrix, translate
from create.math.point2d import Point2D

from ._command import (
    CirclePayload,
    CurvesPayload,
    ImagePayload,
    LinePayload,
    PolygonPayload,
    RectPayload,
    RenderCommand,
    SectorPayload,
    TextPayload,
    TrianglePayload,
    _GEOM_SLOTS,
    _grow_triangle,
)
from create.geometry._fillet import rect_corner_radius, triangle_corner_radius
from create.color.color import Color
from ._blur import BlurredMask, blur_alpha
from ._curve import PlacedMask
from ._image_mapping import image_mapping
from ._raster import blit_image_mapped
from ._surface import MemorySurface
from ._transform import stroke_thickness_px, pixel_scale
from .stroke_align import StrokeAlign
from .stroke_cap import StrokeCap


def casts_outer_shadow(c: RenderCommand) -> Bool:
    """Whether `c` paints an outer shadow before itself.

    Only render calls cast one — never a clear or the letterbox — and only
    when they paint something a silhouette could be taken from.
    """
    if not c.paint._shadow_visible() or c.paint.shadow_inset:
        return False
    if c.is_region():
        return c.paint._fill_visible() or c.paint._stroke_visible()
    if c.payload.isa[LinePayload]():
        ref line = c.payload[LinePayload]
        # A butt line of no length paints nothing, so casts nothing.
        if c.paint.stroke_cap == StrokeCap.BUTT and line.start == line.end:
            return False
        return c.paint._stroke_visible()
    if c.payload.isa[CurvesPayload]():
        return c.paint._stroke_visible()
    if c.payload.isa[TextPayload]():
        return c.payload[TextPayload].style[].text_color.a > 0
    return c.payload.isa[ImagePayload]()


def casts_inset_shadow(c: RenderCommand) -> Bool:
    """Whether `c` paints an inset shadow over itself.

    Only the shapes with an interior take one; a line, a curve, text or an
    image ignores `shadow_inset` and casts nothing. Painted whether or not the
    fill is visible, as in CSS: the shadow is inside the shape, not on it.
    """
    if not c.paint._shadow_visible() or not c.paint.shadow_inset:
        return False
    # A sector or polygon ignores `shadow_inset` too: the inset regions are
    # these three.
    return (
        c.payload.isa[RectPayload]()
        or c.payload.isa[CirclePayload]()
        or c.payload.isa[TrianglePayload]()
    )


def shadow_transform(c: RenderCommand, scale: Float64) -> Matrix[3, 3]:
    """`c.transform` moved by the shadow offset.

    Screen-fixed by default: the offset becomes a device translation composed
    *after* the transform, so a rotating shape keeps its shadow falling the
    same way — only its length follows the pixel scale (autoscale, camera
    zoom). Device rows run downwards, hence `-oy`. With
    `shadow_follows_transform` the offset is local, composed *before* the
    transform, and turns with the shape.
    """
    var o = c.paint.shadow_offset
    if c.paint.shadow_follows_transform:
        return c.transform @ translate(o.x, o.y)
    var sf = pixel_scale(c.transform, scale)
    return translate(o.x * sf, -o.y * sf) @ c.transform


def shadow_command(c: RenderCommand, scale: Float64) -> RenderCommand:
    """The hard silhouette `c` casts, ready to replay before `c`.

    Assumes `casts_outer_shadow(c)`. Blur is carried along in the style for
    the replays that soften it; the geometry here is the unblurred shape.
    Spread is in world units, like the stroke thickness, and widens a
    stroke by twice itself, one spread either side.
    """
    var s = c.copy()
    s.transform = shadow_transform(c, scale)
    s.paint.shadow_enabled = False
    # `c` is already aligned; its silhouette must not move out again.
    s.paint.stroke_alignment = StrokeAlign.INSIDE
    # A shadow is one colour: the fill's gradient stays with the shape.
    s.paint.fill_gradient = None
    var color = c.paint.shadow_color
    var spread = c.paint.shadow_spread

    if c.payload.isa[TextPayload]():
        s.payload[TextPayload].recolor(color)
        return s^
    if c.payload.isa[ImagePayload]():
        s.paint.fill_color = color
        s.payload[ImagePayload].silhouette = True
        return s^

    var ring = (
        not c.paint._fill_visible()
        or c.payload.isa[LinePayload]()
        or c.payload.isa[CurvesPayload]()
    )
    if ring:
        # The stroke alone, dilated by `spread` on both sides.
        s.paint.fill_enabled = False
        s.paint.stroke_color = color
        s.paint.stroke_enabled = True
        s.paint.stroke_thickness = max(
            c.paint.stroke_thickness + 2.0 * spread, 0.0
        )
        # A triangle's ring is its stroke thickened, in place.
        _spread(s, spread, grow_triangle=False)
        return s^

    s.paint.fill_color = color
    s.paint.fill_enabled = True
    s.paint.stroke_enabled = False
    # Every region's stroke is an inset ring (an aligned one of the grown
    # shape), so the fill's edge is already the outer edge.
    _spread(s, spread, grow_triangle=True)
    return s^


def _spread(mut s: RenderCommand, d: Float64, grow_triangle: Bool):
    """Grow the region `s` by `d` local units all round, never below
    nothing. A sector and a polygon are grown exactly when tiled, through
    their `grow`: no corner radius to lean on."""
    if s.payload.isa[RectPayload]():
        ref rect = s.payload[RectPayload]
        rect.w = max(rect.w + 2.0 * d, 0.0)
        rect.h = max(rect.h + 2.0 * d, 0.0)
        rect.corner_radius = max(rect.corner_radius + d, 0.0)
    elif s.payload.isa[CirclePayload]():
        ref circle = s.payload[CirclePayload]
        circle.r = max(circle.r + d, 0.0)
    elif s.payload.isa[TrianglePayload]() and grow_triangle:
        ref triangle = s.payload[TrianglePayload]
        _grow_triangle(triangle.corners, d)
        triangle.corner_radius = max(triangle.corner_radius + d, 0.0)
    elif s.payload.isa[SectorPayload]():
        s.payload[SectorPayload].grow += d
    elif s.payload.isa[PolygonPayload]():
        s.payload[PolygonPayload].grow += d


def image_shadow_mask[
    so: Origin
](
    c: RenderCommand,
    m: Matrix[3, 3],
    src: Pointer[UInt8, so],
    blur: Int,
) -> PlacedMask:
    """The silhouette of the image command `c`, its pixels at `src`, mapped
    by a transform that does not keep it upright, rasterised into an alpha
    mask and blurred by `blur` device pixels.

    An upright image's mask is cached by size (`shadow_mask_key`); this one
    depends on the whole transform, so like a Bézier's it is built afresh
    each frame. The mask is the pixels `blit_image_mapped` covers on the
    device, so a hard and a blurred shadow line up.
    """
    ref image = c.payload[ImagePayload]
    var mapping = image_mapping(
        m,
        image.center.x,
        image.center.y,
        image.w,
        image.h,
        image.image_w,
        image.image_h,
    )
    var width = mapping.x1 - mapping.x0
    var height = mapping.y1 - mapping.y0
    if width <= 0 or height <= 0:
        return PlacedMask(BlurredMask(List[UInt8](), 0, 0, 0), 0, 0)
    var scratch = MemorySurface(width, height)
    blit_image_mapped(
        scratch.surface(),
        src,
        image.image_w,
        image.image_h,
        mapping.translated(-mapping.x0, -mapping.y0),
        Optional(Color.WHITE),
    )
    var alpha = List[UInt8](length=width * height, fill=0)
    for i in range(width * height):
        alpha[i] = scratch.data[i * 4 + 3]
    var mask = blur_alpha(alpha, width, height, Float64(blur) / 2.0)
    var pad = mask.pad
    return PlacedMask(mask^, mapping.x0 - pad, mapping.y0 - pad)


# --- Blur coverage -----------------------------------------------------------
#
# Distances are signed, positive inside the silhouette, and already divided by
# sigma: that is what the GL path interpolates per vertex, and it keeps a zero
# sigma (a hard shadow) out of these functions entirely.


def gaussian_cdf(x: Float64) -> Float64:
    """The standard normal CDF: the share of a unit Gaussian left of `x`.

    Abramowitz and Stegun 7.1.26 for `erf`, good to 1.5e-7 — GLSL has no
    `erf`, so the shader uses the same polynomial and both replays agree.
    """
    # Past four sigma the result rounds to 0 or 1 in any 8-bit channel, and
    # skipping `exp` there makes a blurred shadow's interior nearly free.
    if x >= 4.0:
        return 1.0
    if x <= -4.0:
        return 0.0
    var z = abs(x) / sqrt(2.0)
    var t = 1.0 / (1.0 + 0.3275911 * z)
    var poly = t * (
        0.254829592
        + t
        * (
            -0.284496736
            + t * (1.421413741 + t * (-1.453152027 + t * 1.061405429))
        )
    )
    var erf = 1.0 - poly * exp(-z * z)
    return 0.5 * (1.0 + erf) if x >= 0.0 else 0.5 * (1.0 - erf)


def box_coverage(
    left: Float64, right: Float64, bottom: Float64, top: Float64
) -> Float64:
    """A blurred rectangle's alpha, exactly, from a point's distances to its
    four edges.

    The Gaussian is separable, so the blurred rectangle is the product of
    two blurred slabs, and a slab is the share of the Gaussian between its
    two edges: `cdf(left) + cdf(right) - 1`. Being isotropic, it holds for a
    rotated rectangle measured in its own frame.
    """
    var x = gaussian_cdf(left) + gaussian_cdf(right) - 1.0
    var y = gaussian_cdf(bottom) + gaussian_cdf(top) - 1.0
    return max(x, 0.0) * max(y, 0.0)


def edge_coverage(
    d0: Float64, d1: Float64, d2: Float64, d3: Float64 = 1e9
) -> Float64:
    """A blurred convex polygon's alpha, approximately, from a point's
    distances to up to four edges (a triangle leaves `d3` at its default).

    The product of the blurred half-planes: exact along an edge far from
    the others, slightly heavy where the shape narrows below a few sigma —
    there is no closed form for a blurred triangle. A rectangle has one, so
    it goes through `box_coverage` instead.
    """
    return (
        gaussian_cdf(d0)
        * gaussian_cdf(d1)
        * gaussian_cdf(d2)
        * gaussian_cdf(d3)
    )


def rounded_rect_coverage(
    px: Float64,
    py: Float64,
    half_w: Float64,
    half_h: Float64,
    radius: Float64,
) -> Float64:
    """A blurred rounded rectangle's alpha at `(px, py)` relative to its
    centre; every length already divided by sigma.

    One Gaussian step across the signed distance to the outline — exact
    along the straight edges, a close approximation around a corner. A
    circle is the case `half_w == half_h == radius`.
    """
    var r = min(radius, min(half_w, half_h))
    var qx = abs(px) - (half_w - r)
    var qy = abs(py) - (half_h - r)
    var ox = max(qx, 0.0)
    var oy = max(qy, 0.0)
    var sdf = sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0.0) - r
    return gaussian_cdf(-sdf)


comptime _CAP_NODES: Array[Float64, 4] = [
    0.1834346424956498,
    0.5255324099163290,
    0.7966664774136267,
    0.9602898564975363,
]
"""8-point Gauss-Legendre nodes on [-1, 1], the positive half: each is
used with its negation."""
comptime _CAP_WEIGHTS: Array[Float64, 4] = [
    0.3626837833783620,
    0.3137066458778873,
    0.2223810344533745,
    0.1012285362903763,
]


def _cap_coverage(
    px: Float64, py: Float64, core_half: Float64, radius: Float64
) -> Float64:
    """The blurred half disc capping a capsule's core at `x = core_half`,
    reaching right; every length over sigma.

    Each slice of the cap at height `t` is the interval from `core_half`
    to `core_half + sqrt(radius² - t²)`, blurred along `x` exactly, then
    weighted by the Gaussian across: an integral over `t`, taken in
    `t = radius · sin(θ)`, which removes the square root's kink at the
    cap's rim. Only the stretch within `BLUR_REACH` of `py` carries any
    weight, so the nodes go there, and stay dense however thick the cap.
    """
    var base = gaussian_cdf(core_half - px)
    if base >= 1.0:
        return 0.0  # Too far inside the core for the cap to add anything.
    var lo = max((py - BLUR_REACH) / radius, -1.0)
    var hi = min((py + BLUR_REACH) / radius, 1.0)
    if lo >= hi:
        return 0.0
    var a0 = asin(lo)
    var a1 = asin(hi)
    # Two panels: one alone leaves a full-width Gaussian ~1e-3 short.
    var half = (a1 - a0) / 4.0
    var sum = 0.0
    for panel in range(2):
        var mid = a0 + half * Float64(2 * panel + 1)
        comptime for i in range(4):
            comptime node = _CAP_NODES[i]
            comptime weight = _CAP_WEIGHTS[i]
            for sign in range(2):
                var a = mid + (half if sign == 0 else -half) * node
                var t = radius * sin(a)
                var w = radius * cos(a)
                var u = t - py
                var across = exp(-0.5 * u * u) * _INV_SQRT_TAU
                var along = gaussian_cdf(core_half + w - px) - base
                sum += weight * across * along * w
    return sum * half


comptime _INV_SQRT_TAU = 0.3989422804014327
"""1 / sqrt(2π): the unit Gaussian's peak."""


def capsule_coverage(
    px: Float64, py: Float64, core_half: Float64, radius: Float64
) -> Float64:
    """A blurred capsule's alpha at `(px, py)` relative to its centre, in
    its own frame (the core along `x`); every length already divided by
    sigma.

    The core's rectangle is exact (`box_coverage`) and each half-disc cap
    a short integral (`_cap_coverage`), so a thin round-capped stroke
    blurs as faintly as a butt-capped one, where `rounded_rect_coverage`'s
    one step across the outline sees only the nearer edge. A dozen-odd
    more `exp` per pixel than a box, which a line's narrow shadow can
    afford and a large disc's would not: circles keep the one step.
    """
    var core = box_coverage(
        core_half + px, core_half - px, radius + py, radius - py
    )
    return (
        core
        + _cap_coverage(px, py, core_half, radius)
        + _cap_coverage(-px, py, core_half, radius)
    )


# --- Blurred silhouettes -----------------------------------------------------

comptime BLUR_REACH = 4.0
"""How many sigma a blurred shadow reaches past its silhouette before
`gaussian_cdf` rounds it to nothing."""

comptime SIL_RECT = 0
"""`[cx, cy, half_w, half_h, radius]`: a rectangle, rounded or not; a
circle is one with all three extents equal."""
comptime SIL_TRIANGLE = 1
"""`[nx, ny, c] x 3`: each edge's inward unit normal and offset."""
comptime SIL_LINE = 2
"""`[x0, y0, ux, uy, length, half_thickness, radius]`: a stroke's rectangle,
in its own frame, its caps included: lengthened by half the thickness at
both ends under `SQUARE` and `ROUND`, and under `ROUND` rounded by it into
a capsule, which blurs through `capsule_coverage`."""


def blurs_analytically(c: RenderCommand) -> Bool:
    """Whether `c`'s shadow blurs through `BlurredSilhouette` rather than
    as an image: the shapes and lines, whose edges are known exactly."""
    return (
        c.payload.isa[RectPayload]()
        or c.payload.isa[CirclePayload]()
        or c.payload.isa[TrianglePayload]()
        or c.payload.isa[LinePayload]()
    )


def local_stroke_thickness(
    c: RenderCommand, m: Matrix[3, 3], scale: Float64
) -> Float64:
    """`c`'s stroke as the rasterisers draw it — rounded to whole pixels,
    never under one — back in local units."""
    return Float64(stroke_thickness_px(c.paint, m, scale)) / pixel_scale(
        m, scale
    )


def _triangle_edges(
    xs: Array[Float64, 3], ys: Array[Float64, 3]
) -> Array[Float64, 9]:
    """Inward unit normal `(nx, ny)` and offset `c` per edge, so the signed
    distance of `(x, y)` inside edge `i` is `nx * x + ny * y + c`."""
    var out = Array[Float64, 9](fill=0.0)
    var cross = (xs[1] - xs[0]) * (ys[2] - ys[0]) - (ys[1] - ys[0]) * (
        xs[2] - xs[0]
    )
    var sign = 1.0 if cross >= 0.0 else -1.0
    for i in range(3):
        var j = (i + 1) % 3
        var ex = xs[j] - xs[i]
        var ey = ys[j] - ys[i]
        var l = sqrt(ex * ex + ey * ey)
        if l <= 0.0:
            continue
        var nx = -ey / l * sign
        var ny = ex / l * sign
        out[3 * i] = nx
        out[3 * i + 1] = ny
        out[3 * i + 2] = -(nx * xs[i] + ny * ys[i])
    return out^


struct BlurredSilhouette(Copyable, Movable):
    """A shadow silhouette with its Gaussian blur, as coverage at any local
    point.

    Built from the command `shadow_command` returns, in that command's
    local units. A ring (a stroke-only shape) is the outer shape minus the
    same shape shrunk by `ring`: blurring is linear, so the blurred ring is
    the difference of the two blurred shapes, exactly. Shrinking by `ring`
    moves every edge in by it and the corner radius down by it, which is
    what every region's stroke is: an inset ring. A
    triangle's `corner_radius` is left out: its blurred corners are the
    product of their two edges'.

    The GL path evaluates the same formulas from these fields, so the
    fragment shader is the reference for which ones it reads.
    """

    var kind: Int
    var inv_sigma: Float64
    var outer: Array[Float64, 9]
    var ring: Float64
    """How far in the inner edge of a ring sits; 0 for a filled
    silhouette, or a ring too thick to leave a hole."""
    var x0: Float64
    var y0: Float64
    var x1: Float64
    var y1: Float64
    """The outer silhouette's local bounds, before the blur's reach."""

    def __init__(out self, sh: RenderCommand, thickness: Float64):
        """`sh` is a shadow command; `thickness` its stroke in local units
        (see `local_stroke_thickness`)."""
        self.inv_sigma = (
            2.0 / sh.paint.shadow_blur if sh.paint.shadow_blur > 0.0 else 0.0
        )
        self.outer = Array[Float64, 9](fill=0.0)
        self.ring = 0.0
        var ring = not sh.paint._fill_visible()
        if sh.payload.isa[RectPayload]() or sh.payload.isa[CirclePayload]():
            self.kind = SIL_RECT
            var center: Point2D
            var hw: Float64
            var hh: Float64
            var r: Float64
            if sh.payload.isa[CirclePayload]():
                ref circle = sh.payload[CirclePayload]
                center = circle.center
                hw = circle.r
                hh = hw
                r = hw
            else:
                ref rect = sh.payload[RectPayload]
                center = rect.center
                hw = rect.w / 2.0
                hh = rect.h / 2.0
                r = rect_corner_radius(rect.corner_radius, rect.w, rect.h)
            self.outer[0] = center.x
            self.outer[1] = center.y
            self.outer[2] = hw
            self.outer[3] = hh
            self.outer[4] = r
            self.x0 = center.x - hw
            self.x1 = center.x + hw
            self.y0 = center.y - hh
            self.y1 = center.y + hh
            # Both strokes are inset rings.
            if ring and hw - thickness > 0.0 and hh - thickness > 0.0:
                self.ring = thickness
        elif sh.payload.isa[TrianglePayload]():
            self.kind = SIL_TRIANGLE
            ref corners = sh.payload[TrianglePayload].corners
            # An inset ring, as a rectangle's.
            if ring and _inradius(corners) > thickness:
                self.ring = thickness
            var xs = Array[Float64, 3](fill=0.0)
            var ys = Array[Float64, 3](fill=0.0)
            for k in range(3):
                xs[k] = corners[2 * k]
                ys[k] = corners[2 * k + 1]
            self.outer = _triangle_edges(xs, ys)
            self.x0 = min(xs[0], min(xs[1], xs[2]))
            self.x1 = max(xs[0], max(xs[1], xs[2]))
            self.y0 = min(ys[0], min(ys[1], ys[2]))
            self.y1 = max(ys[0], max(ys[1], ys[2]))
        else:
            self.kind = SIL_LINE
            ref line = sh.payload[LinePayload]
            var ax = line.start.x
            var ay = line.start.y
            var ex = line.end.x - ax
            var ey = line.end.y - ay
            var l = sqrt(ex * ex + ey * ey)
            var h = thickness / 2.0
            var ux = ex / l if l > 0.0 else 1.0
            var uy = ey / l if l > 0.0 else 0.0
            var cap = sh.paint.stroke_cap
            if cap != StrokeCap.BUTT:
                # Both caps reach half the thickness past the ends; a
                # round one is the capsule that rounds them by as much.
                ax -= ux * h
                ay -= uy * h
                l += 2.0 * h
                if cap == StrokeCap.ROUND:
                    self.outer[6] = h
            self.outer[0] = ax
            self.outer[1] = ay
            self.outer[2] = ux
            self.outer[3] = uy
            self.outer[4] = l
            self.outer[5] = h
            var bx = ax + ux * l
            var by = ay + uy * l
            self.x0 = min(ax, bx) - h
            self.x1 = max(ax, bx) + h
            self.y0 = min(ay, by) - h
            self.y1 = max(ay, by) + h

    def __init__(out self, region: InsetRegion, blur: Float64):
        """`region` blurred by `blur` local units: an inset shadow's
        silhouette. Always filled; an empty region covers nothing."""
        self.inv_sigma = 2.0 / blur if blur > 0.0 else 0.0
        self.outer = Array[Float64, 9](fill=0.0)
        self.ring = 0.0
        ref g = region.geom
        if region.kind == SIL_TRIANGLE and not region.empty:
            self.kind = SIL_TRIANGLE
            var xs = Array[Float64, 3](fill=0.0)
            var ys = Array[Float64, 3](fill=0.0)
            for k in range(3):
                xs[k] = g[2 * k]
                ys[k] = g[2 * k + 1]
            self.outer = _triangle_edges(xs, ys)
            self.x0 = min(xs[0], min(xs[1], xs[2]))
            self.x1 = max(xs[0], max(xs[1], xs[2]))
            self.y0 = min(ys[0], min(ys[1], ys[2]))
            self.y1 = max(ys[0], max(ys[1], ys[2]))
            return
        self.kind = SIL_RECT
        self.outer[0] = g[0]
        self.outer[1] = g[1]
        if not region.empty:
            self.outer[2] = g[2]
            self.outer[3] = g[3]
            self.outer[4] = min(region.radius, min(g[2], g[3]))
        self.x0 = g[0] - self.outer[2]
        self.x1 = g[0] + self.outer[2]
        self.y0 = g[1] - self.outer[3]
        self.y1 = g[1] + self.outer[3]

    def reach(self) -> Float64:
        """How far past the silhouette, in local units, any coverage lands."""
        return BLUR_REACH / self.inv_sigma if self.inv_sigma > 0.0 else 0.0

    def _one(self, x: Float64, y: Float64, shrink: Float64) -> Float64:
        """The outer silhouette's coverage, every edge moved in by
        `shrink`."""
        ref g = self.outer
        var k = self.inv_sigma
        if self.kind == SIL_RECT:
            var dx = x - g[0]
            var dy = y - g[1]
            var hw = g[2] - shrink
            var hh = g[3] - shrink
            var r = max(g[4] - shrink, 0.0)
            if r <= 0.0:
                return box_coverage(
                    (hw + dx) * k, (hw - dx) * k, (hh + dy) * k, (hh - dy) * k
                )
            return rounded_rect_coverage(dx * k, dy * k, hw * k, hh * k, r * k)
        if self.kind == SIL_TRIANGLE:
            return edge_coverage(
                (g[0] * x + g[1] * y + g[2] - shrink) * k,
                (g[3] * x + g[4] * y + g[5] - shrink) * k,
                (g[6] * x + g[7] * y + g[8] - shrink) * k,
            )
        var dx = x - g[0]
        var dy = y - g[1]
        var along = dx * g[2] + dy * g[3]
        var across = dx * g[3] - dy * g[2]
        if g[6] > 0.0:
            var half = g[4] / 2.0
            return capsule_coverage(
                (along - half) * k, across * k, (half - g[6]) * k, g[6] * k
            )
        return box_coverage(
            along * k,
            (g[4] - along) * k,
            (g[5] + across) * k,
            (g[5] - across) * k,
        )

    def coverage(self, x: Float64, y: Float64) -> Float64:
        """The blurred silhouette's alpha, 0 to 1, at local `(x, y)`."""
        var c = self._one(x, y, 0.0)
        if self.ring > 0.0 and c > 0.0:
            c -= self._one(x, y, self.ring)
        return max(c, 0.0)


def _inradius(g: Array[Float64, _GEOM_SLOTS]) -> Float64:
    """Twice the area over the perimeter: how far a triangle can shrink."""
    var ax = g[0]
    var ay = g[1]
    var bx = g[2]
    var by = g[3]
    var cx = g[4]
    var cy = g[5]
    var area2 = abs((bx - ax) * (cy - ay) - (by - ay) * (cx - ax))
    var p = (
        sqrt((bx - ax) ** 2 + (by - ay) ** 2)
        + sqrt((cx - bx) ** 2 + (cy - by) ** 2)
        + sqrt((ax - cx) ** 2 + (ay - cy) ** 2)
    )
    return area2 / p if p > 0.0 else 0.0


# --- Inset shadows -----------------------------------------------------------


def _segment_distance(
    x: Float64, y: Float64, ax: Float64, ay: Float64, bx: Float64, by: Float64
) -> Float64:
    """How far `(x, y)` is from the segment `a`-`b`."""
    var ex = bx - ax
    var ey = by - ay
    var l2 = ex * ex + ey * ey
    var t = 0.0
    if l2 > 0.0:
        t = min(max(((x - ax) * ex + (y - ay) * ey) / l2, 0.0), 1.0)
    var dx = x - (ax + t * ex)
    var dy = y - (ay + t * ey)
    return sqrt(dx * dx + dy * dy)


struct InsetRegion(Copyable, Movable):
    """A filled rectangle, circle or triangle with corners rounded by
    `radius`: what an inset shadow is clipped to — the shape inside its
    stroke — and, shifted and shrunk by the spread, the silhouette the
    shadow is cut from.

    Shrinking by `d` is the reverse of `shadow_command`'s growing: every
    edge moves in by `d` and the corner radius drops by `d`, bottoming out
    at a sharp corner. That is also exactly where a stroke's inner edge
    runs — every region's stroke is an inset ring —
    so the interior is the shape shrunk by the stroke's inward extent. The
    radius is a `Float64` rather than the style's `Int`, because those
    shrinks move it by fractions of a unit.
    """

    var kind: Int
    """`SIL_RECT` (a circle is a rectangle rounded all the way) or
    `SIL_TRIANGLE`."""
    var geom: Array[Float64, _GEOM_SLOTS]
    """`[cx, cy, half_w, half_h]` for `SIL_RECT`, the three vertices for
    `SIL_TRIANGLE`, all in the command's local units."""
    var radius: Float64
    var empty: Bool
    """Shrunk past nothing: contains no point and covers nothing."""

    def __init__(out self, c: RenderCommand, inset: Float64):
        """`c`'s filled shape (`c` a rect, circle or triangle), every edge
        moved in by `inset` local units."""
        self.geom = Array[Float64, _GEOM_SLOTS](fill=0.0)
        self.empty = False
        if c.payload.isa[TrianglePayload]():
            ref triangle = c.payload[TrianglePayload]
            ref g = triangle.corners
            self.kind = SIL_TRIANGLE
            self.geom = g.copy()
            self.radius = triangle_corner_radius(
                triangle.corner_radius, g[0], g[1], g[2], g[3], g[4], g[5]
            )
        elif c.payload.isa[CirclePayload]():
            ref circle = c.payload[CirclePayload]
            self.kind = SIL_RECT
            self.geom[0] = circle.center.x
            self.geom[1] = circle.center.y
            self.geom[2] = circle.r
            self.geom[3] = circle.r
            self.radius = circle.r
        else:
            ref rect = c.payload[RectPayload]
            self.kind = SIL_RECT
            self.radius = rect_corner_radius(rect.corner_radius, rect.w, rect.h)
            self.geom[0] = rect.center.x
            self.geom[1] = rect.center.y
            self.geom[2] = rect.w / 2.0
            self.geom[3] = rect.h / 2.0
        self._shrink(inset)

    def shrunk(self, d: Float64) -> InsetRegion:
        """This region with every edge moved in by `d`; out, for a negative
        `d`."""
        var r = self.copy()
        r._shrink(d)
        return r^

    def _shrink(mut self, d: Float64):
        if self.empty or d == 0.0:
            return
        if self.kind == SIL_RECT:
            self.geom[2] -= d
            self.geom[3] -= d
            if self.geom[2] <= 0.0 or self.geom[3] <= 0.0:
                self.empty = True
                return
        else:
            if d >= _inradius(self.geom):
                self.empty = True
                return
            _grow_triangle(self.geom, -d)
        self.radius = max(self.radius - d, 0.0)

    def bounds(self) -> Tuple[Float64, Float64, Float64, Float64]:
        """`(x0, y0, x1, y1)`, the local box the region fits in."""
        ref g = self.geom
        if self.kind == SIL_RECT:
            return (g[0] - g[2], g[1] - g[3], g[0] + g[2], g[1] + g[3])
        return (
            min(g[0], min(g[2], g[4])),
            min(g[1], min(g[3], g[5])),
            max(g[0], max(g[2], g[4])),
            max(g[1], max(g[3], g[5])),
        )

    def contains(self, x: Float64, y: Float64) -> Bool:
        """Whether local `(x, y)` is inside, its edge included."""
        if self.empty:
            return False
        ref g = self.geom
        if self.kind == SIL_RECT:
            var r = min(self.radius, min(g[2], g[3]))
            var qx = abs(x - g[0]) - (g[2] - r)
            var qy = abs(y - g[1]) - (g[3] - r)
            var ox = max(qx, 0.0)
            var oy = max(qy, 0.0)
            return sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0.0) <= r
        # A rounded triangle is its core — the triangle shrunk by the radius —
        # grown by a disc: inside the core, or within `radius` of its edges.
        var core = self.geom.copy()
        if self.radius > 0.0:
            _grow_triangle(core, -self.radius)
        var xs = Array[Float64, 3](fill=0.0)
        var ys = Array[Float64, 3](fill=0.0)
        for k in range(3):
            xs[k] = core[2 * k]
            ys[k] = core[2 * k + 1]
        var e = _triangle_edges(xs, ys)
        var inside = True
        for k in range(3):
            if e[3 * k] * x + e[3 * k + 1] * y + e[3 * k + 2] < 0.0:
                inside = False
        if inside or self.radius <= 0.0:
            return inside
        for k in range(3):
            var j = (k + 1) % 3
            if (
                _segment_distance(x, y, xs[k], ys[k], xs[j], ys[j])
                <= self.radius
            ):
                return True
        return False


def inset_interior(c: RenderCommand, thickness: Float64) -> InsetRegion:
    """What `c`'s inset shadow is clipped to: the shape inside its stroke.

    `thickness` is the stroke in local units, as the rasterisers draw it
    (`local_stroke_thickness`), and ignored when the stroke is off. A
    region's stroke is an inset ring, all of it inside.
    """
    var inset = thickness if c.paint._stroke_visible() else 0.0
    return InsetRegion(c, inset)
