from std.math import sqrt

from create.color.color import Color, _tinted
from create.color.gradient import Gradient
from .style import Style
from create.geometry.bezier import Bezier
from create.math.matrix import Matrix, identity
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D

comptime CMD_CLEAR = 0
"""Paint the whole framebuffer. `style.fill_color` is the colour."""
comptime CMD_RECT = 1
comptime CMD_CIRCLE = 2
comptime CMD_LINE = 3
comptime CMD_TRIANGLE = 4
comptime CMD_IMAGE = 5
comptime CMD_TEXT = 6
comptime CMD_LETTERBOX = 7
"""Paint the four bars outside the design area. `style.fill_color` is the colour and
`geom` is the *device* content rect — the one command whose geometry is
already in pixels, because it is the frame's clip rather than something a
program drew."""
comptime CMD_BEZIER = 8
"""A stroke along a chain of cubic Béziers, its control points in `points`
rather than `geom`. Stroke only — a curve has no interior."""
comptime CMD_SECTOR = 9
"""A pie slice: the tip `(cx, cy)`, radius `r`, and a signed sweep from
`start` in radians, counter-clockwise positive."""
comptime CMD_POLYGON = 10
"""A polygon filled by the nonzero rule, its vertices in `points` rather than
`geom`. `geom[0]` offsets it by that many local units, outwards if positive:
zero for a render call, a shadow's spread otherwise."""

comptime _GEOM_SLOTS = 6
"""Widest fixed geometry any kind needs: a triangle's three corners."""


struct RenderCommand(Copyable, Movable):
    """One recorded render, everything a backend needs to replay it.

    `Canvas` appends one of these per render call instead of rasterising, and a
    backend consumes the whole buffer at the end of the frame. That seam is
    what lets a GPU backend exist at all: a `Surface` is a pixel pointer, which
    a GPU does not have, whereas this is just data.

    **Geometry is local, never device.** It is the shape as the program asked
    for it, paired with the `transform` that maps it — *not* a pre-mapped
    device rect. A rotated rectangle is not an axis-aligned device rectangle,
    so pre-mapping would be lossy; the CPU replay needs the matrix anyway to
    inverse-map per pixel, and the GL backend wants exactly this shape because
    the transform becomes a vertex-shader uniform. The one exception is
    `CMD_LETTERBOX`, noted above.

    Everything else the replay needs is derivable from `transform`: whether it
    is an axis-aligned uniform scale, the world-units-per-pixel factor, and the
    device scan bounds of a local box.

    `geom` slots by kind:

    | kind | 0 | 1 | 2 | 3 | 4 | 5 |
    |---|---|---|---|---|---|---|
    | `CMD_CLEAR` | `x` | `y` | `w` | `h` | — | — |
    | `CMD_RECT` | `x` | `y` | `w` | `h` | — | — |
    | `CMD_CIRCLE` | `cx` | `cy` | `r` | — | — | — |
    | `CMD_LINE` | `x0` | `y0` | `x1` | `y1` | — | — |
    | `CMD_TRIANGLE` | `x1` | `y1` | `x2` | `y2` | `x3` | `y3` |
    | `CMD_IMAGE` | `cx` | `cy` | `w` | `h` | — | — |
    | `CMD_TEXT` | `x` | `y` | — | — | — | — |
    | `CMD_LETTERBOX` | `cx0` | `cy0` | `cx1` | `cy1` | — | — |
    | `CMD_BEZIER` | — | — | — | — | — | — |
    | `CMD_SECTOR` | `cx` | `cy` | `r` | `start` | `sweep` | — |
    | `CMD_POLYGON` | `grow` | box `cx` | box `cy` | box `hw` | box `hh` | box set |

    Build one with the free functions below rather than by hand, so no rendering
    call site has to remember that table.
    """

    var kind: Int
    var geom: Array[Float64, _GEOM_SLOTS]
    var transform: Matrix[3, 3]
    var style: Style
    """Resolved at record time. A later `canvas.fill()` cannot reach back and
    change what an already-recorded command paints."""
    var corner_radius: Float64
    """`CMD_RECT` and `CMD_TRIANGLE`: the requested corner radius in local
    units, before the replay clamps it to what the shape can hold. 0 is
    sharp. A field of its own because a triangle fills every `geom` slot."""
    var text: String
    """`CMD_TEXT` only, and owned — layout happens at replay, in the backend
    that holds the fonts, so the string has to outlive the rendering call."""
    var points: List[Point2D]
    """`CMD_BEZIER`: a chain of n Béziers as 3n + 1 control points,
    `start, control1, control2` of each followed by the last one's `end`;
    each Bézier starts where the one before it ends. `CMD_POLYGON`: the
    vertices, in order. Empty for every other kind, which costs no
    allocation."""
    var image: Int
    """`CMD_IMAGE` only: a backend image id, interned at record time. The
    pixels are copied or uploaded when the image is first seen, so no borrow
    of caller-owned memory ever enters the buffer."""
    var image_w: Int
    var image_h: Int
    var silhouette: Bool
    """`CMD_IMAGE` only: paint `style.fill_color` wherever the image is
    opaque, scaled by its alpha, instead of the image. An image's shadow."""
    var image_tint: Color
    """`CMD_IMAGE` only: the style's tint with its alpha scaled by opacity,
    which multiplies every texel. An image takes none of the style's
    colours, so neither can be resolved into one of them as for every other
    kind; a silhouette ignores it, since its colour already carries both."""
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
        kind: Int,
        transform: Matrix[3, 3],
        style: Style,
        g0: Float64 = 0.0,
        g1: Float64 = 0.0,
        g2: Float64 = 0.0,
        g3: Float64 = 0.0,
        g4: Float64 = 0.0,
        g5: Float64 = 0.0,
    ):
        self.kind = kind
        self.geom = Array[Float64, _GEOM_SLOTS](fill=0.0)
        self.geom[0] = g0
        self.geom[1] = g1
        self.geom[2] = g2
        self.geom[3] = g3
        self.geom[4] = g4
        self.geom[5] = g5
        self.transform = transform
        self.style = style
        self.corner_radius = 0.0
        var image_tint = Color.WHITE
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
            image_tint = _tinted(Color.WHITE, tint, opacity)
            self.style.tint = Color.WHITE
            self.style.opacity = 1.0
        self.text = String("")
        self.points = List[Point2D]()
        self.image = 0
        self.image_w = 0
        self.image_h = 0
        self.silhouette = False
        self.image_tint = image_tint
        self.clip = 0
        self.stroke_grow = 0.0


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
    if c.kind == CMD_RECT or c.kind == CMD_CLEAR:
        return (
            Point2D(c.geom[0], c.geom[1]),
            Vector2D(
                c.geom[2] / 2.0 - c.stroke_grow, c.geom[3] / 2.0 - c.stroke_grow
            ),
        )
    if c.kind == CMD_CIRCLE:
        var r = c.geom[2] - c.stroke_grow
        return (Point2D(c.geom[0], c.geom[1]), Vector2D(r, r))
    if c.kind == CMD_SECTOR:
        return (Point2D(c.geom[0], c.geom[1]), Vector2D(c.geom[2], c.geom[2]))
    if c.kind == CMD_POLYGON and c.geom[5] != 0.0:
        return (Point2D(c.geom[1], c.geom[2]), Vector2D(c.geom[3], c.geom[4]))
    var lo_x = Float64.MAX
    var lo_y = Float64.MAX
    var hi_x = -Float64.MAX
    var hi_y = -Float64.MAX
    if c.kind == CMD_TRIANGLE:
        var g = c.geom.copy()
        if c.stroke_grow != 0.0:
            _grow_triangle(g, -c.stroke_grow)
        for i in range(3):
            lo_x = min(lo_x, g[2 * i])
            hi_x = max(hi_x, g[2 * i])
            lo_y = min(lo_y, g[2 * i + 1])
            hi_y = max(hi_y, g[2 * i + 1])
    else:
        for p in c.points:
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
    return RenderCommand(CMD_CLEAR, identity[3](), s)


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
    return RenderCommand(CMD_CLEAR, screen, s, 0.0, 0.0, w, h)


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
    var c = RenderCommand(CMD_RECT, transform, style, x, y, w, h)
    c.corner_radius = corner_radius
    return c^


def circle_command(
    transform: Matrix[3, 3],
    style: Style,
    cx: Float64,
    cy: Float64,
    r: Float64,
) -> RenderCommand:
    return RenderCommand(CMD_CIRCLE, transform, style, cx, cy, r)


def sector_command(
    transform: Matrix[3, 3],
    style: Style,
    cx: Float64,
    cy: Float64,
    r: Float64,
    start: Float64,
    sweep: Float64,
) -> RenderCommand:
    return RenderCommand(CMD_SECTOR, transform, style, cx, cy, r, start, sweep)


def line_command(
    transform: Matrix[3, 3],
    style: Style,
    x0: Float64,
    y0: Float64,
    x1: Float64,
    y1: Float64,
) -> RenderCommand:
    return RenderCommand(CMD_LINE, transform, style, x0, y0, x1, y1)


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
    var c = RenderCommand(
        CMD_TRIANGLE, transform, style, x1, y1, x2, y2, x3, y3
    )
    c.corner_radius = corner_radius
    return c^


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
    var c = RenderCommand(CMD_BEZIER, transform, style)
    c.points = points^
    return c^


def polygon_command(
    transform: Matrix[3, 3], style: Style, var vertices: List[Point2D]
) -> RenderCommand:
    """A polygon through `vertices`, in order, closed back to the first."""
    var c = RenderCommand(CMD_POLYGON, transform, style)
    c.points = vertices^
    return c^


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
    c.geom[1] = cx
    c.geom[2] = cy
    c.geom[3] = half_w
    c.geom[4] = half_h
    c.geom[5] = 1.0
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
    var c = RenderCommand(CMD_IMAGE, transform, style, cx, cy, w, h)
    c.image = image
    c.image_w = image_w
    c.image_h = image_h
    return c^


def text_command(
    transform: Matrix[3, 3], style: Style, x: Float64, y: Float64, var s: String
) -> RenderCommand:
    """Text anchored at `(x, y)` in local units.

    Deferred whole: the alignment, advances and baseline all come out of
    `style` and the backend's font at replay time, so nothing about the layout
    is decided here.
    """
    var c = RenderCommand(CMD_TEXT, transform, style, x, y)
    c.text = s^
    return c^


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
    return RenderCommand(CMD_LETTERBOX, identity[3](), s, cx0, cy0, cx1, cy1)
