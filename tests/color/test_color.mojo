from std.testing import (
    TestSuite,
    assert_equal,
    assert_true,
    assert_almost_equal,
    assert_raises,
)
from create.color.color import Color


def test_rgba_constructor() raises -> None:
    var c = Color(10, 20, 30, 40)
    assert_equal(c.r, UInt8(10))
    assert_equal(c.g, UInt8(20))
    assert_equal(c.b, UInt8(30))
    assert_equal(c.a, UInt8(40))


def test_rgb_default_alpha() raises -> None:
    var c = Color(1, 2, 3)
    assert_equal(c.a, UInt8(255))


def test_gray_constructor() raises -> None:
    var c = Color(UInt8(128))
    assert_equal(c.r, UInt8(128))
    assert_equal(c.g, UInt8(128))
    assert_equal(c.b, UInt8(128))
    assert_equal(c.a, UInt8(255))


def test_black() raises -> None:
    var c = Color.BLACK
    assert_equal(c.r, UInt8(0))
    assert_equal(c.g, UInt8(0))
    assert_equal(c.b, UInt8(0))
    assert_equal(c.a, UInt8(255))


def test_white() raises -> None:
    var c = Color.WHITE
    assert_equal(c.r, UInt8(255))
    assert_equal(c.g, UInt8(255))
    assert_equal(c.b, UInt8(255))
    assert_equal(c.a, UInt8(255))


def test_red() raises -> None:
    var c = Color.RED
    assert_equal(c.r, UInt8(255))
    assert_equal(c.g, UInt8(0))
    assert_equal(c.b, UInt8(0))
    assert_equal(c.a, UInt8(255))


def test_green() raises -> None:
    var c = Color.GREEN
    assert_equal(c.r, UInt8(0))
    assert_equal(c.g, UInt8(255))
    assert_equal(c.b, UInt8(0))
    assert_equal(c.a, UInt8(255))


def test_blue() raises -> None:
    var c = Color.BLUE
    assert_equal(c.r, UInt8(0))
    assert_equal(c.g, UInt8(0))
    assert_equal(c.b, UInt8(255))
    assert_equal(c.a, UInt8(255))


def test_boundary_max() raises -> None:
    var c = Color(255, 255, 255, 255)
    assert_equal(c.r, UInt8(255))
    assert_equal(c.g, UInt8(255))
    assert_equal(c.b, UInt8(255))
    assert_equal(c.a, UInt8(255))


def test_boundary_min() raises -> None:
    var c = Color(0, 0, 0, 0)
    assert_equal(c.r, UInt8(0))
    assert_equal(c.a, UInt8(0))


def test_hex_channels() raises -> None:
    var c = Color.hex(0x336699)
    assert_equal(c.r, UInt8(0x33))
    assert_equal(c.g, UInt8(0x66))
    assert_equal(c.b, UInt8(0x99))
    assert_equal(c.a, UInt8(255))


def test_hex_black_and_white() raises -> None:
    assert_equal(Color.hex(0x000000).r, UInt8(0))
    assert_equal(Color.hex(0xFFFFFF).b, UInt8(255))


def test_hex_string_six_digits() raises -> None:
    var c = Color.hex("#336699")
    assert_equal(c.r, UInt8(0x33))
    assert_equal(c.g, UInt8(0x66))
    assert_equal(c.b, UInt8(0x99))
    assert_equal(c.a, UInt8(255))


def test_hex_string_hash_is_optional() raises -> None:
    assert_equal(Color.hex("336699"), Color.hex("#336699"))


def test_hex_string_is_case_insensitive() raises -> None:
    assert_equal(Color.hex("#AbCdEf"), Color.hex("#abcdef"))


def test_hex_string_matches_int_form() raises -> None:
    assert_equal(Color.hex("#336699"), Color.hex(0x336699))
    assert_equal(Color.hex("#ffffff"), Color.WHITE)
    assert_equal(Color.hex("#000000"), Color.BLACK)


def test_hex_string_short_form_doubles_digits() raises -> None:
    assert_equal(Color.hex("#f80"), Color.hex("#ff8800"))
    assert_equal(Color.hex("#fff"), Color.WHITE)
    assert_equal(Color.hex("#000"), Color.BLACK)


def test_hex_string_carries_alpha() raises -> None:
    var c = Color.hex("#11223344")
    assert_equal(c.r, UInt8(0x11))
    assert_equal(c.a, UInt8(0x44))
    assert_equal(Color.hex("#0000"), Color(0, 0, 0, 0))
    assert_equal(Color.hex("#f00f"), Color.RED)


def test_hex_string_rejects_bad_length() raises -> None:
    with assert_raises():
        _ = Color.hex("#12345")
    with assert_raises():
        _ = Color.hex("#")
    with assert_raises():
        _ = Color.hex("")


def test_hex_string_rejects_non_hex_digit() raises -> None:
    with assert_raises():
        _ = Color.hex("#gggggg")
    with assert_raises():
        _ = Color.hex("#12 456")


def test_hsv_primaries() raises -> None:
    var r = Color.hsv(0.0, 1.0, 1.0)
    assert_equal(r.r, UInt8(255))
    assert_equal(r.g, UInt8(0))
    assert_equal(r.b, UInt8(0))
    var g = Color.hsv(120.0, 1.0, 1.0)
    assert_equal(g.r, UInt8(0))
    assert_equal(g.g, UInt8(255))
    var b = Color.hsv(240.0, 1.0, 1.0)
    assert_equal(b.b, UInt8(255))
    assert_equal(b.g, UInt8(0))


def test_hsv_secondaries() raises -> None:
    var y = Color.hsv(60.0, 1.0, 1.0)
    assert_equal(y.r, UInt8(255))
    assert_equal(y.g, UInt8(255))
    assert_equal(y.b, UInt8(0))
    var c = Color.hsv(180.0, 1.0, 1.0)
    assert_equal(c.g, UInt8(255))
    assert_equal(c.b, UInt8(255))
    var m = Color.hsv(300.0, 1.0, 1.0)
    assert_equal(m.r, UInt8(255))
    assert_equal(m.b, UInt8(255))


def test_hsv_zero_saturation_is_gray() raises -> None:
    var c = Color.hsv(200.0, 0.0, 0.5)
    assert_equal(c.r, c.g)
    assert_equal(c.g, c.b)
    assert_equal(c.r, UInt8(128))


def test_hsv_zero_value_is_black() raises -> None:
    var c = Color.hsv(200.0, 1.0, 0.0)
    assert_equal(c.r, UInt8(0))
    assert_equal(c.g, UInt8(0))
    assert_equal(c.b, UInt8(0))


def test_hsv_hue_wraps() raises -> None:
    var a = Color.hsv(360.0, 1.0, 1.0)
    var b = Color.hsv(0.0, 1.0, 1.0)
    assert_equal(a.r, b.r)
    assert_equal(a.g, b.g)
    assert_equal(a.b, b.b)
    var neg = Color.hsv(-120.0, 1.0, 1.0)
    var pos = Color.hsv(240.0, 1.0, 1.0)
    assert_equal(neg.b, pos.b)
    assert_equal(neg.r, pos.r)


def test_hsv_clamps_out_of_range() raises -> None:
    var c = Color.hsv(0.0, 5.0, 5.0)
    assert_equal(c.r, UInt8(255))
    assert_equal(c.g, UInt8(0))


def test_lerp_endpoints() raises -> None:
    var a = Color.BLACK.lerp(Color.WHITE, 0.0)
    assert_equal(a.r, UInt8(0))
    var b = Color.BLACK.lerp(Color.WHITE, 1.0)
    assert_equal(b.r, UInt8(255))


def test_lerp_midpoint() raises -> None:
    var c = Color.BLACK.lerp(Color.WHITE, 0.5)
    assert_equal(c.r, UInt8(128))
    assert_equal(c.g, UInt8(128))
    assert_equal(c.b, UInt8(128))


def test_lerp_blends_alpha() raises -> None:
    var c = Color(0, 0, 0, 0).lerp(Color(0, 0, 0, 255), 0.5)
    assert_equal(c.a, UInt8(128))


def test_lerp_clamps_t() raises -> None:
    var lo = Color.BLACK.lerp(Color.WHITE, -2.0)
    assert_equal(lo.r, UInt8(0))
    var hi = Color.BLACK.lerp(Color.WHITE, 3.0)
    assert_equal(hi.r, UInt8(255))


def test_orange() raises -> None:
    var c = Color.ORANGE
    assert_equal(c.r, UInt8(255))
    assert_equal(c.g, UInt8(128))
    assert_equal(c.b, UInt8(0))


def test_secondary_constants() raises -> None:
    assert_equal(Color.CYAN.r, UInt8(0))
    assert_equal(Color.CYAN.g, UInt8(255))
    assert_equal(Color.MAGENTA.g, UInt8(0))
    assert_equal(Color.MAGENTA.b, UInt8(255))
    assert_equal(Color.YELLOW.b, UInt8(0))
    assert_equal(Color.YELLOW.r, UInt8(255))


def test_gray_constants() raises -> None:
    assert_equal(Color.DARK_GRAY.r, UInt8(0x40))
    assert_equal(Color.GRAY.g, UInt8(0x80))
    assert_equal(Color.LIGHT_GRAY.b, UInt8(0xC0))


def test_equality() raises -> None:
    assert_equal(Color(1, 2, 3, 4), Color(1, 2, 3, 4))
    assert_true(Color.RED != Color.BLUE)
    assert_true(Color(1, 2, 3, 4) != Color(1, 2, 3, 5))


def test_equality_matches_constants() raises -> None:
    assert_equal(Color.hex(0xFF0000), Color.RED)
    assert_equal(Color.hsv(0.0, 1.0, 1.0), Color.RED)
    assert_equal(Color.hsv(180.0, 1.0, 1.0), Color.CYAN)


def test_write_to() raises -> None:
    assert_equal(String(Color(1, 2, 3, 4)), "Color(1, 2, 3, 4)")


def test_luminance_endpoints() raises -> None:
    assert_almost_equal(Color.BLACK.luminance(), 0.0)
    assert_almost_equal(Color.WHITE.luminance(), 1.0)


def test_luminance_orders_grays() raises -> None:
    assert_true(Color.DARK_GRAY.luminance() < Color.GRAY.luminance())
    assert_true(Color.GRAY.luminance() < Color.LIGHT_GRAY.luminance())


def test_luminance_weights_green_over_blue() raises -> None:
    assert_true(Color.GREEN.luminance() > Color.RED.luminance())
    assert_true(Color.RED.luminance() > Color.BLUE.luminance())


def test_to_hsv_primaries() raises -> None:
    var r = Color.RED.to_hsv()
    assert_almost_equal(r[0], 0.0)
    assert_almost_equal(r[1], 1.0)
    assert_almost_equal(r[2], 1.0)
    var g = Color.GREEN.to_hsv()
    assert_almost_equal(g[0], 120.0)
    var b = Color.BLUE.to_hsv()
    assert_almost_equal(b[0], 240.0)


def test_to_hsv_secondaries() raises -> None:
    assert_almost_equal(Color.YELLOW.to_hsv()[0], 60.0)
    assert_almost_equal(Color.CYAN.to_hsv()[0], 180.0)
    assert_almost_equal(Color.MAGENTA.to_hsv()[0], 300.0)


def test_to_hsv_gray_has_no_hue() raises -> None:
    var c = Color.GRAY.to_hsv()
    assert_almost_equal(c[0], 0.0)
    assert_almost_equal(c[1], 0.0)


def test_to_hsv_black_is_zero_value() raises -> None:
    var c = Color.BLACK.to_hsv()
    assert_almost_equal(c[1], 0.0)
    assert_almost_equal(c[2], 0.0)


def test_hsv_round_trip() raises -> None:
    var original = Color.hex(0x336699)
    var h = original.to_hsv()
    assert_equal(Color.hsv(h[0], h[1], h[2]), original)


def test_over_opaque_source_replaces() raises -> None:
    assert_equal(Color.RED.over(Color.BLUE), Color.RED)


def test_over_transparent_source_keeps_destination() raises -> None:
    assert_equal(Color(255, 0, 0, 0).over(Color.BLUE), Color.BLUE)


def test_over_half_alpha_is_midpoint() raises -> None:
    var c = Color(255, 255, 255, 128).over(Color.BLACK)
    assert_equal(c.r, UInt8(128))
    assert_equal(c.g, UInt8(128))
    assert_equal(c.b, UInt8(128))


def test_over_stays_opaque_on_opaque_destination() raises -> None:
    assert_equal(Color(0, 0, 0, 1).over(Color.WHITE).a, UInt8(255))
    assert_equal(Color(0, 0, 0, 128).over(Color.WHITE).a, UInt8(255))


def test_over_accumulates_alpha_on_translucent_destination() raises -> None:
    var c = Color(0, 0, 0, 128).over(Color(0, 0, 0, 128))
    assert_equal(c.a, UInt8(191))


def test_over_per_channel() raises -> None:
    var c = Color(255, 0, 0, 128).over(Color(0, 0, 255))
    assert_equal(c.r, UInt8(128))
    assert_equal(c.g, UInt8(0))
    assert_equal(c.b, UInt8(127))


def test_over_repeated_converges_on_source() raises -> None:
    var c = Color.BLACK
    for _ in range(16):
        c = Color(255, 255, 255, 64).over(c)
    assert_true(c.r > UInt8(240))


def test_with_alpha_keeps_rgb() raises -> None:
    var c = Color(12, 34, 56, 255).with_alpha(128)
    assert_equal(c.r, UInt8(12))
    assert_equal(c.g, UInt8(34))
    assert_equal(c.b, UInt8(56))
    assert_equal(c.a, UInt8(128))


def test_with_alpha_replaces_existing_alpha() raises -> None:
    assert_equal(Color(1, 2, 3, 64).with_alpha(255), Color(1, 2, 3, 255))


def test_with_alpha_composites_like_a_spelled_out_color() raises -> None:
    var a = Color.RED.with_alpha(128).over(Color.BLUE)
    var b = Color(255, 0, 0, 128).over(Color.BLUE)
    assert_equal(a, b)


def _close(actual: Float64, expected: Float64, within: Float64) -> Bool:
    return abs(actual - expected) <= within


def test_oklch_matches_published_values() raises -> None:
    # Reference values from Björn Ottosson's OKLab, as CSS's oklch() gives.
    var red = Color.RED.to_oklch()
    assert_true(_close(red[0], 0.62796, 0.001))
    assert_true(_close(red[1], 0.25768, 0.001))
    assert_true(_close(red[2], 29.2339, 0.1))
    var blue = Color(0, 0, 255).to_oklch()
    assert_true(_close(blue[0], 0.45201, 0.001))
    assert_true(_close(blue[1], 0.31321, 0.001))
    assert_true(_close(blue[2], 264.052, 0.1))
    var white = Color.WHITE.to_oklch()
    assert_true(_close(white[0], 1.0, 0.0001))
    assert_equal(white[1], 0.0)
    assert_equal(white[2], 0.0)  # a grey has no hue
    assert_true(_close(Color.BLACK.to_oklch()[0], 0.0, 0.0001))


def test_oklch_builds_the_published_colours() raises -> None:
    assert_equal(Color.oklch(0.62796, 0.25768, 29.2339), Color.RED)
    assert_equal(Color.oklch(0.45201, 0.31321, 264.052), Color(0, 0, 255))
    assert_equal(Color.oklch(1, 0, 0), Color.WHITE)
    assert_equal(Color.oklch(0, 0, 0), Color.BLACK)


def test_oklch_round_trips_every_tenth_colour() raises -> None:
    for r in range(0, 256, 17):
        for g in range(0, 256, 17):
            for b in range(0, 256, 17):
                var color = Color(UInt8(r), UInt8(g), UInt8(b))
                var lch = color.to_oklch()
                assert_equal(Color.oklch(lch[0], lch[1], lch[2]), color)


def test_oklch_hue_wraps() raises -> None:
    assert_equal(Color.oklch(0.7, 0.1, 30), Color.oklch(0.7, 0.1, 390))
    assert_equal(Color.oklch(0.7, 0.1, 30), Color.oklch(0.7, 0.1, -330))


def test_oklch_too_vivid_keeps_its_lightness_and_hue() raises -> None:
    # Far more chroma than any screen shows at this lightness and hue.
    var color = Color.oklch(0.7, 0.5, 145)
    var lch = color.to_oklch()
    assert_true(_close(lch[0], 0.7, 0.01))
    assert_true(_close(lch[2], 145, 2))
    assert_true(lch[1] > 0.15)  # still as colourful as fits


def test_equal_oklch_lightness_looks_equally_light() raises -> None:
    # The point of OKLCH: a yellow and a blue at one lightness are about as
    # light as each other, which HSV's value can't promise.
    var yellow = Color.oklch(0.7, 0.12, 100)
    var blue = Color.oklch(0.7, 0.12, 260)
    assert_true(abs(yellow.luminance() - blue.luminance()) < 0.06)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
