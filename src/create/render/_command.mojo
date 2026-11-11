from std.math import sqrt

from create.color.color import Color, _tinted
from create.color.gradient import Gradient
from .style import Style
from create.geometry.bezier import Bezier
from create.math.matrix import Matrix, identity
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D
from std.utils import Variant

comptime _GEOM_SLOTS = 6
"""A triangle's three corners, interleaved `x1, y1, x2, y2, x3, y3`."""


@fieldwise_init
struct ClearPayload(Copyable, Movable):
    """Paint the whole framebuffer in `style.fill_color`, or its gradient.

    A gradient spans the `w` x `h` area centred on the origin (the design
    area) that the command's transform maps to pixels; a colour clear has a
    zero area and the identity, since it covers the framebuffer, not the
    design."""

    var w: Float64
    var h: Float64


@fieldwise_init
struct RectPayload(Copyable, Movable):
    """A rectangle centred at `center`, `w` by `h`, its corners rounded by
    `corner_radius` (the requested radius, before the replay clamps it to
    what the shape can hold; 0 is sharp)."""

    var center: Point2D
    var w: Float64
    var h: Float64
    var corner_radius: Float64


@fieldwise_init
struct CirclePayload(Copyable, Movable):
    var center: Point2D
    var r: Float64


@fieldwise_init
struct LinePayload(Copyable, Movable):
    var start: Point2D
    var end: Point2D


@fieldwise_init
struct TrianglePayload(Copyable, Movable):
    """A triangle through `corners` (`x1, y1, x2, y2, x3, y3`), rounded by
    `corner_radius`, requested as for a rectangle."""

    var corners: Array[Float64, _GEOM_SLOTS]
    var corner_radius: Float64


@fieldwise_init
struct ImagePayload(Copyable, Movable):
    """An image centred at `center`, rendered `w` by `h` local units.

    `image` is a backend id, interned at record time, not a pointer: the
    pixels are shared or uploaded when the image is first seen, so no borrow
    of caller-owned memory enters the buffer. `image_w` and `image_h` are the
    source's pixel dimensions, which the replay needs to resample."""

    var center: Point2D
    var w: Float64
    var h: Float64
    var image: Int
    var image_w: Int
    var image_h: Int
    var silhouette: Bool
    """Paint `style.fill_color` wherever the image is opaque, scaled by its
    alpha, instead of the image. An image's shadow."""
    var tint: Color
    """The style's tint with its alpha scaled by opacity, which multiplies
    every texel. An image takes none of the style's colours, so neither can
    be resolved into one of them as for every other kind; a silhouette
    ignores it, since its colour already carries both. Set by
    `RenderCommand.__init__`."""


@fieldwise_init
struct TextPayload(Copyable, Movable):
    """`text` anchored at `position`. Owned, since layout happens at replay,
    in the backend that holds the fonts."""

    var position: Point2D
    var text: String


@fieldwise_init
struct LetterboxPayload(Copyable, Movable):
    """The bars outside the *device* content rect `[x0, x1) x [y0, y1)` —
    the one payload already in pixels, because it is the frame's clip rather
    than something a program drew."""

    var x0: Float64
    var y0: Float64
    var x1: Float64
    var y1: Float64


@fieldwise_init
struct CurvesPayload(Copyable, Movable):
    """A stroke along a chain of n cubic Béziers, as 3n + 1 control
    `points`: `start, control1, control2` of each, then the last one's
    `end`; each starts where the one before it ends. Stroke only — a curve
    has no interior."""

    var points: List[Point2D]


@fieldwise_init
struct SectorPayload(Copyable, Movable):
    """A pie slice: its tip at `center`, radius `r`, and a signed sweep from
    `start_angle` in radians, counter-clockwise positive. `grow` offsets it
    by that many local units, outwards if positive: zero for a render call,
    a shadow's spread or a stroke alignment otherwise."""

    var center: Point2D
    var r: Float64
    var start_angle: Float64
    var sweep_angle: Float64
    var grow: Float64


@fieldwise_init
struct PolygonPayload(Copyable, Movable):
    """A polygon through `vertices`, in order, filled by the nonzero rule.
    `grow` is as for a sector. `gradient_box`, when set, is the centre and
    half-extents a fill gradient spans instead of the vertices' bounds: a
    curved shape flattened to a polygon, whose chords fall short of it."""

    var vertices: List[Point2D]
    var grow: Float64
    var gradient_box: Optional[Tuple[Point2D, Vector2D]]


comptime RenderPayload = Variant[
    ClearPayload,
    RectPayload,
    CirclePayload,
    LinePayload,
    TrianglePayload,
    ImagePayload,
    TextPayload,
    LetterboxPayload,
    CurvesPayload,
    SectorPayload,
    PolygonPayload,
]
"""What a command draws. Check the kind with `.isa[T]()` and read or change
its fields through `[T]`, e.g. `c.payload[RectPayload].w`."""


struct RenderCommand(Copyable, Movable):
    """One recorded render, everything a backend needs to replay it.

    `Canvas` appends one of these per render call instead of rasterising, and a
    backend consumes the whole buffer at the end of the frame. That seam is
    what lets a GPU backend exist at all: a `Surface` is a pixel pointer, which
    a GPU does not have, whereas this is just data.

    **Geometry is local, never device.** `payload` is the shape as the
    program asked for it, paired with the `transform` that maps it — *not* a
    pre-mapped device rect. A rotated rectangle is not an axis-aligned device
    rectangle, so pre-mapping would be lossy; the CPU replay needs the matrix
    anyway to inverse-map per pixel, and the GL backend wants exactly this
    shape because the transform becomes a vertex-shader uniform. The one
    exception is `LetterboxPayload`.

    Everything else the replay needs is derivable from `transform`: whether it
    is an axis-aligned uniform scale, the world-units-per-pixel factor, and the
    device scan bounds of a local box.

    Build one with the free functions below rather than by hand.
    """

    var payload: RenderPayload
    var transform: Matrix[3, 3]
    var style: Style
    """Resolved at record time. A later `canvas.fill()` cannot reach back and
    change what an already-recorded command paints."""
    var clip: Int
    """The id of the innermost `canvas.clip` this was rendered under — an
    index into `Backend.clips`, one past — or 0 for none. Stamped by
    `Backend.record`, so no builder below has to know about clips."""
    var stroke_grow: Float64
    """How far `aligned_stroke` grew the shape to move its stroke out, in
    local units; 0 for a command as recorded. `_fill_box` takes it back off
    a rectangle and a circle, so a fill gradient stays where the shape is."""

    def __init__(
        out self,
        var payload: RenderPayload,
        transform: Matrix[3, 3],
        style: Style,
    ):
        self.payload = payload^
        self.transform = transform
        self.style = style
        if self.style.tint != Color.WHITE or self.style.opacity != 1.0:
            var tint = self.style.tint
            var opacity = self.style.opacity
            self.style.fill_color = _tinted(
                self.style.fill_color, tint, opacity
            )
            if self.style.fill_gradient:
                self.style.fill_gradient = (
                    self.style.fill_gradient.value()._tinted(tint, opacity)
                )
            self.style.stroke_color = _tinted(
                self.style.stroke_color, tint, opacity
            )
            self.style.text_color = _tinted(
                self.style.text_color, tint, opacity
            )
            self.style.shadow_color = _tinted(
                self.style.shadow_color, tint, opacity
            )
            if self.payload.isa[ImagePayload]():
                self.payload[ImagePayload].tint = _tinted(
                    Color.WHITE, tint, opacity
                )
            self.style.tint = Color.WHITE
            self.style.opacity = 1.0
        self.clip = 0
        self.stroke_grow = 0.0

    def is_region(self) -> Bool:
        """Whether this draws a shape with an inside: a rectangle, circle,
        triangle, sector or polygon."""
        return (
            self.payload.isa[RectPayload]()
            or self.payload.isa[CirclePayload]()
            or self.payload.isa[TrianglePayload]()
            or self.payload.isa[SectorPayload]()
            or self.payload.isa[PolygonPayload]()
        )

    def is_shape(self) -> Bool:
        """Whether this draws a shape or a curve: a region, a line or a
        chain of Béziers — what the antialiased shape replay takes."""
        return (
            self.is_region()
            or self.payload.isa[LinePayload]()
            or self.payload.isa[CurvesPayload]()
        )


def _grow_triangle(mut g: Array[Float64, _GEOM_SLOTS], d: Float64):
    """Move each vertex out along its corner's bisector so every edge lands
    `d` further out. Shrinks for a negative `d`; a degenerate triangle is left
    alone."""
    var xs = Array[Float64, 3](fill=0.0)
    var ys = Array[Float64, 3](fill=0.0)
    var out = Array[Float64, 6](fill=0.0)
    for i in range(3):
        xs[i] = g[2 * i]
        ys[i] = g[2 * i + 1]
    for i in range(3):
        var px = xs[(i + 2) % 3]
        var py = ys[(i + 2) % 3]
        var nx = xs[(i + 1) % 3]
        var ny = ys[(i + 1) % 3]
        var l1 = sqrt((px - xs[i]) ** 2 + (py - ys[i]) ** 2)
        var l2 = sqrt((nx - xs[i]) ** 2 + (ny - ys[i]) ** 2)
        if l1 <= 0.0 or l2 <= 0.0:
            return
        var ux = (px - xs[i]) / l1
        var uy = (py - ys[i]) / l1
        var wx = (nx - xs[i]) / l2
        var wy = (ny - ys[i]) / l2
        # `u + w` points inward along the bisector; its length is
        # `2 cos(theta/2)` and the vertex has to move `d / sin(theta/2)`.
        var bx = ux + wx
        var by = uy + wy
        var bl = sqrt(bx * bx + by * by)
        var cross = ux * wy - uy * wx
        var sin_half = sqrt(max(0.0, (1.0 - (ux * wx + uy * wy)) / 2.0))
        if bl <= 1e-12 or sin_half <= 1e-6 or abs(cross) <= 1e-12:
            return
        var k = d / sin_half
        out[2 * i] = xs[i] - bx / bl * k
        out[2 * i + 1] = ys[i] - by / bl * k
    for i in range(6):
        g[i] = out[i]


def _fill_box(c: RenderCommand) -> Tuple[Point2D, Vector2D]:
    """The local box a fill gradient spans: its centre and half-extents.

    The shape's own bounds, before the transform, so the gradient moves and
    turns with it. A sector spans its whole circle, like a circle, so a
    slice shows the part of the circle's gradient it covers; a triangle and
    a polygon span their vertices' bounds. Both replays read this, so they
    agree on where a gradient lies. A stroke moved out by `aligned_stroke`
    leaves it where it was.
    """
    if c.payload.isa[RectPayload]():
        ref rect = c.payload[RectPayload]
        return (
            rect.center,
            Vector2D(
                rect.w / 2.0 - c.stroke_grow, rect.h / 2.0 - c.stroke_grow
            ),
        )
    if c.payload.isa[ClearPayload]():
        ref clear = c.payload[ClearPayload]
        return (Point2D(0.0, 0.0), Vector2D(clear.w / 2.0, clear.h / 2.0))
    if c.payload.isa[CirclePayload]():
        ref circle = c.payload[CirclePayload]
        var r = circle.r - c.stroke_grow
        return (circle.center, Vector2D(r, r))
    if c.payload.isa[SectorPayload]():
        ref sector = c.payload[SectorPayload]
        return (sector.center, Vector2D(sector.r, sector.r))
    var lo_x = Float64.MAX
    var lo_y = Float64.MAX
    var hi_x = -Float64.MAX
    var hi_y = -Float64.MAX
    if c.payload.isa[TrianglePayload]():
        var g = c.payload[TrianglePayload].corners.copy()
        if c.stroke_grow != 0.0:
            _grow_triangle(g, -c.stroke_grow)
        for i in range(3):
            lo_x = min(lo_x, g[2 * i])
            hi_x = max(hi_x, g[2 * i])
            lo_y = min(lo_y, g[2 * i + 1])
            hi_y = max(hi_y, g[2 * i + 1])
    elif c.payload.isa[PolygonPayload]():
        ref polygon = c.payload[PolygonPayload]
        if polygon.gradient_box:
            return polygon.gradient_box.value()
        for p in polygon.vertices:
            lo_x = min(lo_x, p.x)
            hi_x = max(hi_x, p.x)
            lo_y = min(lo_y, p.y)
            hi_y = max(hi_y, p.y)
    if lo_x > hi_x:
        return (Point2D(0.0, 0.0), Vector2D(0.0, 0.0))
    return (
        Point2D((lo_x + hi_x) / 2.0, (lo_y + hi_y) / 2.0),
        Vector2D((hi_x - lo_x) / 2.0, (hi_y - lo_y) / 2.0),
    )


def clear_command(color: Color) -> RenderCommand:
    """Paint the whole framebuffer. Carries no transform — it covers the
    framebuffer, not the design area, so no mapping applies."""
    var s = Style()
    s.fill_color = color
    s.fill_enabled = True
    return RenderCommand(ClearPayload(0.0, 0.0), identity[3](), s)


def clear_command(
    gradient: Gradient, screen: Matrix[3, 3], w: Float64, h: Float64
) -> RenderCommand:
    """Paint the whole framebuffer with `gradient`, spread over the `w` x `h`
    screen-space area centred on the origin — the design area — which
    `screen` maps to pixels. Beyond that area, as in the letterbox, its end
    colours carry on. The geometry is the rectangle's, which is the box
    `_fill_box` reads."""
    var s = Style()
    s.fill_gradient = gradient
    s.fill_enabled = True
    return RenderCommand(ClearPayload(w, h), screen, s)


def _clear_is_opaque(c: RenderCommand) -> Bool:
    """Whether the clear `c` hides everything under it."""
    if c.style.fill_gradient:
        return c.style.fill_gradient.value()._opaque()
    return c.style.fill_color.a == 255


def rect_command(
    transform: Matrix[3, 3],
    style: Style,
    x: Float64,
    y: Float64,
    w: Float64,
    h: Float64,
    corner_radius: Float64 = 0.0,
) -> RenderCommand:
    """A rectangle centred at `(x, y)`, `w` by `h`, in local units, its
    corners rounded by `corner_radius`."""
    return RenderCommand(
        RectPayload(Point2D(x, y), w, h, corner_radius), transform, style
    )


def circle_command(
    transform: Matrix[3, 3],
    style: Style,
    cx: Float64,
    cy: Float64,
    r: Float64,
) -> RenderCommand:
    return RenderCommand(CirclePayload(Point2D(cx, cy), r), transform, style)


def sector_command(
    transform: Matrix[3, 3],
    style: Style,
    cx: Float64,
    cy: Float64,
    r: Float64,
    start: Float64,
    sweep: Float64,
) -> RenderCommand:
    return RenderCommand(
        SectorPayload(Point2D(cx, cy), r, start, sweep, 0.0), transform, style
    )


def line_command(
    transform: Matrix[3, 3],
    style: Style,
    x0: Float64,
    y0: Float64,
    x1: Float64,
    y1: Float64,
) -> RenderCommand:
    return RenderCommand(
        LinePayload(Point2D(x0, y0), Point2D(x1, y1)), transform, style
    )


def triangle_command(
    transform: Matrix[3, 3],
    style: Style,
    x1: Float64,
    y1: Float64,
    x2: Float64,
    y2: Float64,
    x3: Float64,
    y3: Float64,
    corner_radius: Float64 = 0.0,
) -> RenderCommand:
    var corners = Array[Float64, _GEOM_SLOTS](fill=0.0)
    corners[0] = x1
    corners[1] = y1
    corners[2] = x2
    corners[3] = y2
    corners[4] = x3
    corners[5] = y3
    return RenderCommand(
        TrianglePayload(corners^, corner_radius), transform, style
    )


def bezier_command(
    transform: Matrix[3, 3], style: Style, curve: Bezier
) -> RenderCommand:
    return bezier_chain_command(
        transform,
        style,
        [curve.start, curve.control1, curve.control2, curve.end],
    )


def bezier_chain_command(
    transform: Matrix[3, 3], style: Style, var points: List[Point2D]
) -> RenderCommand:
    """A stroke along the joined Béziers whose control points are `points`,
    laid out as `RenderCommand.points` describes: 3n + 1 of them."""
    return RenderCommand(CurvesPayload(points^), transform, style)


def polygon_command(
    transform: Matrix[3, 3], style: Style, var vertices: List[Point2D]
) -> RenderCommand:
    """A polygon through `vertices`, in order, closed back to the first."""
    return RenderCommand(PolygonPayload(vertices^, 0.0, None), transform, style)


def rounded_sector_command(
    transform: Matrix[3, 3],
    style: Style,
    var vertices: List[Point2D],
    cx: Float64,
    cy: Float64,
    r: Float64,
) -> RenderCommand:
    """A rounded sector, recorded as the polygon through its flattened
    outline `vertices`, its gradient still spanning its whole circle (at
    `(cx, cy)`, radius `r`) as a sector's does."""
    return framed_polygon_command(transform, style, vertices^, cx, cy, r, r)


def framed_polygon_command(
    transform: Matrix[3, 3],
    style: Style,
    var vertices: List[Point2D],
    cx: Float64,
    cy: Float64,
    half_w: Float64,
    half_h: Float64,
) -> RenderCommand:
    """The polygon through a curved shape's flattened outline `vertices`,
    its gradient spanning the box at `(cx, cy)` with these half-extents
    rather than the vertices' bounds, which the chords fall short of."""
    var c = polygon_command(transform, style, vertices^)
    c.payload[PolygonPayload].gradient_box = (
        Point2D(cx, cy),
        Vector2D(half_w, half_h),
    )
    return c^


def image_command(
    transform: Matrix[3, 3],
    style: Style,
    cx: Float64,
    cy: Float64,
    w: Float64,
    h: Float64,
    image: Int,
    image_w: Int,
    image_h: Int,
) -> RenderCommand:
    """An image centred at `(cx, cy)`, rendered `w` by `h` local units.

    `image` is a backend id, not a pointer — see the field docstring. `image_w`
    and `image_h` are the source pixel dimensions, which the replay needs to
    resample and the record site already knows.
    """
    return RenderCommand(
        ImagePayload(
            Point2D(cx, cy),
            w,
            h,
            image,
            image_w,
            image_h,
            silhouette=False,
            tint=Color.WHITE,
        ),
        transform,
        style,
    )


def text_command(
    transform: Matrix[3, 3], style: Style, x: Float64, y: Float64, var s: String
) -> RenderCommand:
    """Text anchored at `(x, y)` in local units.

    Deferred whole: the alignment, advances and baseline all come out of
    `style` and the backend's font at replay time, so nothing about the layout
    is decided here.
    """
    return RenderCommand(TextPayload(Point2D(x, y), s^), transform, style)


def letterbox_command(
    color: Color, cx0: Float64, cy0: Float64, cx1: Float64, cy1: Float64
) -> RenderCommand:
    """The bars outside the device content rect `[cx0, cx1) x [cy0, cy1)`.

    Recorded last, so it doubles as the clip for anything a program drew past
    the edges of the design area.
    """
    var s = Style()
    s.fill_color = color
    s.fill_enabled = True
    return RenderCommand(LetterboxPayload(cx0, cy0, cx1, cy1), identity[3](), s)
