from std.math import erf, exp, sqrt
from create.math import PI
from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_false,
    assert_true,
)

from create.math.matrix import (
    Matrix,
    _apply as apply,
    identity,
    rotate,
    scale,
    translate,
)
from create.math.point2d import Point2D
from create.math.vector2d import Vector2D
from create.geometry.bezier import Bezier
from create.color.color import Color
from create.render.style import Style
from create.render._command import (
    RenderCommand,
    bezier_chain_command,
    bezier_command,
    circle_command,
    clear_command,
    line_command,
    polygon_command,
    rect_command,
    sector_command,
    image_command,
    text_command,
    triangle_command,
)
from create.render._shadow import (
    box_coverage,
    casts_inset_shadow,
    casts_outer_shadow,
    edge_coverage,
    gaussian_cdf,
    rounded_rect_coverage,
    shadow_command,
    shadow_transform,
    BlurredSilhouette,
)
from create.render._curve import bezier_shadow_mask
from create.render.stroke_cap import StrokeCap


def _shadowed() -> Style:
    var s = Style(fill=Color.WHITE, shadow_enabled=True)
    s.shadow_offset = Vector2D(4, -4)
    return s^


def _device() -> Matrix[3, 3]:
    """A window base like the canvas builds: scale 2, y flipped."""
    return translate(100.0, 100.0) @ scale(2.0, -2.0)


def _moved(m: Matrix[3, 3], s: Matrix[3, 3]) -> Tuple[Float64, Float64]:
    """Where the local origin lands under `s`, relative to under `m`."""
    var a = apply(m, 0.0, 0.0)
    var b = apply(s, 0.0, 0.0)
    return (b[0] - a[0], b[1] - a[1])


def test_screen_fixed_offset_ignores_rotation() raises -> None:
    var m = _device() @ rotate(PI / 2.0)
    var c = rect_command(m, _shadowed(), 0.0, 0.0, 10.0, 10.0)
    # A rotated transform has no single pixel scale, so the length comes from
    # the frame's autoscale factor, as stroke thickness does.
    var d = _moved(m, shadow_transform(c, 2.0))
    # Down-right on screen: device rows run downwards.
    assert_almost_equal(d[0], 8.0)
    assert_almost_equal(d[1], 8.0)


def test_follows_transform_offset_turns_with_the_shape() raises -> None:
    var m = _device() @ rotate(PI / 2.0)
    var s = _shadowed()
    s.shadow_follows_transform = True
    var c = rect_command(m, s, 0.0, 0.0, 10.0, 10.0)
    var d = _moved(m, shadow_transform(c, 2.0))
    # (4, -4) turned a quarter anticlockwise is (4, 4): up-right on screen.
    assert_almost_equal(d[0], 8.0)
    assert_almost_equal(d[1], -8.0)


def test_only_render_calls_that_paint_cast_a_shadow() raises -> None:
    var s = _shadowed()
    assert_true(casts_outer_shadow(rect_command(identity[3](), s, 0, 0, 1, 1)))
    assert_false(casts_outer_shadow(clear_command(Color.RED)))
    s.fill_enabled = False
    s.stroke_enabled = False
    assert_false(casts_outer_shadow(rect_command(identity[3](), s, 0, 0, 1, 1)))
    var off = _shadowed()
    off.shadow_enabled = False
    assert_false(
        casts_outer_shadow(rect_command(identity[3](), off, 0, 0, 1, 1))
    )
    var inset = _shadowed()
    inset.shadow_inset = True
    assert_false(
        casts_outer_shadow(rect_command(identity[3](), inset, 0, 0, 1, 1))
    )


def test_filled_shape_casts_one_filled_layer() raises -> None:
    var s = _shadowed()
    s.shadow_color = Color(0, 0, 0, 100)
    var c = rect_command(identity[3](), s, 0.0, 0.0, 10.0, 6.0)
    var sh = shadow_command(c, 1.0)
    assert_true(sh.style.fill_enabled)
    assert_equal(sh.style.fill_color, Color(0, 0, 0, 100))
    assert_false(sh.style.stroke_enabled)
    assert_false(sh.style.shadow_enabled)
    # A rectangle's stroke is inset, so the silhouette is the rectangle.
    assert_equal(sh.geom[2], 10.0)
    assert_equal(sh.geom[3], 6.0)


def test_stroke_only_shape_casts_its_ring() raises -> None:
    var s = Style(stroke=Color.RED, stroke_thickness=3, shadow_enabled=True)
    var c = circle_command(identity[3](), s, 0.0, 0.0, 10.0)
    var sh = shadow_command(c, 1.0)
    assert_false(sh.style.fill_enabled)
    assert_true(sh.style.stroke_enabled)
    assert_equal(sh.style.stroke_color, s.shadow_color)
    assert_equal(sh.style.stroke_thickness, 3)
    assert_equal(sh.geom[2], 10.0)


def test_bezier_casts_its_stroke_even_when_filled() raises -> None:
    # A curve has no interior: a fill in its style changes nothing, and its
    # silhouette is the stroke, widened by the spread on both sides.
    var s = _shadowed()
    s.stroke_enabled = True
    s.stroke_thickness = 3
    s.shadow_spread = 1.0
    var curve = Bezier((0.0, 0.0), (10.0, 20.0), (20.0, -20.0), (30.0, 0.0))
    var c = bezier_command(identity[3](), s, curve)
    assert_true(casts_outer_shadow(c))
    var sh = shadow_command(c, 1.0)
    assert_false(sh.style.fill_enabled)
    assert_true(sh.style.stroke_enabled)
    assert_equal(sh.style.stroke_color, s.shadow_color)
    assert_equal(sh.style.stroke_thickness, 5)
    assert_equal(len(sh.points), len(c.points))
    for i in range(len(c.points)):
        assert_equal(sh.points[i], c.points[i])
    s.stroke_enabled = False
    assert_false(casts_outer_shadow(bezier_command(identity[3](), s, curve)))


def test_a_bezier_chain_casts_every_curve() raises -> None:
    var s = _shadowed()
    s.stroke_enabled = True
    var chain: List[Point2D] = [
        (0.0, 0.0),
        (10.0, 20.0),
        (20.0, 20.0),
        (30.0, 0.0),
        (40.0, -20.0),
        (50.0, -20.0),
        (0.0, 0.0),
    ]
    var c = bezier_chain_command(identity[3](), s, chain.copy())
    assert_true(casts_outer_shadow(c))
    var sh = shadow_command(c, 1.0)
    assert_equal(len(sh.points), len(chain))
    for i in range(len(chain)):
        assert_equal(sh.points[i], chain[i])


def test_spread_grows_each_kind() raises -> None:
    var s = _shadowed()
    s.stroke_enabled = False
    s.shadow_spread = 2.0
    var r = shadow_command(rect_command(identity[3](), s, 0, 0, 10, 6), 1.0)
    assert_equal(r.geom[2], 14.0)
    assert_equal(r.geom[3], 10.0)
    assert_equal(r.corner_radius, 2.0)
    var c = shadow_command(circle_command(identity[3](), s, 0, 0, 5), 1.0)
    assert_equal(c.geom[2], 7.0)
    var l = shadow_command(line_command(identity[3](), s, 0, 0, 5, 0), 1.0)
    assert_equal(l.style.stroke_thickness, 5)


def test_negative_spread_never_inverts_a_shape() raises -> None:
    var s = _shadowed()
    s.shadow_spread = -20.0
    var r = shadow_command(rect_command(identity[3](), s, 0, 0, 10, 6), 1.0)
    assert_equal(r.geom[2], 0.0)
    assert_equal(r.geom[3], 0.0)


def test_triangle_grows_every_edge_by_the_spread() raises -> None:
    var s = _shadowed()
    s.stroke_enabled = False
    s.shadow_spread = 1.0
    # Right isosceles triangle, legs along the axes.
    var c = triangle_command(identity[3](), s, 0, 0, 10, 0, 0, 10)
    var sh = shadow_command(c, 1.0)
    # The right-angle vertex moves out one unit along both axes.
    assert_almost_equal(sh.geom[0], -1.0)
    assert_almost_equal(sh.geom[1], -1.0)
    assert_equal(sh.corner_radius, 1.0)


def test_triangle_silhouette_is_the_shape_its_stroke_is_inset_in() raises -> (
    None
):
    var s = _shadowed()
    s.stroke_thickness = 2
    s.shadow_spread = 0.0
    var c = triangle_command(identity[3](), s, 0, 0, 10, 0, 0, 10)
    var sh = shadow_command(c, 1.0)
    # The stroke is an inset ring, so its outer edge is the triangle's.
    for i in range(6):
        assert_almost_equal(sh.geom[i], c.geom[i])


def test_a_sector_casts_its_grown_silhouette() raises -> None:
    # The stroke is inset, so the silhouette is the sector; the spread
    # rides along for `sector_quads` to grow it exactly.
    var s = _shadowed()
    s.shadow_spread = 2.0
    var c = sector_command(identity[3](), s, 0.0, 0.0, 10.0, 0.5, -4.0)
    assert_true(casts_outer_shadow(c))
    var sh = shadow_command(c, 1.0)
    assert_true(sh.style.fill_enabled)
    assert_equal(sh.style.fill_color, s.shadow_color)
    assert_false(sh.style.stroke_enabled)
    for i in range(5):
        assert_equal(sh.geom[i], c.geom[i])
    assert_equal(sh.geom[5], 2.0)


def test_an_stroke_only_sector_casts_its_ring() raises -> None:
    var s = Style(stroke=Color.RED, stroke_thickness=3, shadow_enabled=True)
    s.shadow_spread = 1.0
    var c = sector_command(identity[3](), s, 0.0, 0.0, 10.0, 0.0, 1.0)
    var sh = shadow_command(c, 1.0)
    assert_false(sh.style.fill_enabled)
    assert_equal(sh.style.stroke_color, s.shadow_color)
    assert_equal(sh.style.stroke_thickness, 5)
    assert_equal(sh.geom[5], 1.0)
    s.stroke_enabled = False
    assert_false(
        casts_outer_shadow(sector_command(identity[3](), s, 0, 0, 10, 0, 1))
    )


def test_a_sector_casts_no_inset_shadow() raises -> None:
    var s = _shadowed()
    s.shadow_inset = True
    var c = sector_command(identity[3](), s, 0.0, 0.0, 10.0, 0.0, 1.0)
    assert_false(casts_inset_shadow(c))
    assert_false(casts_outer_shadow(c))


def _square() -> List[Point2D]:
    return [(-10.0, -10.0), (10.0, -10.0), (10.0, 10.0), (-10.0, 10.0)]


def test_a_polygon_casts_its_grown_silhouette() raises -> None:
    # The stroke is inset, so the silhouette is the polygon; the spread
    # rides along for `polygon_quads` to grow it exactly.
    var s = _shadowed()
    s.shadow_spread = 2.0
    var c = polygon_command(identity[3](), s, _square())
    assert_true(casts_outer_shadow(c))
    var sh = shadow_command(c, 1.0)
    assert_true(sh.style.fill_enabled)
    assert_equal(sh.style.fill_color, s.shadow_color)
    assert_false(sh.style.stroke_enabled)
    assert_equal(len(sh.points), 4)
    for i in range(4):
        assert_true(sh.points[i] == c.points[i])
    assert_equal(sh.geom[0], 2.0)


def test_an_stroke_only_polygon_casts_its_ring() raises -> None:
    var s = Style(stroke=Color.RED, stroke_thickness=3, shadow_enabled=True)
    s.shadow_spread = 1.0
    var c = polygon_command(identity[3](), s, _square())
    var sh = shadow_command(c, 1.0)
    assert_false(sh.style.fill_enabled)
    assert_equal(sh.style.stroke_color, s.shadow_color)
    assert_equal(sh.style.stroke_thickness, 5)
    assert_equal(sh.geom[0], 1.0)
    s.stroke_enabled = False
    assert_false(
        casts_outer_shadow(polygon_command(identity[3](), s, _square()))
    )


def test_a_polygon_casts_no_inset_shadow() raises -> None:
    var s = _shadowed()
    s.shadow_inset = True
    var c = polygon_command(identity[3](), s, _square())
    assert_false(casts_inset_shadow(c))
    assert_false(casts_outer_shadow(c))


def test_text_shadow_recolours_the_glyphs() raises -> None:
    var s = _shadowed()
    var c = text_command(identity[3](), s, 0.0, 0.0, "hi")
    var sh = shadow_command(c, 1.0)
    assert_equal(sh.style.text_color, s.shadow_color)
    assert_equal(sh.text, "hi")


def test_image_shadow_is_a_silhouette() raises -> None:
    var s = _shadowed()
    var c = image_command(identity[3](), s, 0, 0, 4, 4, 7, 4, 4)
    assert_false(c.silhouette)
    var sh = shadow_command(c, 1.0)
    assert_true(sh.silhouette)
    assert_equal(sh.style.fill_color, s.shadow_color)
    assert_equal(sh.image, 7)


def test_gaussian_cdf_matches_erf() raises -> None:
    var x = -3.875
    while x < 4.0:
        var want = 0.5 * (1.0 + erf(x / sqrt(2.0)))
        assert_almost_equal(gaussian_cdf(x), want, atol=2e-7)
        x += 0.125
    # Past four sigma it saturates, below what an 8-bit channel resolves.
    assert_equal(gaussian_cdf(4.0), 1.0)
    assert_equal(gaussian_cdf(-4.0), 0.0)


def test_coverage_is_half_on_an_edge_and_saturates_by_three_sigma() raises -> (
    None
):
    # A half-plane: the far edges out of reach.
    assert_almost_equal(edge_coverage(0.0, 1e9, 1e9), 0.5, atol=1e-7)
    assert_true(edge_coverage(3.0, 1e9, 1e9) > 0.998)
    assert_true(edge_coverage(-3.0, 1e9, 1e9) < 0.002)
    assert_almost_equal(box_coverage(0.0, 1e9, 1e9, 1e9), 0.5, atol=1e-7)
    assert_true(box_coverage(3.0, 1e9, 1e9, 1e9) > 0.998)
    assert_true(box_coverage(-3.0, 1e9, 1e9, 1e9) < 0.002)
    # A long straight edge of a rounded rectangle.
    assert_almost_equal(
        rounded_rect_coverage(10.0, 0.0, 10.0, 100.0, 2.0), 0.5, atol=1e-7
    )
    assert_true(rounded_rect_coverage(7.0, 0.0, 10.0, 100.0, 2.0) > 0.998)
    assert_true(rounded_rect_coverage(13.0, 0.0, 10.0, 100.0, 2.0) < 0.002)


def test_box_coverage_is_the_separable_erf_form() raises -> None:
    # Centre of a rectangle 2 sigma wide and 1 sigma tall: each axis keeps
    # the share of the Gaussian within its half-extent.
    var want = erf(1.0 / sqrt(2.0)) * erf(0.5 / sqrt(2.0))
    assert_almost_equal(box_coverage(1.0, 1.0, 0.5, 0.5), want, atol=1e-6)
    # Off-centre: x = 0.3 in a slab [-1, 1].
    var slab = 0.5 * (erf(1.3 / sqrt(2.0)) + erf(0.7 / sqrt(2.0)))
    assert_almost_equal(box_coverage(1.3, 0.7, 1e9, 1e9), slab, atol=1e-6)


def test_edge_product_matches_the_box_once_the_shape_is_wide() raises -> None:
    # Far from the opposite edges the two forms agree; narrow, the product
    # overestimates, since cdf(a) * cdf(b) >= cdf(a) + cdf(b) - 1.
    assert_almost_equal(
        edge_coverage(0.5, 10.0, 0.5, 10.0),
        box_coverage(0.5, 10.0, 0.5, 10.0),
        atol=1e-6,
    )
    assert_true(
        edge_coverage(0.5, 0.5, 0.5, 0.5) > box_coverage(0.5, 0.5, 0.5, 0.5)
    )


def test_rounded_rect_coverage_is_symmetric_and_rounds_corners() raises -> None:
    var a = rounded_rect_coverage(9.0, 4.0, 10.0, 5.0, 3.0)
    assert_almost_equal(a, rounded_rect_coverage(-9.0, -4.0, 10.0, 5.0, 3.0))
    # The sharp corner point is outside a rounded corner by (sqrt 2 - 1) r.
    var corner = rounded_rect_coverage(10.0, 5.0, 10.0, 5.0, 3.0)
    assert_almost_equal(
        corner, gaussian_cdf(-(sqrt(2.0) - 1.0) * 3.0), atol=1e-9
    )
    # A circle: half at its radius in any direction.
    var d = 4.0 / sqrt(2.0)
    assert_almost_equal(
        rounded_rect_coverage(d, d, 4.0, 4.0, 4.0), 0.5, atol=1e-7
    )


def _blurred_line(
    cap: StrokeCap, thickness: Float64 = 6, blur: Float64 = 4
) -> BlurredSilhouette:
    """A line from (0, 0) to (20, 0), 6 thick and its shadow blurred by 4
    (sigma 2) unless given."""
    var s = Style(
        stroke=Color.BLACK,
        stroke_thickness=thickness,
        stroke_cap=cap,
        shadow_blur=blur,
    )
    var sh = shadow_command(line_command(identity[3](), s, 0, 0, 20, 0), 1.0)
    return BlurredSilhouette(sh, thickness)


def _capsule_reference(
    x: Float64, y: Float64, core_half: Float64, radius: Float64
) -> Float64:
    """A blurred capsule centred on the origin (unit sigma), integrated row
    by row: each row of a capsule is one interval, blurred along it
    exactly, so only the sum across is numeric."""
    var rows = 20000
    var dy = 2.0 * radius / Float64(rows)
    var total = 0.0
    for j in range(rows):
        var t = -radius + (Float64(j) + 0.5) * dy
        var w = core_half + sqrt(max(radius * radius - t * t, 0.0))
        var along = 0.5 * (erf((w - x) / sqrt(2.0)) - erf((-w - x) / sqrt(2.0)))
        total += exp(-0.5 * (t - y) * (t - y)) * along
    return total * dy / sqrt(2.0 * PI)


def _line_end() -> Float64:
    """`_blurred_line`'s coverage on its axis where its silhouette ends: half
    along, times the 6-thick band's blur across (3 / sigma 2 = 1.5 either
    side)."""
    return 0.5 * (gaussian_cdf(1.5) - gaussian_cdf(-1.5))


def test_a_butt_line_shadow_fades_past_its_end() raises -> None:
    var b = _blurred_line(StrokeCap.BUTT)
    assert_almost_equal(b.coverage(20, 0), _line_end(), atol=1e-6)
    assert_true(b.coverage(23, 0) < 0.07)


def test_a_round_line_shadow_is_a_blurred_capsule() raises -> None:
    var b = _blurred_line(StrokeCap.ROUND)
    # In sigma units (2): a core from -5 to 5 around (10, 0), radius 1.5.
    for p in [(23.0, 0.0), (23.0, 3.0), (21.0, 2.0), (10.0, 4.0)]:
        assert_almost_equal(
            b.coverage(p[0], p[1]),
            _capsule_reference((p[0] - 10.0) / 2.0, p[1] / 2.0, 5.0, 1.5),
            atol=1e-5,
        )
    assert_almost_equal(b.coverage(23, 0), b.coverage(-3, 0), atol=1e-12)
    assert_true(b.x1 >= 26.0 and b.x0 <= -6.0)


def test_a_round_cap_is_inside_a_square_one() raises -> None:
    # So its blur is fainter everywhere past the line's end.
    var round = _blurred_line(StrokeCap.ROUND)
    var square = _blurred_line(StrokeCap.SQUARE)
    for p in [(21.0, 0.0), (23.0, 0.0), (23.0, 3.0), (25.0, 1.0)]:
        assert_true(round.coverage(p[0], p[1]) < square.coverage(p[0], p[1]))


def test_a_thin_round_line_blurs_as_faintly_as_a_butt_one() raises -> None:
    # 2 thick under blur 20 (sigma 10): away from the ends, both are the
    # same thin band blurred, about 8% dark rather than half.
    var round = _blurred_line(StrokeCap.ROUND, thickness=2, blur=20)
    var butt = _blurred_line(StrokeCap.BUTT, thickness=2, blur=20)
    # Butt: the band across (0.1 sigma either side) times 1 sigma along.
    var band = gaussian_cdf(0.1) - gaussian_cdf(-0.1)
    var along = gaussian_cdf(1.0) - gaussian_cdf(-1.0)
    assert_almost_equal(butt.coverage(10, 0), band * along, atol=1e-6)
    # Round: the same, its caps adding their little area.
    var r = round.coverage(10, 0)
    assert_almost_equal(r, _capsule_reference(0.0, 0.0, 1.0, 0.1), atol=1e-5)
    assert_true(r > butt.coverage(10, 0) and r < 0.1)


def test_a_square_line_shadow_reaches_the_corner() raises -> None:
    var b = _blurred_line(StrokeCap.SQUARE)
    assert_almost_equal(b.coverage(23, 0), _line_end(), atol=1e-6)
    assert_almost_equal(b.coverage(23, 3), 0.25, atol=2e-3)
    assert_almost_equal(b.coverage(-3, -3), 0.25, atol=2e-3)


def test_a_butt_line_of_no_length_casts_nothing() raises -> None:
    var s = Style(stroke=Color.BLACK, stroke_thickness=6, shadow_blur=4)
    assert_false(casts_outer_shadow(line_command(identity[3](), s, 5, 5, 5, 5)))
    s.stroke_cap = StrokeCap.ROUND
    assert_true(casts_outer_shadow(line_command(identity[3](), s, 5, 5, 5, 5)))


def _mask_mass(cap: StrokeCap) -> Int:
    var s = Style(
        stroke=Color.BLACK, stroke_thickness=8, stroke_cap=cap, shadow_blur=4
    )
    var c = bezier_command(
        identity[3](),
        s,
        Bezier(
            Point2D(10, 10), Point2D(20, 30), Point2D(40, 30), Point2D(50, 10)
        ),
    )
    var mask = bezier_shadow_mask(c, identity[3](), 1.0, 0)
    var total = 0
    for a in mask.mask.pixels:
        total += Int(a)
    return total


def test_a_bezier_shadow_mask_includes_its_caps() raises -> None:
    var butt = _mask_mass(StrokeCap.BUTT)
    assert_true(_mask_mass(StrokeCap.ROUND) > butt)
    assert_true(_mask_mass(StrokeCap.SQUARE) > _mask_mass(StrokeCap.ROUND))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
