from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_almost_equal,
)

from create.geometry.bezier import Bezier
from create.math.matrix import identity, scale, translate
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D
from create.color.color import Color
from create.render.style import Style
from create.render._surface import MemorySurface
from create.render._blur import blur_reach
from create.render._command import bezier_chain_command, bezier_command
from create.render._curve import (
    MITER_LIMIT,
    bezier_device_points,
    bezier_shadow_mask,
    stroke_pieces,
    stroke_quads,
    stroke_segment,
)
from create.render.stroke_cap import StrokeCap
from create.render._raster import fill_all, fill_quad


def _assert_point_near(p: Point2D, q: Point2D, tol: Float64 = 1e-9) raises:
    assert_almost_equal(p.x, q.x, atol=tol)
    assert_almost_equal(p.y, q.y, atol=tol)


def _s_curve() -> Bezier:
    return Bezier((0.0, 0.0), (100.0, 100.0), (0.0, 100.0), (100.0, 0.0))


def test_device_points_follow_the_transform() raises -> None:
    var b = _s_curve()
    var c = bezier_command(scale(2.0, 2.0), Style(), b)
    var points = bezier_device_points(c, c.transform)
    _assert_point_near(points[0], Point2D(0.0, 0.0))
    _assert_point_near(points[len(points) - 1], Point2D(200.0, 0.0))


def test_device_points_refine_with_zoom() raises -> None:
    # The same curve drawn larger is flattened into more segments.
    var c = bezier_command(identity[3](), Style(), _s_curve())
    var near = bezier_device_points(c, c.transform)
    var far = bezier_device_points(c, scale(8.0, 8.0))
    assert_true(len(far) > len(near))


def _two_curve_chain() -> List[Point2D]:
    # An S-curve and a second curve leaving its end smoothly.
    return [
        (0.0, 0.0),
        (100.0, 100.0),
        (0.0, 100.0),
        (100.0, 0.0),
        (200.0, -100.0),
        (250.0, 50.0),
        (300.0, 0.0),
    ]


def test_chain_flattens_to_one_polyline() raises -> None:
    var chain = _two_curve_chain()
    var c = bezier_chain_command(identity[3](), Style(), chain.copy())
    var points = bezier_device_points(c, c.transform)
    var first = Bezier(chain[0], chain[1], chain[2], chain[3]).flatten(0.25)
    var second = Bezier(chain[3], chain[4], chain[5], chain[6]).flatten(0.25)
    # The joint appears once.
    assert_equal(len(points), len(first) + len(second) - 1)
    _assert_point_near(points[0], chain[0])
    _assert_point_near(points[len(first) - 1], chain[3])
    _assert_point_near(points[len(points) - 1], chain[6])
    for i in range(1, len(points)):
        assert_true(points[i] != points[i - 1])


def test_chain_stroke_shares_edges_across_the_joint() raises -> None:
    var c = bezier_chain_command(identity[3](), Style(), _two_curve_chain())
    var corners = stroke_quads(bezier_device_points(c, c.transform), 6.0)
    for q in range(len(corners) // 4 - 1):
        assert_equal(corners[4 * q + 1], corners[4 * (q + 1)])
        assert_equal(corners[4 * q + 2], corners[4 * (q + 1) + 3])


def test_closed_polyline_strokes_as_a_ring() raises -> None:
    var points: List[Point2D] = [
        (0.0, 0.0),
        (10.0, 0.0),
        (10.0, 10.0),
        (0.0, 10.0),
        (0.0, 0.0),
    ]
    var corners = stroke_quads(points, 2.0)
    # Four sides, the last closing back to the start.
    assert_equal(len(corners), 16)
    for q in range(4):
        var next = (q + 1) % 4
        assert_equal(corners[4 * q + 1], corners[4 * next])
        assert_equal(corners[4 * q + 2], corners[4 * next + 3])
    # The start is mitred like any corner, not butt.
    _assert_point_near(corners[0], Point2D(1.0, 1.0))
    _assert_point_near(corners[3], Point2D(-1.0, -1.0))


def test_there_and_back_is_not_a_ring() raises -> None:
    var points: List[Point2D] = [(0.0, 0.0), (10.0, 0.0), (0.0, 0.0)]
    assert_equal(len(stroke_quads(points, 2.0)), 8)


def test_straight_polyline_gives_a_straight_band() raises -> None:
    var points: List[Point2D] = [(0.0, 0.0), (10.0, 0.0), (20.0, 0.0)]
    var corners = stroke_quads(points, 4.0)
    assert_equal(len(corners), 8)
    # Left edge at +2, right at -2: exactly a line's band.
    _assert_point_near(corners[0], Point2D(0.0, 2.0))
    _assert_point_near(corners[1], Point2D(10.0, 2.0))
    _assert_point_near(corners[2], Point2D(10.0, -2.0))
    _assert_point_near(corners[3], Point2D(0.0, -2.0))
    _assert_point_near(corners[5], Point2D(20.0, 2.0))
    _assert_point_near(corners[6], Point2D(20.0, -2.0))


def test_neighbouring_quads_share_their_joining_edge() raises -> None:
    var c = bezier_command(identity[3](), Style(), _s_curve())
    var corners = stroke_quads(bezier_device_points(c, c.transform), 6.0)
    var quads = len(corners) // 4
    assert_true(quads > 2)
    for q in range(quads - 1):
        # This quad's far edge is the next one's near edge, exactly.
        assert_equal(corners[4 * q + 1], corners[4 * (q + 1)])
        assert_equal(corners[4 * q + 2], corners[4 * (q + 1) + 3])


def test_miter_keeps_both_edges_at_half_width() raises -> None:
    # A right-angle corner: the mitred corner is sqrt(2) half-widths out.
    var points: List[Point2D] = [(0.0, 0.0), (10.0, 0.0), (10.0, 10.0)]
    var corners = stroke_quads(points, 2.0)
    _assert_point_near(corners[1], Point2D(9.0, 1.0))
    _assert_point_near(corners[2], Point2D(11.0, -1.0))


def test_miter_is_clamped_at_a_sharp_turn() raises -> None:
    var points: List[Point2D] = [(0.0, 0.0), (10.0, 0.0), (0.0, 0.1)]
    var corners = stroke_quads(points, 2.0)
    var reach = (corners[1] - Point2D(10.0, 0.0)).magnitude()
    assert_almost_equal(reach, MITER_LIMIT, atol=1e-9)


def test_repeated_points_are_skipped() raises -> None:
    var points: List[Point2D] = [(0.0, 0.0), (0.0, 0.0), (10.0, 0.0)]
    assert_equal(len(stroke_quads(points, 2.0)), 4)


def test_zero_length_gives_no_quads() raises -> None:
    var b = Bezier((5.0, 5.0), (5.0, 5.0), (5.0, 5.0), (5.0, 5.0))
    var c = bezier_command(identity[3](), Style(), b)
    assert_equal(
        len(stroke_quads(bezier_device_points(c, c.transform), 3.0)), 0
    )


def test_zero_width_gives_no_quads() raises -> None:
    var points: List[Point2D] = [(0.0, 0.0), (10.0, 0.0)]
    assert_equal(len(stroke_quads(points, 0.0)), 0)


def _stroked(thickness: Float64) -> Style:
    var s = Style()
    s.stroke_thickness = thickness
    return s^


def _mass(pixels: List[UInt8]) -> Int:
    var total = 0
    for p in pixels:
        total += Int(p)
    return total


def test_an_unblurred_mask_is_the_stroke_itself() raises -> None:
    # Moved in from the edges, so the whole stroke lands on the surface.
    var c = bezier_command(translate(10.0, 10.0), _stroked(5), _s_curve())
    var placed = bezier_shadow_mask(c, c.transform, 1.0, 0)
    assert_equal(placed.mask.pad, 0)
    # The same quads filled straight onto a device-sized surface.
    var device = MemorySurface(120, 120)
    var s = device.surface()
    var corners = stroke_quads(bezier_device_points(c, c.transform), 5.0)
    for q in range(0, len(corners), 4):
        var qx: Array[Float64, 4] = [
            corners[q].x,
            corners[q + 1].x,
            corners[q + 2].x,
            corners[q + 3].x,
        ]
        var qy: Array[Float64, 4] = [
            corners[q].y,
            corners[q + 1].y,
            corners[q + 2].y,
            corners[q + 3].y,
        ]
        fill_quad(s, qx, qy, Color.WHITE)
    var inked = 0
    for y in range(120):
        for x in range(120):
            var mx = x - placed.x
            var my = y - placed.y
            var covered = UInt8(0)
            if (
                mx >= 0
                and my >= 0
                and mx < placed.mask.width
                and my < placed.mask.height
            ):
                covered = placed.mask.pixels[my * placed.mask.width + mx]
            assert_equal(covered, device.pixel(x, y).a)
            if covered > 0:
                inked += 1
    assert_equal(_mass(placed.mask.pixels), inked * 255)


def test_a_blurred_mask_grows_by_the_reach_and_keeps_its_mass() raises -> None:
    var c = bezier_command(identity[3](), _stroked(5), _s_curve())
    var hard = bezier_shadow_mask(c, c.transform, 1.0, 0)
    var soft = bezier_shadow_mask(c, c.transform, 1.0, 8)
    var pad = blur_reach(4.0)
    assert_equal(soft.mask.pad, pad)
    assert_equal(soft.x, hard.x - pad)
    assert_equal(soft.y, hard.y - pad)
    assert_equal(soft.mask.width, hard.mask.width + 2 * pad)
    var before = Float64(_mass(hard.mask.pixels))
    var after = Float64(_mass(soft.mask.pixels))
    assert_true(abs(after - before) / before < 0.02)


def test_an_invisible_stroke_gives_an_empty_mask() raises -> None:
    var s = _stroked(5)
    s.stroke_enabled = False
    var c = bezier_command(identity[3](), s, _s_curve())
    var placed = bezier_shadow_mask(c, c.transform, 1.0, 8)
    assert_equal(placed.mask.width, 0)
    assert_equal(len(placed.mask.pixels), 0)


def _stroke_line(
    mut mem: MemorySurface,
    x0: Float64,
    y0: Float64,
    x1: Float64,
    y1: Float64,
    c: Color,
    thickness: Int,
):
    """A line as both replays draw one: `stroke_segment`'s quad, filled by
    `fill_quad`."""
    var quad = stroke_segment(
        Point2D(x0, y0), Point2D(x1, y1), Float64(thickness)
    )
    if not quad:
        return
    ref q = quad.value()
    var qx: Array[Float64, 4] = [q[0].x, q[1].x, q[2].x, q[3].x]
    var qy: Array[Float64, 4] = [q[0].y, q[1].y, q[2].y, q[3].y]
    fill_quad(mem.surface(), qx, qy, c)


def _filled(width: Int, height: Int, c: Color) raises -> MemorySurface:
    var mem = MemorySurface(width, height)
    fill_all(mem.surface(), c)
    return mem^


def test_two_points_give_a_line_band() raises -> None:
    # One quad, the segment pushed out by half the width along its normal
    # (-dy, dx): left edge first, then the right, in order around the quad.
    var corners = stroke_quads([Point2D(1.0, 2.0), Point2D(4.0, 6.0)], 10.0)
    assert_equal(len(corners), 4)
    # d = (3, 4), length 5: the unit normal (-0.8, 0.6) times half of 10.
    var n = Vector2D(-4.0, 3.0)
    _assert_point_near(corners[0], Point2D(1.0, 2.0) + n)
    _assert_point_near(corners[1], Point2D(4.0, 6.0) + n)
    _assert_point_near(corners[2], Point2D(4.0, 6.0) - n)
    _assert_point_near(corners[3], Point2D(1.0, 2.0) - n)


def test_a_segment_is_the_two_point_strip_exactly() raises -> None:
    # Lines take `stroke_segment`, curves `stroke_quads`: the same corners to
    # the bit, so a line meets a curve's band as one stroke would.
    var a = Point2D(1.3, -2.7)
    var b = Point2D(40.1, 9.9)
    var corners = stroke_quads([a, b], 3.0)
    var quad = stroke_segment(a, b, 3.0)
    assert_true(Bool(quad))
    for i in range(4):
        assert_equal(quad.value()[i], corners[i])


def test_a_segment_of_no_length_or_width_has_no_quad() raises -> None:
    assert_true(not stroke_segment(Point2D(2, 2), Point2D(2, 2), 3.0))
    assert_true(not stroke_segment(Point2D(0, 0), Point2D(5, 0), 0.0))


def test_two_point_stroke_ends_flush_with_the_segment() raises -> None:
    # Butt ends: covered columns are those whose centre lies in [1, 6).
    var mem = MemorySurface(8, 8)
    _stroke_line(mem, 1.0, 1.5, 6.0, 1.5, Color.WHITE, 1)
    assert_equal(mem.pixel(1, 1), Color.WHITE)
    assert_equal(mem.pixel(5, 1), Color.WHITE)
    assert_equal(mem.pixel(0, 1).a, 0)
    assert_equal(mem.pixel(6, 1).a, 0)
    assert_equal(mem.pixel(3, 0).a, 0)
    assert_equal(mem.pixel(3, 2).a, 0)


def test_two_point_stroke_thickens_with_stroke_thickness() raises -> None:
    var mem = MemorySurface(8, 8)
    _stroke_line(mem, 1.0, 4.5, 6.0, 4.5, Color.WHITE, 3)
    # The band spans y in [3, 6], so rows 3..5.
    assert_equal(mem.pixel(3, 2).a, 0)
    assert_equal(mem.pixel(3, 3), Color.WHITE)
    assert_equal(mem.pixel(3, 4), Color.WHITE)
    assert_equal(mem.pixel(3, 5), Color.WHITE)
    assert_equal(mem.pixel(3, 6).a, 0)


def test_two_point_stroke_measures_thickness_across_the_segment() raises -> (
    None
):
    # At 45 degrees a 4-wide band crosses a row over 4 * sqrt(2) ~ 5.66
    # pixels, centred on the segment: row 10's centre line meets it at
    # x = 10.5, so columns 8..12. An axis-aligned extent would give 4.
    var mem = MemorySurface(20, 20)
    _stroke_line(mem, 2.0, 2.0, 18.0, 18.0, Color.WHITE, 4)
    assert_equal(mem.pixel(7, 10).a, 0)
    for x in range(8, 13):
        assert_equal(mem.pixel(x, 10), Color.WHITE)
    assert_equal(mem.pixel(13, 10).a, 0)


def test_two_point_stroke_paints_nothing_for_a_zero_length_segment() raises -> (
    None
):
    var mem = MemorySurface(8, 8)
    _stroke_line(mem, 3.5, 3.5, 3.5, 3.5, Color.WHITE, 3)
    for y in range(8):
        for x in range(8):
            assert_equal(mem.pixel(x, y).a, 0)


def test_two_point_stroke_clips_outside_the_surface() raises -> None:
    var mem = MemorySurface(4, 4)
    _stroke_line(mem, -5.0, 2.5, 9.0, 2.5, Color.WHITE, 1)
    for x in range(4):
        assert_equal(mem.pixel(x, 2), Color.WHITE)
    assert_equal(mem.pixel(0, 0).a, 0)


def test_two_point_stroke_composites_each_covered_pixel_exactly_once() raises -> (
    None
):
    # A thick alpha line must match one `over` per pixel, not several stacked
    # up from overlapping stamps (which would read darker here).
    var src = Color(255, 255, 255, 128)
    var dst = Color(0, 0, 0, 255)
    var mem = _filled(8, 8, dst)
    _stroke_line(mem, 1.0, 4.5, 6.0, 4.5, src, 3)
    assert_equal(mem.pixel(3, 4), src.over(dst))

    var vmem = _filled(8, 8, dst)
    _stroke_line(vmem, 4.5, 1.0, 4.5, 6.0, src, 3)
    assert_equal(vmem.pixel(4, 3), src.over(dst))


def test_square_caps_push_the_ends_out_by_half_the_width() raises -> None:
    var pieces = stroke_pieces(
        [Point2D(10, 10), Point2D(30, 10)], 6.0, StrokeCap.SQUARE
    )
    assert_equal(len(pieces.caps), 0)
    assert_equal(len(pieces.quads), 4)
    _assert_point_near(pieces.quads[0], Point2D(7, 13))
    _assert_point_near(pieces.quads[1], Point2D(33, 13))
    _assert_point_near(pieces.quads[2], Point2D(33, 7))
    _assert_point_near(pieces.quads[3], Point2D(7, 7))


def test_a_square_capped_segment_is_the_strip_exactly() raises -> None:
    var a = Point2D(1.3, -2.7)
    var b = Point2D(40.1, 9.9)
    var pieces = stroke_pieces([a, b], 3.0, StrokeCap.SQUARE)
    var quad = stroke_segment(a, b, 3.0, StrokeCap.SQUARE)
    assert_true(Bool(quad))
    for i in range(4):
        assert_equal(quad.value()[i], pieces.quads[i])


def test_a_round_capped_segment_has_no_single_quad() raises -> None:
    assert_true(
        not stroke_segment(Point2D(0, 0), Point2D(5, 0), 3.0, StrokeCap.ROUND)
    )


def test_round_caps_start_and_end_on_the_end_quads_corners() raises -> None:
    # Exactly, so the shared edge is walked identically and paints once.
    var pieces = stroke_pieces(
        [Point2D(10, 10), Point2D(20, 14), Point2D(30, 10)],
        6.0,
        StrokeCap.ROUND,
    )
    assert_equal(len(pieces.caps), 2)
    var q = len(pieces.quads) - 4
    ref start = pieces.caps[0]
    ref end = pieces.caps[1]
    assert_equal(start[0], pieces.quads[0])
    assert_equal(start[len(start) - 1], pieces.quads[3])
    assert_equal(end[0], pieces.quads[q + 2])
    assert_equal(end[len(end) - 1], pieces.quads[q + 1])


def test_round_caps_bulge_away_from_the_band() raises -> None:
    var pieces = stroke_pieces(
        [Point2D(10, 10), Point2D(30, 10)], 6.0, StrokeCap.ROUND
    )
    var least = 1e9
    for p in pieces.caps[0]:
        assert_true(p.x <= 10.0 + 1e-9)
        least = min(least, p.x)
    assert_almost_equal(least, 7.0, atol=1e-9)
    var most = -1e9
    for p in pieces.caps[1]:
        assert_true(p.x >= 30.0 - 1e-9)
        most = max(most, p.x)
    assert_almost_equal(most, 33.0, atol=1e-9)


def test_a_closed_ring_has_no_caps() raises -> None:
    for cap in [StrokeCap.ROUND, StrokeCap.SQUARE]:
        var pieces = stroke_pieces(
            [Point2D(0, 0), Point2D(20, 0), Point2D(10, 15), Point2D(0, 0)],
            4.0,
            cap,
        )
        assert_equal(len(pieces.caps), 0)
        assert_equal(len(pieces.quads), 12)


def test_a_round_dot_is_a_whole_disc() raises -> None:
    var pieces = stroke_pieces(
        [Point2D(5, 5), Point2D(5, 5)], 8.0, StrokeCap.ROUND
    )
    assert_equal(len(pieces.quads), 0)
    assert_equal(len(pieces.caps), 1)
    assert_true(len(pieces.caps[0]) >= 8)
    for p in pieces.caps[0]:
        assert_almost_equal((p - Point2D(5, 5)).magnitude(), 4.0, atol=1e-9)


def test_a_square_dot_lines_up_with_the_axis() raises -> None:
    var upright = stroke_pieces([Point2D(5, 5)], 8.0, StrokeCap.SQUARE)
    assert_equal(len(upright.quads), 4)
    for p in upright.quads:
        assert_almost_equal(abs(p.x - 5.0), 4.0, atol=1e-9)
        assert_almost_equal(abs(p.y - 5.0), 4.0, atol=1e-9)
    # Under a turned transform the square turns with the local axes.
    var turned = stroke_pieces(
        [Point2D(0, 0)], 2.0, StrokeCap.SQUARE, Vector2D(3, 3)
    )
    for p in turned.quads:
        var on_axis = abs(p.x) < 1e-9 or abs(p.y) < 1e-9
        assert_true(on_axis)
        assert_almost_equal(
            Vector2D(p).magnitude(), 1.4142135623730951, atol=1e-9
        )


def test_a_butt_dot_is_nothing() raises -> None:
    var pieces = stroke_pieces([Point2D(5, 5)], 8.0, StrokeCap.BUTT)
    assert_equal(len(pieces.quads), 0)
    assert_equal(len(pieces.caps), 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
