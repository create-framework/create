"""Fill and stroke geometry for sectors, shared by both replays.

A sector is tiled in *device* space at replay into convex quads — a fan
triangle is a quad with its first corner repeated — and both backends fill
those same quads, the CPU through `fill_quad` and the GPU as vertices,
which is what keeps them in parity. Neighbouring quads share their corners
exactly, so under `fill_quad`'s half-open rule a translucent sector
composites once everywhere, fill and stroke together.

The stroke is an inset band, as a circle's is: the fill stops where the
stroke starts, `stroke_thickness` inside every edge. The tiling walks the
sweep in thin wedges around the tip, and along each wedge's rays the sector
is one stretch of distances from the tip: the fill is the stretch of the
sector eroded by the stroke, the stroke what lies either side of it.

A shadow's spread offsets the whole sector first (its `grow`, zero for a
render call). Growing it keeps it one stretch per ray — a sector grown by a
disc is still star-shaped about its tip — but reaches into the missing
wedge too, round the tip and the arc's ends, so the walk goes all the way
round.
"""

from std.math import asin, atan, atan2, cos, max, min, sin, sqrt
from create.math import PI, TAU

from create.geometry.geometry import _normalized_sweep
from create.math.matrix import Matrix, _apply as mat_apply
from create.math.point2d import Point2D

from ._command import RenderCommand, SectorPayload
from ._pieces import Pieces
from ._tessellate import _arc_segments
from ._transform import stroke_thickness_px, pixel_scale


def sector_quads(c: RenderCommand, m: Matrix[3, 3], scale: Float64) -> Pieces:
    """`c` (a `SectorPayload`) mapped by `m` and tiled into fill and stroke
    quads.

    The tiling is built in local space and mapped per corner, so a
    non-uniform transform gives the elliptical sector it should. With no
    visible stroke everything is fill. With a stroke too wide to leave
    any fill, the whole sector is one colour, as a circle's is: the fill's
    if the fill is visible, else the stroke's. Its `grow` offsets the sector
    by that many local units first, outwards if positive.
    """
    var out = Pieces()
    ref sector = c.payload[SectorPayload]
    var cx = sector.center.x
    var cy = sector.center.y
    var r = sector.r
    var grow = sector.grow
    var sweep = _normalized_sweep(sector.start_angle, sector.sweep_angle)
    var start = sweep[0]
    var theta = sweep[1]
    if r <= 0.0 or theta <= 0.0 or r + grow <= 0.0:
        return out^
    var full = theta >= TAU
    var sf = pixel_scale(m, scale)
    var t = 0.0
    if c.paint._stroke_visible():
        t = min(Float64(stroke_thickness_px(c.paint, m, scale)) / sf, r + grow)

    # Sample angles into the sweep: an even split fine enough for the arc,
    # plus every angle where either boundary changes shape, so each wedge
    # sees a boundary as one straight piece or one chord of a round one. A
    # grown sector reaches round into the missing wedge, so the walk does.
    var span = TAU if grow > 0.0 else theta
    var n = _arc_segments((r + max(grow, 0.0)) * sf, span)
    var alphas = List[Float64]()
    for i in range(n + 1):
        alphas.append(span * Float64(i) / Float64(n))
    if not full:
        # The far edge, which an even split of a whole turn can straddle.
        alphas.append(theta)
        _breakpoints(alphas, theta, r, grow, sf)
        if t > 0.0:
            _breakpoints(alphas, theta, r, grow - t, sf)
    sort(alphas)

    # Along each ray, from the tip: stroke to `inner`, fill to `middle`,
    # stroke to `outer`. Any stretch may be empty.
    var tip = List[Point2D]()
    var inner = List[Point2D]()
    var middle = List[Point2D]()
    var outer = List[Point2D]()
    var lengths = List[Tuple[Float64, Float64, Float64]]()
    for i in range(len(alphas)):
        var alpha = alphas[i]
        if i > 0 and alpha <= alphas[i - 1]:
            continue
        var shape = _offset_extent(alpha, theta, full, r, grow)
        var a = shape[0]
        var b = max(shape[1], a)
        var cc = a
        var d = b
        if t > 0.0:
            var hole = _offset_extent(alpha, theta, full, r, grow - t)
            d = min(max(hole[1], a), b)
            cc = min(max(hole[0], a), d)
        var dx = cos(start + alpha)
        var dy = sin(start + alpha)
        tip.append(Point2D(mat_apply(m, cx + dx * a, cy + dy * a)))
        inner.append(Point2D(mat_apply(m, cx + dx * cc, cy + dy * cc)))
        middle.append(Point2D(mat_apply(m, cx + dx * d, cy + dy * d)))
        outer.append(Point2D(mat_apply(m, cx + dx * b, cy + dy * b)))
        lengths.append((cc - a, d - cc, b - d))

    for i in range(len(inner) - 1):
        var j = i + 1
        if lengths[i][1] > 0.0 or lengths[j][1] > 0.0:
            _append_quad(
                out.fill_quads, inner[i], middle[i], middle[j], inner[j]
            )
        if lengths[i][0] > 0.0 or lengths[j][0] > 0.0:
            _append_quad(out.stroke_quads, tip[i], inner[i], inner[j], tip[j])
        if lengths[i][2] > 0.0 or lengths[j][2] > 0.0:
            _append_quad(
                out.stroke_quads, middle[i], outer[i], outer[j], middle[j]
            )

    if t > 0.0 and len(out.fill_quads) == 0 and c.paint._fill_visible():
        out.fill_quads = out.stroke_quads^
        out.stroke_quads = List[Point2D]()
    return out^


def _offset_extent(
    alpha: Float64, theta: Float64, full: Bool, r: Float64, offset: Float64
) -> Tuple[Float64, Float64]:
    """The stretch of the ray at `alpha` into a sweep of `theta` that the
    sector offset by `offset` covers, as distances from the tip. Empty
    stretches come back with both ends equal, where the stretch would close
    up, so the caller's quads shrink to nothing without jumping."""
    if offset >= 0.0:
        if full or alpha <= theta:
            return (0.0, r + offset)
        return (
            0.0,
            max(
                _capsule_distance(alpha - theta, r, offset),
                _capsule_distance(TAU - alpha, r, offset),
            ),
        )
    var e = -offset
    var hi = r - e
    if not full and alpha > theta:
        return (hi, hi)
    var lo = _eroded_distance(alpha, theta, e, full)
    # The eroded sector narrows to nothing exactly at a sample angle; snap
    # the rounding there so no sliver reaches back along the edge.
    if lo >= hi * (1.0 - 1e-9):
        lo = hi
    return (lo, hi)


def _breakpoints(
    mut alphas: List[Float64],
    theta: Float64,
    r: Float64,
    offset: Float64,
    sf: Float64,
):
    """Append the angles where the sector offset by `offset` changes shape
    along its boundary, measured from both straight edges."""
    if offset < 0.0:
        var e = -offset
        if r - e <= 0.0:
            return
        var beta = PI / 2.0
        if r - e > e:
            beta = asin(e / (r - e))
        for off in [beta, PI / 2.0, theta / 2.0]:
            for a in [off, theta - off]:
                if a > 0.0 and a < theta:
                    alphas.append(a)
    elif offset > 0.0:
        # Into the missing wedge: where the round end of an edge's band meets
        # its straight side, where the side meets the round tip, and the
        # wedge's middle, where the two edges' bands swap which reaches
        # further. The round end is centred off the tip, so it is walked by
        # its own angle.
        var gap = TAU - theta
        var ends = _arc_segments(offset * sf, PI / 2.0)
        var offs = List[Float64]()
        offs.append(atan(offset / r))
        offs.append(PI / 2.0)
        offs.append(gap / 2.0)
        for k in range(1, ends):
            var psi = -PI / 2.0 * Float64(k) / Float64(ends)
            offs.append(atan2(-offset * sin(psi), r + offset * cos(psi)))
        for off in offs:
            if off > 0.0 and off < gap:
                alphas.append(theta + off)
                alphas.append(TAU - off)


def _eroded_distance(
    alpha: Float64, theta: Float64, t: Float64, full: Bool
) -> Float64:
    """How far from the tip, along the direction `alpha` into a sweep of
    `theta`, a point first lies `t` or more from both straight edges.

    Within a quarter turn of an edge the nearest point of that edge is
    across from it, so the distance is `t / sin`; past that it is the tip,
    so `t`. A full turn has no straight edges.
    """
    if full or t <= 0.0:
        return 0.0
    return max(_edge_distance(alpha, t), _edge_distance(theta - alpha, t))


def _edge_distance(alpha: Float64, t: Float64) -> Float64:
    if alpha >= PI / 2.0:
        return t
    var s = sin(alpha)
    if s <= 0.0:
        return Float64.MAX
    return t / s


def _capsule_distance(beta: Float64, r: Float64, g: Float64) -> Float64:
    """How far from the tip the ray `beta` outside a straight edge of
    length `r` leaves that edge grown by `g`: a band of half-width `g`,
    round at both ends."""
    if beta >= PI / 2.0:
        return g
    var s = sin(beta)
    var co = cos(beta)
    if r * s <= g * co:
        # Past the far end of the side: the round end at the arc's end.
        return r * co + sqrt(max(g * g - r * r * s * s, 0.0))
    return g / s


def _append_quad(
    mut corners: List[Point2D], a: Point2D, b: Point2D, c: Point2D, d: Point2D
):
    corners.append(a)
    corners.append(b)
    corners.append(c)
    corners.append(d)
