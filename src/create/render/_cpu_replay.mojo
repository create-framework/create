"""The CPU replay: every recorded command rasterised onto a `Surface`.

`CpuReplay.replay` is what `Backend.present` runs on the CPU backend, and
what every capture and pixel read runs on either backend. Rectangles and
circles are rasterised from their equations, row by row; every other shape
through the pieces `shape_pieces` cuts it into; text and images by blitting.
Shadows, clips and antialiasing are applied around those here, so no
rasteriser in `_raster.mojo` knows about any of them.
"""

from std.collections import Dict, Optional
from std.math import max, min, abs, sqrt, ceil, floor

from create.math.matrix import (
    Matrix,
    identity,
    inverse,
    _apply as mat_apply,
    scale as mat_scale,
)

from ._command import (
    CirclePayload,
    ClearPayload,
    ImagePayload,
    LetterboxPayload,
    RectPayload,
    TextPayload,
    TrianglePayload,
    RenderCommand,
    _fill_box,
)
from ._lower import (
    is_lowered,
    is_plain_triangle,
    shape_pieces,
    shape_shadow_mask,
)
from ._pieces import fill_pieces
from ._blur import (
    SHADOW_MASK_LIMIT,
    BlurredMask,
    blur_image_alpha,
    shadow_mask_key,
)
from ._raster import (
    FillPaint,
    blend,
    blit_alpha,
    blit_image,
    blit_image_mapped,
    fill_all,
    fill_pixels,
    fill_span,
    fill_triangle,
)
from ._image_mapping import image_mapping, upright, upright_rect
from ._clip import _Clip, _ClipRows
from ._transform import (
    glyph_transform,
    stroke_thickness_px,
    pixel_scale,
    text_pixel_scale,
    text_upright,
    uniform,
)
from ._stroke import aligned_stroke, stroke_offset
from ._shadow import (
    BlurredSilhouette,
    blurs_analytically,
    casts_inset_shadow,
    casts_outer_shadow,
    image_shadow_mask,
    inset_interior,
    local_stroke_thickness,
    shadow_command,
    shadow_transform,
)
from create.geometry._fillet import rect_corner_radius
from ._surface import Surface
from ._resources import Resources
from .antialiasing import Antialiasing
from ._coverage import CoverageScratch, composite_coverage
from create.color.color import Color


def device_bounds(
    m: Matrix[3, 3],
    lx0: Float64,
    ly0: Float64,
    lx1: Float64,
    ly1: Float64,
    width: Int,
    height: Int,
) -> Tuple[Int, Int, Int, Int]:
    """Device-space scan bounds for the local box `[lx0, lx1] x [ly0, ly1]`.

    Returns `(x_min, y_min, x_max, y_max)`, half-open on the maxima and
    clipped to `width` x `height`. The bounds come from the four *corners*,
    not the edge midpoints: under a rotation the midpoints are no longer the
    extremes, and scanning between them clips the shape.
    """
    var p0 = mat_apply(m, lx0, ly0)
    var p1 = mat_apply(m, lx1, ly0)
    var p2 = mat_apply(m, lx1, ly1)
    var p3 = mat_apply(m, lx0, ly1)
    var x_min = max(Int(min(min(p0[0], p1[0]), min(p2[0], p3[0]))), 0)
    var x_max = min(Int(max(max(p0[0], p1[0]), max(p2[0], p3[0]))) + 1, width)
    var y_min = max(Int(min(min(p0[1], p1[1]), min(p2[1], p3[1]))), 0)
    var y_max = min(Int(max(max(p0[1], p1[1]), max(p2[1], p3[1]))) + 1, height)
    return (x_min, y_min, x_max, y_max)


def _fill_paint(c: RenderCommand, m: Matrix[3, 3]) -> FillPaint:
    """What `c`'s fill paints, for a command mapped to device pixels by `m`:
    its colour, or its gradient placed over its `_fill_box`."""
    if not c.paint.fill_gradient:
        return c.paint.fill_color
    ref gradient = c.paint.fill_gradient.value()
    var box = _fill_box(c)
    return FillPaint(
        gradient, gradient._device_mapping(inverse(m), box[0], box[1])
    )


def _blurred_shadow[
    o: Origin[mut=True]
](s: Surface[o], sh: RenderCommand, scale: Float64, m: Matrix[3, 3]):
    """Paint the shadow command `sh` blurred, pixel by pixel.

    Coverage is sampled at pixel centres in the silhouette's local frame, so
    a rotated or sheared shadow blurs along its own axes. Runs that come out
    at full alpha go through `fill_span` together; only the soft band
    composites pixel by pixel.
    """
    var shape = BlurredSilhouette(sh, local_stroke_thickness(sh, m, scale))
    var reach = shape.reach()
    var b = device_bounds(
        m,
        shape.x0 - reach,
        shape.y0 - reach,
        shape.x1 + reach,
        shape.y1 + reach,
        s.width,
        s.height,
    )
    var minv = inverse(m)
    var color = sh.paint.shadow_color
    var full = Float64(color.a)
    for py in range(b[1], b[3]):
        var row = py * s.width * 4
        var run = -1
        for px in range(b[0], b[2]):
            var l = mat_apply(minv, Float64(px) + 0.5, Float64(py) + 0.5)
            var a = Int(full * shape.coverage(l[0], l[1]) + 0.5)
            if a >= Int(color.a):
                if run < 0:
                    run = px
                continue
            if run >= 0:
                fill_span(s, row + run * 4, px - run, color)
                run = -1
            if a > 0:
                blend(
                    s, row + px * 4, Color(color.r, color.g, color.b, UInt8(a))
                )
        if run >= 0:
            fill_span(s, row + run * 4, b[2] - run, color)


def _inset_shadow[
    o: Origin[mut=True]
](
    s: Surface[o],
    c: RenderCommand,
    scale: Float64,
    m: Matrix[3, 3],
    sm: Matrix[3, 3],
    blur: Int,
):
    """Paint `c`'s inset shadow over it: the shadow colour wherever the
    silhouette — the interior moved by the offset (`sm`) and shrunk by the
    spread — does not cover, clipped to the interior (`m`).

    Tested at pixel centres like `_blurred_shadow`, since the alpha is
    per pixel anyway wherever the shadow is soft; a `blur` of 0 cuts the
    silhouette hard. Full-alpha runs go through `fill_span` together.
    """
    var interior = inset_interior(c, local_stroke_thickness(c, m, scale))
    if interior.empty:
        return
    var cut = interior.shrunk(c.paint.shadow_spread)
    var soft = BlurredSilhouette(cut, c.paint.shadow_blur)
    var lb = interior.bounds()
    var b = device_bounds(m, lb[0], lb[1], lb[2], lb[3], s.width, s.height)
    var minv = inverse(m)
    var sminv = inverse(sm)
    var color = c.paint.shadow_color
    var full = Float64(color.a)
    for py in range(b[1], b[3]):
        var row = py * s.width * 4
        var run = -1
        for px in range(b[0], b[2]):
            var x = Float64(px) + 0.5
            var y = Float64(py) + 0.5
            var a = 0
            var l = mat_apply(minv, x, y)
            if interior.contains(l[0], l[1]):
                var ls = mat_apply(sminv, x, y)
                var cov: Float64
                if blur > 0:
                    cov = soft.coverage(ls[0], ls[1])
                else:
                    cov = 1.0 if cut.contains(ls[0], ls[1]) else 0.0
                a = Int(full * (1.0 - cov) + 0.5)
            if a >= Int(color.a):
                if run < 0:
                    run = px
                continue
            if run >= 0:
                fill_span(s, row + run * 4, px - run, color)
                run = -1
            if a > 0:
                blend(
                    s, row + px * 4, Color(color.r, color.g, color.b, UInt8(a))
                )
        if run >= 0:
            fill_span(s, row + run * 4, b[2] - run, color)


def _circle_row_span(
    pcx: Float64, dy: Float64, rad2: Float64, lo_bound: Int, hi_bound: Int
) -> Tuple[Int, Int]:
    """Integer columns in `[lo_bound, hi_bound)` where `(col - pcx)**2 + dy**2
    <= rad2` — the same per-column test `_circle`'s uniform branch used to
    make one column at a time. `sqrt` only seeds the bounds; each side is
    then walked outward while the exact same expression still passes and
    inward while it fails, which is what keeps this bit-exact with the
    per-pixel loop it replaces despite `sqrt` rounding differently than
    repeated multiplication. Returns an empty range (`lo > hi`) rather than
    raising when no column qualifies.
    """
    if lo_bound >= hi_bound:
        return (lo_bound, lo_bound - 1)
    var rem = rad2 - dy * dy
    if rem < 0.0:
        return (lo_bound, lo_bound - 1)
    var half = sqrt(rem)

    var lo = Int(pcx - half)
    while lo - 1 >= lo_bound:
        var dx = Float64(lo - 1) - pcx
        if dx * dx + dy * dy <= rad2:
            lo -= 1
        else:
            break
    while lo < hi_bound:
        var dx = Float64(lo) - pcx
        if dx * dx + dy * dy <= rad2:
            break
        lo += 1

    var hi = Int(pcx + half)
    while hi + 1 < hi_bound:
        var dx = Float64(hi + 1) - pcx
        if dx * dx + dy * dy <= rad2:
            hi += 1
        else:
            break
    while hi >= lo_bound:
        var dx = Float64(hi) - pcx
        if dx * dx + dy * dy <= rad2:
            break
        hi -= 1

    return (max(lo, lo_bound), min(hi, hi_bound - 1))


def _affine_row_span(
    v0: Float64,
    step: Float64,
    inv_step: Float64,
    col0: Int,
    lo: Float64,
    hi: Float64,
    col_lo: Int,
    col_hi: Int,
) -> Tuple[Int, Int]:
    """Integer columns in `[col_lo, col_hi)` where `lo <= v0 + (col -
    col0)*step <= hi` — one axis of the rotated rect's containment test,
    solved directly instead of walked pixel by pixel. `step` is one of the
    inverse matrix's two affine coefficients (`minv[0,0]` or `minv[1,0]`),
    constant for the whole shape (not just one row), so the caller passes
    its reciprocal `inv_step` precomputed once rather than paying a
    division on every row — `step` itself is still needed for the exact
    `== 0.0` test, since multiplying by an `inv_step` of `inf` would not
    reproduce it. `v0` is the local coordinate at column `col0` — a fixed
    reference column, independent of the `[col_lo, col_hi)` clip range,
    since a caller solving an inner span clips to the outer span's columns
    while `v0` still comes from the row's start. Returns an empty range
    (`lo > hi`) rather than raising when no column qualifies. Not required
    to be bit-exact with a per-pixel walk — see the non-uniform branches
    this feeds, whose exactness policy already accepts a rounded-endpoint
    edge.

    `step` is treated as zero below a small threshold, not just at exactly
    `0.0`: a composed matrix that is mathematically axis-aligned (e.g. a
    rotate/counter-rotate pair meant to cancel) still leaves a residual on
    the order of 1e-16 in `minv[0,0]`/`minv[1,0]` after floating-point matrix
    multiplication, which `uniform()` rejects. Dividing by that residual
    turns it into an inv_step of ~1e15, which amplifies the last bit of
    rounding noise in `step` into a huge, unstable `t0`/`t1` — different
    enough frame to frame under a continuously varying transform to make the
    solved span flicker between "whole row" and "nothing". A real rotation
    or shear is many orders of magnitude above this threshold, so treating
    smaller values as zero costs no legitimate case.
    """
    if col_lo >= col_hi:
        return (col_lo, col_lo - 1)
    if abs(step) < 1e-9:
        if v0 < lo or v0 > hi:
            return (col_lo, col_lo - 1)
        return (col_lo, col_hi - 1)
    var t0 = (lo - v0) * inv_step
    var t1 = (hi - v0) * inv_step
    var c_lo = min(t0, t1)
    var c_hi = max(t0, t1)
    var start = max(Int(ceil(c_lo)) + col0, col_lo)
    var end = min(Int(floor(c_hi)) + col0, col_hi - 1)
    return (start, end)


def _ellipse_row_span(
    a: Float64,
    b: Float64,
    c: Float64,
    inv_2a: Float64,
    col0: Int,
    col_lo: Int,
    col_hi: Int,
) -> Tuple[Int, Int]:
    """Integer columns in `[col_lo, col_hi)` where `a*t^2 + b*t + c <= 0`,
    `t = col - col0` — the rotated/sheared circle's per-row containment
    test, solved directly instead of walked pixel by pixel. Substituting the
    row's affine local-space coordinates (taken at reference column `col0`)
    into `dx^2 + dy^2 <= radius^2` turns it into this quadratic in `t`; `a`
    is `step_x^2 + step_y^2`, always positive for a non-degenerate
    transform and constant for the whole shape, so the caller passes
    `inv_2a = 1/(2a)` precomputed once instead of dividing by it on every
    row. The qualifying columns (if any) are the single interval between
    its two roots, offset back to absolute columns by `col0`. `col0` is
    independent of `[col_lo, col_hi)`, since a caller solving an inner span
    clips to the outer span's columns while the quadratic's coefficients
    still come from the row's start. Returns an empty range (`lo > hi`)
    when the row misses the shape entirely.

    `a` is treated as zero below a small threshold, mirroring
    `_affine_row_span`'s `step` guard — a composed matrix that is
    mathematically axis-aligned can still leave `step_x`/`step_y` as ~1e-16
    residuals rather than exact zero, and squaring them into `a` does not
    make them any less capable of sending `inv_2a` (computed by the caller
    as `1/(2a)`) to a huge, sign-unstable value. When `a` degenerates this
    way, `b` (built from the same tiny steps) degenerates with it, so
    solving the linear fallback would hit the identical blow-up — instead,
    since `c` is the implicit function's value already evaluated at the row's
    reference column `col0`, a negligible `a` means the row barely varies
    across its clip range at all, so `c`'s sign alone decides the whole run.
    """
    if col_lo >= col_hi:
        return (col_lo, col_lo - 1)
    if abs(a) < 1e-18:
        if c > 0.0:
            return (col_lo, col_lo - 1)
        return (col_lo, col_hi - 1)
    var disc = b * b - 4.0 * a * c
    if disc < 0.0:
        return (col_lo, col_lo - 1)
    var sq = sqrt(disc)
    var r0 = (-b - sq) * inv_2a
    var r1 = (-b + sq) * inv_2a
    var start = max(Int(ceil(r0)) + col0, col_lo)
    var end = min(Int(floor(r1)) + col0, col_hi - 1)
    return (start, end)


def _circle_arc_row[
    o: Origin[mut=True]
](
    s: Surface[o],
    row_off: Int,
    pcx: Float64,
    dy: Float64,
    pr2: Float64,
    pr_inner2: Float64,
    x0: Int,
    x1: Int,
    full_fill: Bool,
    stroke_visible: Bool,
    fill_enabled: Bool,
    fill_col: FillPaint,
    stroke_col: Color,
):
    """One row of a circle (or a rounded rect's corner quarter-disc,
    restricted to `[x0, x1)`), factored out of `_circle`'s own uniform
    branch so both call sites share one solve. `full_fill` and `pr_inner2`
    carry the caller's `pr_inner <= 0.0` degenerate case exactly as `_circle`
    already handled it — the whole span paints in *fill* colour, not
    stroke, when the stroke is too thick for the radius to leave a ring.
    A pure refactor for `_circle`'s own call site: same branches, same
    order, same colours.
    """
    var outer = _circle_row_span(pcx, dy, pr2, x0, x1)
    var ol = outer[0]
    var oh = outer[1]
    if ol > oh:
        return
    if full_fill:
        fill_span(s, (row_off + ol) * 4, oh - ol + 1, fill_col)
    elif stroke_visible:
        var inner = _circle_row_span(pcx, dy, pr_inner2, ol, oh + 1)
        var il = inner[0]
        var ih = inner[1]
        if il <= ih:
            if fill_enabled:
                fill_span(s, (row_off + il) * 4, ih - il + 1, fill_col)
            if il > ol:
                fill_span(s, (row_off + ol) * 4, il - ol, stroke_col)
            if ih < oh:
                fill_span(s, (row_off + ih + 1) * 4, oh - ih, stroke_col)
        else:
            fill_span(s, (row_off + ol) * 4, oh - ol + 1, stroke_col)


def _fillet_disc_row_span(
    a: Float64,
    inv_2a: Float64,
    step_x: Float64,
    step_y: Float64,
    A0: Float64,
    B0: Float64,
    cx: Float64,
    cy: Float64,
    r2: Float64,
    col0: Int,
    col_lo: Int,
    col_hi: Int,
) -> Tuple[Int, Int]:
    """`_ellipse_row_span` specialised to one fillet corner's circle, centred
    at `(cx, cy)` in local space rather than at the shape's own centre —
    `a`/`inv_2a` stay the caller's precomputed, transform-only constants."""
    var dx0 = A0 - cx
    var dy0 = B0 - cy
    var bcoef = 2.0 * (dx0 * step_x + dy0 * step_y)
    var c0 = dx0 * dx0 + dy0 * dy0 - r2
    return _ellipse_row_span(a, bcoef, c0, inv_2a, col0, col_lo, col_hi)


def _rounded_box_row(
    x: Float64,
    y: Float64,
    w: Float64,
    h: Float64,
    radius: Float64,
    yc: Float64,
    width: Int,
) -> Tuple[Int, Int]:
    """The columns `[lo, hi)` whose centres lie in the device box `[x, x+w)`
    x `[y, y+h)` with corners of `radius`, on the row whose centre is at
    `yc`, clamped to `[0, width)`; `hi <= lo` when it misses the row."""
    if w <= 0.0 or h <= 0.0 or yc < y or yc >= y + h:
        return (0, 0)
    var left = x
    var right = x + w
    var r = min(radius, min(w, h) / 2.0)
    var dy = 0.0
    if yc < y + r:
        dy = y + r - yc
    elif yc > y + h - r:
        dy = yc - (y + h - r)
    if dy > 0.0:
        var chord = sqrt(max(r * r - dy * dy, 0.0))
        left = x + r - chord
        right = x + w - r + chord
    return (
        max(Int(ceil(left - 0.5)), 0),
        min(Int(ceil(right - 0.5)), width),
    )


def _rounded_rect_row_span(
    A0: Float64,
    B0: Float64,
    col0: Int,
    step_x: Float64,
    step_y: Float64,
    inv_step_x: Float64,
    inv_step_y: Float64,
    a: Float64,
    inv_2a: Float64,
    lx0: Float64,
    ly0: Float64,
    lx1: Float64,
    ly1: Float64,
    r: Float64,
    r2: Float64,
    col_lo: Int,
    col_hi: Int,
) -> Tuple[Int, Int]:
    """One row's covered columns inside a rounded rect `[lx0,lx1] x
    [ly0,ly1]` with corner radius `r`, under a non-uniform transform.

    A rounded rect is convex, so a row's covered columns are always one
    interval — this finds it as the union of up to three column-contiguous
    sub-solves, ordered by local `y` (monotone in `col` for a fixed row):
    the bottom and top corner bands each solve a straight strip plus two
    fillet discs, the middle band solves the sharp rect's own x-range
    outright, and merging by min/max of endpoints is valid precisely
    because that union stays contiguous. `r <= 0` skips all of it for the
    plain two-axis rect test `_rect`'s sharp path already used.
    """
    if r <= 0.0:
        var xr = _affine_row_span(
            A0, step_x, inv_step_x, col0, lx0, lx1, col_lo, col_hi
        )
        var yr = _affine_row_span(
            B0, step_y, inv_step_y, col0, ly0, ly1, col_lo, col_hi
        )
        return (max(xr[0], yr[0]), min(xr[1], yr[1]))

    var y_bot = _affine_row_span(
        B0, step_y, inv_step_y, col0, ly0, ly0 + r, col_lo, col_hi
    )
    var y_mid = _affine_row_span(
        B0, step_y, inv_step_y, col0, ly0 + r, ly1 - r, col_lo, col_hi
    )
    var y_top = _affine_row_span(
        B0, step_y, inv_step_y, col0, ly1 - r, ly1, col_lo, col_hi
    )

    var lo = col_hi
    var hi = col_lo - 1

    if y_mid[0] <= y_mid[1]:
        var xr = _affine_row_span(
            A0, step_x, inv_step_x, col0, lx0, lx1, y_mid[0], y_mid[1] + 1
        )
        if xr[0] <= xr[1]:
            lo = min(lo, xr[0])
            hi = max(hi, xr[1])

    if y_bot[0] <= y_bot[1]:
        var run_lo = y_bot[0]
        var run_hi = y_bot[1] + 1
        var xr = _affine_row_span(
            A0, step_x, inv_step_x, col0, lx0 + r, lx1 - r, run_lo, run_hi
        )
        if xr[0] <= xr[1]:
            lo = min(lo, xr[0])
            hi = max(hi, xr[1])
        var dl = _fillet_disc_row_span(
            a,
            inv_2a,
            step_x,
            step_y,
            A0,
            B0,
            lx0 + r,
            ly0 + r,
            r2,
            col0,
            run_lo,
            run_hi,
        )
        if dl[0] <= dl[1]:
            lo = min(lo, dl[0])
            hi = max(hi, dl[1])
        var dr = _fillet_disc_row_span(
            a,
            inv_2a,
            step_x,
            step_y,
            A0,
            B0,
            lx1 - r,
            ly0 + r,
            r2,
            col0,
            run_lo,
            run_hi,
        )
        if dr[0] <= dr[1]:
            lo = min(lo, dr[0])
            hi = max(hi, dr[1])

    if y_top[0] <= y_top[1]:
        var run_lo = y_top[0]
        var run_hi = y_top[1] + 1
        var xr = _affine_row_span(
            A0, step_x, inv_step_x, col0, lx0 + r, lx1 - r, run_lo, run_hi
        )
        if xr[0] <= xr[1]:
            lo = min(lo, xr[0])
            hi = max(hi, xr[1])
        var dl = _fillet_disc_row_span(
            a,
            inv_2a,
            step_x,
            step_y,
            A0,
            B0,
            lx0 + r,
            ly1 - r,
            r2,
            col0,
            run_lo,
            run_hi,
        )
        if dl[0] <= dl[1]:
            lo = min(lo, dl[0])
            hi = max(hi, dl[1])
        var dr = _fillet_disc_row_span(
            a,
            inv_2a,
            step_x,
            step_y,
            A0,
            B0,
            lx1 - r,
            ly1 - r,
            r2,
            col0,
            run_lo,
            run_hi,
        )
        if dr[0] <= dr[1]:
            lo = min(lo, dr[0])
            hi = max(hi, dr[1])

    return (lo, hi)


struct CpuReplay(Movable):
    """The CPU replay: recorded commands rasterised onto a `Surface`.

    Holds only its own working memory and the CPU's image shadow cache; what
    a replay reads beside the commands — the images and glyph cache, the
    frame's clips, the antialiasing level — is handed to `replay` by the
    `Backend`, as `GLRenderer.render` is handed the same. Every capture and
    pixel read replays here too, whichever backend presents the frame.
    """

    var antialiasing: Antialiasing
    """The level the replay in progress runs at, set by `replay`."""
    var _coverage_runs: List[Int]
    var _coverage: CoverageScratch
    """`_shape`'s working memory, kept so a frame of antialiased shapes
    allocates once."""
    var shadow_masks: Dict[Int, BlurredMask]
    """Blurred image silhouettes, keyed by `shadow_mask_key`: an image's
    shadow is blurred once per image, device size and blur, not per frame."""

    def __init__(out self):
        self.antialiasing = Antialiasing.OFF
        self._coverage_runs = List[Int]()
        self._coverage = CoverageScratch()
        self.shadow_masks = Dict[Int, BlurredMask]()

    def replay[
        o: Origin[mut=True]
    ](
        mut self,
        mut res: Resources,
        s: Surface[o],
        cmds: List[RenderCommand],
        clips: List[_Clip],
        antialiasing: Antialiasing,
        scale: Float64,
        pre: Matrix[3, 3] = identity[3](),
        skip_letterbox: Bool = False,
        skip_clear: Bool = False,
    ) raises:
        """Render `cmds` onto `s`, in order.

        `scale` is the frame's autoscale factor — the fallback pixel scale for
        commands whose transform is not uniform. It is constant for a frame, so
        it travels here rather than on every command.

        `pre` multiplies every command's transform on the left, and exists
        because a capture replays a frame whose commands were recorded against
        a *different* mapping: `Canvas` bakes the window's base matrix into
        each one, so writing that same frame into a design-sized buffer needs
        `capture_base @ window_base_inverse` in front of it. Identity on the
        live path, which is therefore unchanged.

        `skip_letterbox` drops the bars, for a capture that is bar-free by
        contract; `skip_clear` drops every clear too, for one with a
        transparent background.

        `res` holds the images and the glyph cache the commands draw from,
        `clips` the frame's `canvas.clip` levels their `clip` ids index, and
        `antialiasing` the level to replay at.

        Each of the frame's clips becomes rows first, all of them before any
        command, so no row table moves while a surface points into it.
        """
        self.antialiasing = antialiasing
        var rows = self._clip_rows(res, clips, s, scale, pre)
        for ref c in cmds:
            var skipped = (
                skip_letterbox and c.payload.isa[LetterboxPayload]()
            ) or (skip_clear and c.payload.isa[ClearPayload]())
            if not skipped:
                if c.clip == 0:
                    self._one(res, s, c, scale, pre)
                else:
                    var clip = Pointer(to=rows[c.clip - 1])
                    self._one(
                        res,
                        s._with_clip(
                            clip.unsafe_origin_cast[MutUntrackedOrigin]()
                        ),
                        c,
                        scale,
                        pre,
                    )
        _ = rows^

    def _clip_rows[
        o: Origin[mut=True]
    ](
        mut self,
        mut res: Resources,
        clips: List[_Clip],
        s: Surface[o],
        scale: Float64,
        pre: Matrix[3, 3],
    ) raises -> List[_ClipRows]:
        """Every clip of the frame as the rows of `s` it keeps, in id order.

        Each region is replayed through `_one` onto a recording surface
        `grid` times finer, as `_shape` antialiases a shape, so its rows keep
        exactly the coverage the same shape would paint, and then
        intersected with its parent's, which comes earlier.
        """
        var grid = self.antialiasing._cpu_grid()
        var g = Float64(grid)
        var out = List[_ClipRows](capacity=len(clips))
        for i in range(len(clips)):
            var runs = List[Int]()
            var recorder = Pointer(to=runs).unsafe_origin_cast[
                MutUntrackedOrigin
            ]()
            var fine = Surface[o](
                s.px, s.width * grid, s.height * grid
            )._recording_into(recorder)
            var region = clips[i].region.copy()
            self._one(res, fine, region, scale * g, mat_scale(g) @ pre)
            var own = _ClipRows(runs, s.width, s.height, clips[i].invert, grid)
            _ = runs^
            var parent = clips[i].parent
            if parent == 0:
                out.append(own^)
            else:
                out.append(own.intersect(out[parent - 1]))
        return out^

    def _one[
        o: Origin[mut=True]
    ](
        mut self,
        mut res: Resources,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        pre: Matrix[3, 3],
    ) raises:
        """Replay `c` onto `s`, its stroke aligned first: the one place, so
        its shadows and the shape itself see the same geometry. Copies `c`
        only when there is something to align."""
        var offset = stroke_offset(c, pre @ c.transform, scale)
        if offset > 0.0:
            self._replay(res, s, aligned_stroke(c, offset), scale, pre)
        else:
            self._replay(res, s, c, scale, pre)

    def _replay[
        o: Origin[mut=True]
    ](
        mut self,
        mut res: Resources,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        pre: Matrix[3, 3],
    ) raises:
        # The one place the pre-matrix is composed, so no per-kind helper has
        # to remember to do it.
        var m = pre @ c.transform
        # Likewise the blend mode: every raster loop reads it off the surface.
        var t = s._with_blend_mode(c.paint.blend_mode)
        # An outer shadow is the command's silhouette, replayed under it
        # through this same dispatch.
        if casts_outer_shadow(c):
            var sh = shadow_command(c, scale)
            var sm = pre @ sh.transform
            # The blur in whole device pixels; see `_ensure_glyph`. Text is
            # blurred where it is laid out, at its own scale.
            var sf = text_pixel_scale(sm, scale) if c.payload.isa[
                TextPayload
            ]() else pixel_scale(sm, scale)
            var blur = Int(c.paint.shadow_blur * sf + 0.5)
            if blur == 0:
                self._one(res, s, sh, scale, pre)
            elif blurs_analytically(c):
                _blurred_shadow(t, sh, scale, sm)
            elif c.payload.isa[TextPayload]():
                self._text(res, t, sh, scale, sm, blur)
            elif c.payload.isa[ImagePayload]():
                self._image_shadow(res, t, sh, scale, sm, blur)
            elif is_lowered(c):
                var placed = shape_shadow_mask(sh, sm, scale, blur)
                blit_alpha(
                    t,
                    placed.mask.pixels.unsafe_ptr(),
                    placed.mask.width,
                    placed.mask.height,
                    placed.x,
                    placed.y,
                    c.paint.shadow_color,
                )
        if c.payload.isa[ClearPayload]():
            if c.paint.fill_gradient:
                var paint = _fill_paint(c, m)
                for row in range(t.height):
                    fill_span(t, row * t.width * 4, t.width, paint)
            else:
                fill_all(t, c.paint.fill_color)
        elif c.is_shape():
            self._shape(t, c, scale, m)
        elif c.payload.isa[ImagePayload]():
            self._image(res, t, c, scale, m)
        elif c.payload.isa[TextPayload]():
            self._text(res, t, c, scale, m)
        elif c.payload.isa[LetterboxPayload]():
            self._letterbox(t, c)
        # An inset shadow lies over the command, inside its stroke.
        if casts_inset_shadow(c):
            var sm = pre @ shadow_transform(c, scale)
            var blur = Int(c.paint.shadow_blur * pixel_scale(sm, scale) + 0.5)
            _inset_shadow(t, c, scale, m, sm, blur)

    def _shape[
        o: Origin[mut=True]
    ](
        mut self,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        m: Matrix[3, 3],
    ) raises:
        """Draw the shape `c`, antialiased at `antialiasing`.

        Antialiased, the shape is drawn by its own rasteriser onto a
        recording surface `grid` times finer, its device mapping and pixel
        scale both multiplied by `grid`, and the runs it records composited
        as coverage (`_coverage.mojo`). A recording surface is a clip region
        being rasterised, already on the grid by `_clip_rows`, so it records
        the shape's runs as they are.
        """
        var grid = self.antialiasing._cpu_grid()
        if grid == 1 or s._recording:
            self._shape_pixels(s, c, scale, m)
            return
        var runs = self._coverage_runs^
        self._coverage_runs = List[Int]()
        runs.clear()
        var recorder = Pointer(to=runs).unsafe_origin_cast[MutUntrackedOrigin]()
        var fine = Surface[o](
            s.px, s.width * grid, s.height * grid
        )._recording_into(recorder)
        var g = Float64(grid)
        self._shape_pixels(fine, c, scale * g, mat_scale(g) @ m)
        var scratch = self._coverage^
        self._coverage = CoverageScratch()
        composite_coverage(s, runs, grid, _fill_paint(c, m), scratch)
        self._coverage = scratch^
        self._coverage_runs = runs^

    def _shape_pixels[
        o: Origin[mut=True]
    ](
        mut self,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        m: Matrix[3, 3],
    ) raises:
        """Draw the shape `c` by pixel centres: a rectangle or a circle by
        its own rasteriser, a plain triangle in one pass, every other kind
        as the pieces `shape_pieces` cuts it into."""
        if c.payload.isa[RectPayload]():
            self._rect(s, c, scale, m)
        elif c.payload.isa[CirclePayload]():
            self._circle(s, c, scale, m)
        elif is_plain_triangle(c):
            if c.paint._fill_visible():
                ref g = c.payload[TrianglePayload].corners
                var p1 = mat_apply(m, g[0], g[1])
                var p2 = mat_apply(m, g[2], g[3])
                var p3 = mat_apply(m, g[4], g[5])
                fill_triangle(
                    s,
                    p1[0],
                    p1[1],
                    p2[0],
                    p2[1],
                    p3[0],
                    p3[1],
                    _fill_paint(c, m),
                )
        else:
            var pieces = shape_pieces(c, m, scale)
            if pieces.has_fill():
                fill_pieces(
                    s,
                    pieces.fill_quads,
                    pieces.fill_polygons,
                    _fill_paint(c, m),
                )
            if pieces.has_stroke():
                fill_pieces(
                    s,
                    pieces.stroke_quads,
                    pieces.stroke_polygons,
                    c.paint.stroke_color,
                )

    def _rect[
        o: Origin[mut=True]
    ](
        mut self,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        m: Matrix[3, 3],
    ):
        var W = s.width
        ref rect = c.payload[RectPayload]
        var x = rect.center.x
        var y = rect.center.y
        var lx0 = x - rect.w / 2.0
        var ly0 = y - rect.h / 2.0
        var lx1 = x + rect.w / 2.0
        var ly1 = y + rect.h / 2.0

        var r_local = rect_corner_radius(rect.corner_radius, rect.w, rect.h)

        if uniform(m) and r_local <= 0.0:
            # Axis-aligned and sharp: map the two opposite corners and order
            # them, since the y flip in the base mapping sends the smaller
            # world y to the larger pixel row. Rounded corners take the
            # general path below, which splits each row into fill and stroke
            # so a translucent rectangle composites once.
            var p0 = mat_apply(m, lx0, ly0)
            var p1 = mat_apply(m, lx1, ly1)
            var x0 = Int(min(p0[0], p1[0]))
            var y0 = Int(min(p0[1], p1[1]))
            var iw = Int(abs(p1[0] - p0[0]))
            var ih = Int(abs(p1[1] - p0[1]))
            # The stroke is an inset ring, so the fill stops where it starts.
            var sw = 0
            if c.paint._stroke_visible():
                sw = stroke_thickness_px(c.paint, m, scale)
            if c.paint._fill_visible():
                fill_pixels(
                    s,
                    x0 + sw,
                    y0 + sw,
                    x0 + iw - sw,
                    y0 + ih - sw,
                    _fill_paint(c, m),
                )
            if sw > 0:
                var sc = c.paint.stroke_color
                fill_pixels(s, x0, y0, x0 + iw, y0 + sw, sc)
                fill_pixels(s, x0, y0 + ih - sw, x0 + iw, y0 + ih, sc)
                fill_pixels(s, x0, y0 + sw, x0 + sw, y0 + ih - sw, sc)
                fill_pixels(s, x0 + iw - sw, y0 + sw, x0 + iw, y0 + ih - sw, sc)
        elif uniform(m):
            # Axis-aligned and rounded: per row, the outer rounded span and
            # the inner one (inset by the stroke, its corners `sw` smaller
            # and sharp once the stroke is wider than they are); stroke
            # either side of the inner span, fill inside it, so a
            # translucent rectangle composites once.
            var p0 = mat_apply(m, lx0, ly0)
            var p1 = mat_apply(m, lx1, ly1)
            var x0 = Float64(Int(min(p0[0], p1[0])))
            var y0 = Float64(Int(min(p0[1], p1[1])))
            var iw = Float64(Int(abs(p1[0] - p0[0])))
            var ih = Float64(Int(abs(p1[1] - p0[1])))
            var pr = r_local * pixel_scale(m, scale)
            var fill_visible = c.paint._fill_visible()
            var sw = 0.0
            if c.paint._stroke_visible():
                sw = Float64(stroke_thickness_px(c.paint, m, scale))
            var fill_col = _fill_paint(c, m)
            var stroke_col = c.paint.stroke_color
            for row in range(max(Int(y0), 0), min(Int(y0 + ih), s.height)):
                var yc = Float64(row) + 0.5
                var outer = _rounded_box_row(x0, y0, iw, ih, pr, yc, W)
                if outer[1] <= outer[0]:
                    continue
                var row_off = row * W
                if sw == 0.0:
                    if fill_visible:
                        fill_span(
                            s,
                            (row_off + outer[0]) * 4,
                            outer[1] - outer[0],
                            fill_col,
                        )
                    continue
                var inner = _rounded_box_row(
                    x0 + sw,
                    y0 + sw,
                    iw - 2.0 * sw,
                    ih - 2.0 * sw,
                    max(pr - sw, 0.0),
                    yc,
                    W,
                )
                if inner[1] <= inner[0]:
                    fill_span(
                        s,
                        (row_off + outer[0]) * 4,
                        outer[1] - outer[0],
                        stroke_col,
                    )
                    continue
                if inner[0] > outer[0]:
                    fill_span(
                        s,
                        (row_off + outer[0]) * 4,
                        inner[0] - outer[0],
                        stroke_col,
                    )
                if fill_visible:
                    fill_span(
                        s,
                        (row_off + inner[0]) * 4,
                        inner[1] - inner[0],
                        fill_col,
                    )
                if outer[1] > inner[1]:
                    fill_span(
                        s,
                        (row_off + inner[1]) * 4,
                        outer[1] - inner[1],
                        stroke_col,
                    )
        else:
            # Rotated/sheared: the inverse mapping is still affine (no
            # perspective row), so a device column maps to local space by
            # `local0 + col * (minv[0,0], minv[1,0])` — linear in `col`. The
            # rect's containment test is two independent range checks (`lx`
            # inside `[lx0,lx1]`, `ly` inside `[ly0,ly1]`), and each is linear
            # in `col`, so `_affine_row_span` solves the qualifying column
            # range directly per axis instead of walking pixels; the row's
            # covered run is their intersection. A stroke splits that run
            # into an inner fill span (same solve, shrunk by the stroke
            # width) and up to two stroke spans flanking it, mirroring the
            # uniform circle branch below. Not bit-exact with the old
            # per-pixel test — an edge pixel may land one column off — which
            # this phase's exactness policy accepts and `test_gl_parity.mojo`
            # gates.
            var minv = inverse(m)
            var b = device_bounds(m, lx0, ly0, lx1, ly1, s.width, s.height)
            var sw_f = c.paint.stroke_thickness
            var step_x = minv[0, 0]
            var step_y = minv[1, 0]
            var inv_step_x = 1.0 / step_x if step_x != 0.0 else 0.0
            var inv_step_y = 1.0 / step_y if step_y != 0.0 else 0.0
            if r_local <= 0.0:
                var fill_enabled = c.paint._fill_visible()
                var stroke_enabled = c.paint._stroke_visible()
                var fill_col = _fill_paint(c, m)
                var stroke_col = c.paint.stroke_color
                for row in range(b[1], b[3]):
                    var local0 = mat_apply(
                        minv, Float64(b[0]) + 0.5, Float64(row) + 0.5
                    )
                    var A = local0[0]
                    var B = local0[1]
                    var row_off = row * W
                    var xr = _affine_row_span(
                        A, step_x, inv_step_x, b[0], lx0, lx1, b[0], b[2]
                    )
                    var yr = _affine_row_span(
                        B, step_y, inv_step_y, b[0], ly0, ly1, b[0], b[2]
                    )
                    var outer_lo = max(xr[0], yr[0])
                    var outer_hi = min(xr[1], yr[1])
                    if outer_lo > outer_hi:
                        continue
                    if not stroke_enabled:
                        if fill_enabled:
                            fill_span(
                                s,
                                (row_off + outer_lo) * 4,
                                outer_hi - outer_lo + 1,
                                fill_col,
                            )
                        continue
                    var xi = _affine_row_span(
                        A,
                        step_x,
                        inv_step_x,
                        b[0],
                        lx0 + sw_f,
                        lx1 - sw_f,
                        outer_lo,
                        outer_hi + 1,
                    )
                    var yi = _affine_row_span(
                        B,
                        step_y,
                        inv_step_y,
                        b[0],
                        ly0 + sw_f,
                        ly1 - sw_f,
                        outer_lo,
                        outer_hi + 1,
                    )
                    var inner_lo = max(xi[0], yi[0])
                    var inner_hi = min(xi[1], yi[1])
                    if inner_lo <= inner_hi:
                        if fill_enabled:
                            fill_span(
                                s,
                                (row_off + inner_lo) * 4,
                                inner_hi - inner_lo + 1,
                                fill_col,
                            )
                        if inner_lo > outer_lo:
                            fill_span(
                                s,
                                (row_off + outer_lo) * 4,
                                inner_lo - outer_lo,
                                stroke_col,
                            )
                        if inner_hi < outer_hi:
                            fill_span(
                                s,
                                (row_off + inner_hi + 1) * 4,
                                outer_hi - inner_hi,
                                stroke_col,
                            )
                    else:
                        fill_span(
                            s,
                            (row_off + outer_lo) * 4,
                            outer_hi - outer_lo + 1,
                            stroke_col,
                        )
            else:
                # Same outer/inner span shape as the sharp path above, but
                # both spans come from `_rounded_rect_row_span` instead of a
                # plain two-axis intersection. The inner (fill) shape is
                # inset by the stroke width on both the rect and its
                # radius; when that leaves the radius at or below zero,
                # `_rounded_rect_row_span`'s own `r <= 0` branch falls back
                # to the sharp two-axis test, so a corner too thick for its
                # stroke gets a sharp inner silhouette rather than a
                # negative radius.
                var fill_enabled = c.paint._fill_visible()
                var stroke_enabled = c.paint._stroke_visible()
                var fill_col = _fill_paint(c, m)
                var stroke_col = c.paint.stroke_color
                var r2 = r_local * r_local
                var a = step_x * step_x + step_y * step_y
                var inv_2a = 1.0 / (2.0 * a) if abs(a) >= 1e-18 else 0.0
                var inner_r = r_local - sw_f
                var inner_r2 = inner_r * inner_r if inner_r > 0.0 else 0.0
                for row in range(b[1], b[3]):
                    var local0 = mat_apply(
                        minv, Float64(b[0]) + 0.5, Float64(row) + 0.5
                    )
                    var A0 = local0[0]
                    var B0 = local0[1]
                    var row_off = row * W
                    var outer = _rounded_rect_row_span(
                        A0,
                        B0,
                        b[0],
                        step_x,
                        step_y,
                        inv_step_x,
                        inv_step_y,
                        a,
                        inv_2a,
                        lx0,
                        ly0,
                        lx1,
                        ly1,
                        r_local,
                        r2,
                        b[0],
                        b[2],
                    )
                    var outer_lo = outer[0]
                    var outer_hi = outer[1]
                    if outer_lo > outer_hi:
                        continue
                    if not stroke_enabled:
                        if fill_enabled:
                            fill_span(
                                s,
                                (row_off + outer_lo) * 4,
                                outer_hi - outer_lo + 1,
                                fill_col,
                            )
                        continue
                    var inner = _rounded_rect_row_span(
                        A0,
                        B0,
                        b[0],
                        step_x,
                        step_y,
                        inv_step_x,
                        inv_step_y,
                        a,
                        inv_2a,
                        lx0 + sw_f,
                        ly0 + sw_f,
                        lx1 - sw_f,
                        ly1 - sw_f,
                        inner_r,
                        inner_r2,
                        outer_lo,
                        outer_hi + 1,
                    )
                    var inner_lo = inner[0]
                    var inner_hi = inner[1]
                    if inner_lo <= inner_hi:
                        if fill_enabled:
                            fill_span(
                                s,
                                (row_off + inner_lo) * 4,
                                inner_hi - inner_lo + 1,
                                fill_col,
                            )
                        if inner_lo > outer_lo:
                            fill_span(
                                s,
                                (row_off + outer_lo) * 4,
                                inner_lo - outer_lo,
                                stroke_col,
                            )
                        if inner_hi < outer_hi:
                            fill_span(
                                s,
                                (row_off + inner_hi + 1) * 4,
                                outer_hi - inner_hi,
                                stroke_col,
                            )
                    else:
                        fill_span(
                            s,
                            (row_off + outer_lo) * 4,
                            outer_hi - outer_lo + 1,
                            stroke_col,
                        )

    def _circle[
        o: Origin[mut=True]
    ](
        mut self,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        m: Matrix[3, 3],
    ):
        var W = s.width
        var H = s.height
        ref circle = c.payload[CirclePayload]
        var cx = circle.center.x
        var cy = circle.center.y
        var r = circle.r
        var r2 = r * r
        var r_inner = r - c.paint.stroke_thickness
        var r_inner2 = r_inner * r_inner

        if uniform(m):
            # A uniform scale keeps a circle a circle, so it stays a distance
            # test — just in pixels rather than world units.
            var p = mat_apply(m, cx, cy)
            # Pixel centres sit at +0.5, so moving the centre back by half a
            # pixel lets the row spans test integer columns and rows.
            var pcx = p[0] - 0.5
            var pcy = p[1] - 0.5
            var pr = r * pixel_scale(m, scale)
            var pr2 = pr * pr
            var pr_inner = pr - Float64(stroke_thickness_px(c.paint, m, scale))
            var pr_inner2 = pr_inner * pr_inner
            var x0 = max(Int(pcx - pr), 0)
            var y0 = max(Int(pcy - pr), 0)
            var x1 = min(Int(pcx + pr) + 1, W)
            var y1 = min(Int(pcy + pr) + 1, H)
            # Whether a row's *entire* outer span is fill, with no stroke ever
            # rendered — matches the per-pixel `if`'s "or pr_inner <= 0.0" arm,
            # which shortcuts to true regardless of `d2` and so never leaves
            # the `elif` reachable.
            var full_fill = c.paint._fill_visible() and (
                not c.paint._stroke_visible() or pr_inner <= 0.0
            )
            var fill_enabled = c.paint._fill_visible()
            var stroke_enabled = c.paint._stroke_visible()
            var fill_col = _fill_paint(c, m)
            var stroke_col = c.paint.stroke_color
            for row in range(y0, y1):
                var dy = Float64(row) - pcy
                _circle_arc_row(
                    s,
                    row * W,
                    pcx,
                    dy,
                    pr2,
                    pr_inner2,
                    x0,
                    x1,
                    full_fill,
                    stroke_enabled,
                    fill_enabled,
                    fill_col,
                    stroke_col,
                )
        else:
            # Same trick as the rotated rect branch above, adapted to a
            # quadratic: a device column maps to local space by `local0 +
            # col * (step_x, step_y)`, so substituting into `dx^2 + dy^2 <=
            # r^2` turns the row's containment test into `a*col^2 + b*col +
            # c <= 0` with `a = step_x^2 + step_y^2` constant across the
            # whole shape. `_ellipse_row_span` solves that directly instead
            # of walking pixels; stroke handling mirrors the uniform branch
            # above (outer span, then a shrunk inner span for the fill,
            # flanked by up to two stroke spans). Not bit-exact with the old
            # per-pixel walk, which this phase's exactness policy accepts.
            var minv = inverse(m)
            var b = device_bounds(m, cx - r, cy - r, cx + r, cy + r, W, H)
            var step_x = minv[0, 0]
            var step_y = minv[1, 0]
            var fill_enabled = c.paint._fill_visible()
            var stroke_enabled = c.paint._stroke_visible()
            var fill_col = _fill_paint(c, m)
            var stroke_col = c.paint.stroke_color
            var full_fill = not stroke_enabled or r_inner <= 0.0
            var a = step_x * step_x + step_y * step_y
            var inv_2a = 1.0 / (2.0 * a)
            for row in range(b[1], b[3]):
                var local0 = mat_apply(
                    minv, Float64(b[0]) + 0.5, Float64(row) + 0.5
                )
                var dx0 = local0[0] - cx
                var dy0 = local0[1] - cy
                var row_off = row * W
                var bcoef = 2.0 * (dx0 * step_x + dy0 * step_y)
                var c_outer = dx0 * dx0 + dy0 * dy0 - r2
                var outer = _ellipse_row_span(
                    a, bcoef, c_outer, inv_2a, b[0], b[0], b[2]
                )
                var ol = outer[0]
                var oh = outer[1]
                if ol > oh:
                    continue
                if full_fill:
                    if fill_enabled:
                        fill_span(s, (row_off + ol) * 4, oh - ol + 1, fill_col)
                    continue
                var c_inner = dx0 * dx0 + dy0 * dy0 - r_inner2
                var inner = _ellipse_row_span(
                    a, bcoef, c_inner, inv_2a, b[0], ol, oh + 1
                )
                var il = inner[0]
                var ih = inner[1]
                if il <= ih:
                    if fill_enabled:
                        fill_span(s, (row_off + il) * 4, ih - il + 1, fill_col)
                    if il > ol:
                        fill_span(s, (row_off + ol) * 4, il - ol, stroke_col)
                    if ih < oh:
                        fill_span(
                            s, (row_off + ih + 1) * 4, oh - ih, stroke_col
                        )
                else:
                    fill_span(s, (row_off + ol) * 4, oh - ol + 1, stroke_col)

    def _image[
        o: Origin[mut=True]
    ](
        mut self,
        mut res: Resources,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        m: Matrix[3, 3],
    ) raises:
        ref image = c.payload[ImagePayload]
        if image.image not in res.images:
            return
        # Bound by reference so the pixels stay in the cache rather than being
        # copied out of it once per render.
        ref img = res.images[image.image]
        var silhouette = Optional(
            c.paint.fill_color
        ) if image.silhouette else None
        if not upright(m):
            blit_image_mapped(
                s,
                img.pixels[].unsafe_ptr(),
                img.width,
                img.height,
                image_mapping(
                    m,
                    image.center.x,
                    image.center.y,
                    image.w,
                    image.h,
                    img.width,
                    img.height,
                ),
                silhouette,
                image.tint,
                self.antialiasing._cpu_grid(),
            )
            return
        var r = upright_rect(
            m, image.center.x, image.center.y, image.w, image.h
        )
        blit_image(
            s,
            img.pixels[].unsafe_ptr(),
            img.width,
            img.height,
            r.x,
            r.y,
            r.width,
            r.height,
            silhouette,
            image.tint,
        )

    def _image_shadow[
        o: Origin[mut=True]
    ](
        mut self,
        mut res: Resources,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        m: Matrix[3, 3],
        blur: Int,
    ) raises:
        """The silhouette command `c` blurred by `blur` device pixels, from
        a cached mask laid over the same destination rect `_image` uses —
        or, under a transform that turns the image, a mask built for it."""
        ref image = c.payload[ImagePayload]
        if image.image not in res.images:
            return
        if not upright(m):
            var placed = image_shadow_mask(
                c,
                m,
                res.images[image.image].pixels[].unsafe_ptr(),
                blur,
            )
            blit_alpha(
                s,
                placed.mask.pixels.unsafe_ptr(),
                placed.mask.width,
                placed.mask.height,
                placed.x,
                placed.y,
                c.paint.fill_color,
            )
            return
        var r = upright_rect(
            m, image.center.x, image.center.y, image.w, image.h
        )
        var key = shadow_mask_key(image.image, r.width, r.height, blur)
        if key not in self.shadow_masks:
            if len(self.shadow_masks) >= SHADOW_MASK_LIMIT:
                self.shadow_masks.clear()
            ref img = res.images[image.image]
            self.shadow_masks[key] = blur_image_alpha(
                img.pixels[].unsafe_ptr(),
                img.width,
                img.height,
                r.width,
                r.height,
                Float64(blur) / 2.0,
            )
        ref mask = self.shadow_masks[key]
        blit_alpha(
            s,
            mask.pixels.unsafe_ptr(),
            mask.width,
            mask.height,
            r.x - mask.pad,
            r.y - mask.pad,
            c.paint.fill_color,
        )

    def _text[
        o: Origin[mut=True]
    ](
        mut self,
        mut res: Resources,
        s: Surface[o],
        c: RenderCommand,
        scale: Float64,
        m: Matrix[3, 3],
        blur: Int = 0,
    ) raises:
        # Upright, only the anchor is mapped and the layout happens in pixel
        # space; otherwise the upright layout is mapped glyph by glyph.
        # `canvas.text` already skips recording when `text_color` is fully
        # transparent; text has no other visibility gate (fill is unrelated).
        var sf = text_pixel_scale(m, scale)
        ref text = c.payload[TextPayload]
        if text_upright(m):
            var p = mat_apply(m, text.position.x, text.position.y)
            res.text[].render(s, text.text, p[0], p[1], text.style[], sf, blur)
        else:
            res.text[].render_mapped(
                s,
                text.text,
                glyph_transform(m, text.position.x, text.position.y, sf),
                text.style[],
                sf,
                blur,
            )

    def _letterbox[
        o: Origin[mut=True]
    ](mut self, s: Surface[o], c: RenderCommand):
        var W = s.width
        var H = s.height
        ref bars = c.payload[LetterboxPayload]
        var cx0 = Int(bars.x0)
        var cy0 = Int(bars.y0)
        var cx1 = Int(bars.x1)
        var cy1 = Int(bars.y1)
        var col = c.paint.fill_color
        if cy0 > 0:
            fill_pixels(s, 0, 0, W, cy0, col)
        if cy1 < H:
            fill_pixels(s, 0, cy1, W, H, col)
        if cx0 > 0:
            fill_pixels(s, 0, cy0, cx0, cy1, col)
        if cx1 < W:
            fill_pixels(s, cx1, cy0, W, cy1, col)
