from std.testing import TestSuite, assert_equal, assert_true, assert_false

from create import *
from create.render._text import _pixel_size
from create.render._transform import stroke_thickness_px
from create.render.style import _ResolvedStyle


def _r(s: Style) -> _ResolvedStyle:
    """`s` applied to a fresh frame's style."""
    return s._resolved(ColorScheme.light())


def test_a_fresh_frames_style() raises -> None:
    var s = _ResolvedStyle()
    assert_equal(s.fill_color, Color.WHITE)
    assert_false(s.fill_enabled)
    assert_equal(s.stroke_color, Color.BLACK)
    assert_equal(s.stroke_thickness, 1)
    assert_true(s.stroke_enabled)
    assert_true(s.stroke_alignment == StrokeAlign.INSIDE)
    assert_true(s.stroke_cap == StrokeCap.BUTT)
    assert_true(s.stroke_dash == StrokeDash.SOLID)
    assert_equal(s.text_color, Color.BLACK)
    assert_equal(s.font_size, 16)
    assert_equal(s.font_weight, FontWeight.REGULAR)
    assert_false(s.font_italic)
    assert_true(s.text_alignment == Align.CENTER)
    assert_equal(s.tint, Color.WHITE)
    assert_equal(s.opacity, 1.0)
    assert_true(s.blend_mode == BlendMode.NORMAL)
    assert_equal(s.shadow_color, Color(0, 0, 0, 96))
    assert_equal(s.shadow_offset, Vector(4, -4))
    assert_equal(s.shadow_blur, 8.0)
    assert_equal(s.shadow_spread, 0.0)
    assert_false(s.shadow_inset)
    assert_false(s.shadow_follows_transform)
    assert_false(s.shadow_enabled)


def test_an_empty_style_sets_nothing() raises -> None:
    var s = Style()
    assert_false(Bool(s.fill))
    assert_false(Bool(s.stroke_thickness))
    assert_false(Bool(s.stroke_enabled))
    assert_false(Bool(s.text_alignment))
    assert_false(Bool(s.shadow_enabled))
    assert_equal(String(s), "Style()")


def test_a_style_holds_only_what_it_was_given() raises -> None:
    var s = Style(fill=Color.RED, corner_radius=4)
    assert_true(s.fill == Color.RED)
    assert_equal(s.corner_radius.value(), 4.0)
    assert_false(Bool(s.fill_enabled))  # switched on when applied, not here
    assert_false(Bool(s.stroke))
    assert_false(Bool(s.font_size))


def test_number_fields_take_integers() raises -> None:
    var thickness = 3
    var s = Style()
    s.stroke_thickness = thickness
    s.corner_radius = 4
    s.opacity = 1
    assert_equal(s.stroke_thickness.value(), 3.0)
    assert_equal(s.corner_radius.value(), 4.0)
    assert_equal(s.opacity.value(), 1.0)


def test_each_keyword_lands_in_its_field() raises -> None:
    var s = _r(
        Style(
            fill=Color.RED,
            fill_enabled=False,
            stroke=Color.BLUE,
            stroke_thickness=3,
            stroke_enabled=False,
            stroke_alignment=StrokeAlign.OUTSIDE,
            stroke_cap=StrokeCap.ROUND,
            stroke_dash=StrokeDash.DASHED,
            corner_radius=5,
            text_color=Color.WHITE,
            font_size=32,
            font_weight=FontWeight.BOLD,
            font_italic=True,
            text_alignment=Align.TOP_LEFT,
            tint=Color.RED,
            opacity=0.5,
            blend_mode=BlendMode.ADD,
            shadow=Color.RED,
            shadow_offset=Vector(1, 2),
            shadow_blur=3.0,
            shadow_spread=-1.0,
            shadow_inset=True,
            shadow_follows_transform=True,
            shadow_enabled=True,
        )
    )
    assert_equal(s.fill_color, Color.RED)
    assert_false(s.fill_enabled)
    assert_equal(s.stroke_color, Color.BLUE)
    assert_equal(s.stroke_thickness, 3)
    assert_false(s.stroke_enabled)
    assert_true(s.stroke_alignment == StrokeAlign.OUTSIDE)
    assert_true(s.stroke_cap == StrokeCap.ROUND)
    assert_true(s.stroke_dash == StrokeDash.DASHED)
    assert_equal(s.corner_radius, 5.0)
    assert_equal(s.text_color, Color.WHITE)
    assert_equal(s.font_size, 32)
    assert_equal(s.font_weight, FontWeight.BOLD)
    assert_true(s.font_italic)
    assert_true(s.text_alignment == Align.TOP_LEFT)
    assert_equal(s.tint, Color.RED)
    assert_equal(s.opacity, 0.5)
    assert_true(s.blend_mode == BlendMode.ADD)
    assert_equal(s.shadow_color, Color.RED)
    assert_equal(s.shadow_offset, Vector(1, 2))
    assert_equal(s.shadow_blur, 3.0)
    assert_equal(s.shadow_spread, -1.0)
    assert_true(s.shadow_inset)
    assert_true(s.shadow_follows_transform)
    assert_true(s.shadow_enabled)


def test_naming_a_part_switches_its_property_on() raises -> None:
    assert_true(_r(Style(fill=Color.RED)).fill_enabled)
    assert_true(_r(Style(shadow=Color.RED)).shadow_enabled)
    assert_true(_r(Style(shadow_offset=Vector(1, 2))).shadow_enabled)
    assert_true(_r(Style(shadow_blur=12)).shadow_enabled)
    assert_true(_r(Style(shadow_spread=0)).shadow_enabled)
    assert_true(_r(Style(shadow_inset=False)).shadow_enabled)
    assert_false(_r(Style(shadow_follows_transform=True)).shadow_enabled)


def test_an_explicit_enabled_beside_a_part_wins() raises -> None:
    var s = _r(Style(shadow=Color.RED, shadow_enabled=False))
    assert_false(s.shadow_enabled)
    assert_equal(s.shadow_color, Color.RED)
    assert_false(
        _r(Style(stroke=Color.RED, stroke_enabled=False)).stroke_enabled
    )
    assert_false(_r(Style(fill=Color.RED, fill_enabled=False)).fill_enabled)


def test_over_takes_each_part_from_the_top_style_first() raises -> None:
    var base = Style(fill=Color.WHITE, stroke=Color.BLUE, corner_radius=12)
    var s = Style(fill=Color.RED, font_size=20).over(base)
    assert_true(s.fill == Color.RED)
    assert_true(s.stroke == Color.BLUE)
    assert_equal(s.corner_radius.value(), 12.0)
    assert_equal(s.font_size.value(), 20.0)
    assert_false(Bool(s.text_color))


def test_over_an_empty_style_changes_nothing() raises -> None:
    var s = Style(fill=Color.RED, shadow_blur=4)
    assert_equal(String(s.over(Style())), String(s))
    assert_equal(String(Style().over(s)), String(s))


def test_over_is_applying_the_base_then_the_top() raises -> None:
    # a part named on top switches on what the base switched off
    var outlined = Style(stroke_thickness=2).over(Style(stroke_enabled=False))
    assert_true(_r(outlined).stroke_enabled)
    assert_true(
        _r(Style(fill=Color.RED).over(Style(fill_enabled=False))).fill_enabled
    )
    assert_true(
        _r(
            Style(shadow_blur=4).over(Style(shadow_enabled=False))
        ).shadow_enabled
    )
    # an explicit switch on top still wins
    var off = Style(stroke=Color.RED, stroke_enabled=False)
    assert_false(_r(off.over(Style(stroke_enabled=True))).stroke_enabled)
    # a fill colour on top clears the base's gradient
    var sky = Gradient.linear(Color.RED, Color.BLUE)
    var solid = _r(Style(fill=Color.GREEN).over(Style(fill_gradient=sky)))
    assert_false(Bool(solid.fill_gradient))
    assert_equal(solid.fill_color, Color.GREEN)


def test_style_writes_only_what_it_sets() raises -> None:
    assert_equal(
        String(Style(fill=Color.RED, corner_radius=4)),
        "Style(fill=Color(255, 0, 0, 255), corner_radius=4.0)",
    )
    assert_equal(
        String(
            Style(
                stroke_cap=StrokeCap.ROUND,
                text_alignment=Align.LEFT,
                shadow_offset=Vector(0, -3),
                shadow_enabled=False,
            )
        ),
        (
            "Style(stroke_cap=StrokeCap.ROUND, text_alignment=Align.LEFT,"
            " shadow_offset=Vector(0.0, -3.0), shadow_enabled=False)"
        ),
    )


def test_a_role_is_a_colour_of_the_scheme_it_is_applied_in() raises -> None:
    var s = Style(fill=ColorRole.PRIMARY, text_color=ColorRole.ON_PRIMARY)
    assert_true(s.fill.role().value() == ColorRole.PRIMARY)
    var dark = s._resolved(ColorScheme.dark())
    assert_equal(dark.fill_color, ColorScheme.dark().primary)
    assert_equal(dark.text_color, ColorScheme.dark().on_primary)
    assert_true(dark.fill_enabled)
    assert_equal(_r(s).fill_color, ColorScheme.light().primary)


def test_a_style_prints_a_role_by_its_name() raises -> None:
    assert_equal(
        String(Style(fill=ColorRole.SURFACE_CONTAINER)),
        "Style(fill=ColorRole.SURFACE_CONTAINER)",
    )


def test_a_canvas_draws_a_role_in_its_colours() raises -> None:
    var canvas = Canvas(40, 40, antialiasing=Antialiasing.OFF)
    canvas.colors(ColorScheme.dark())
    with canvas.style(Style(fill=ColorRole.PRIMARY, stroke_enabled=False)):
        canvas.rectangle((-10, 0), 20, 40)
    with canvas.style(fill=ColorRole.TERTIARY, stroke_enabled=False):
        canvas.rectangle((10, 0), 20, 40)
    assert_equal(canvas.color_at((-10, 0)), ColorScheme.dark().primary)
    assert_equal(canvas.color_at((10, 0)), ColorScheme.dark().tertiary)
    assert_equal(canvas.colors().primary, ColorScheme.dark().primary)


def test_stroke_cap_does_not_switch_the_stroke_on() raises -> None:
    var s = _r(Style(stroke_enabled=False, stroke_cap=StrokeCap.SQUARE))
    assert_false(s.stroke_enabled)
    assert_true(s.stroke_cap == StrokeCap.SQUARE)


def test_stroke_alignment_does_not_switch_the_stroke_on() raises -> None:
    var s = _r(Style(stroke_enabled=False, stroke_alignment=StrokeAlign.CENTER))
    assert_false(s.stroke_enabled)
    assert_true(s.stroke_alignment == StrokeAlign.CENTER)


def test_stroke_alignment_prints_its_name() raises -> None:
    assert_equal(String(StrokeAlign.INSIDE), "StrokeAlign.INSIDE")
    assert_equal(String(StrokeAlign.CENTER), "StrokeAlign.CENTER")
    assert_equal(String(StrokeAlign.OUTSIDE), "StrokeAlign.OUTSIDE")
    assert_equal(String(StrokeAlign(7)), "StrokeAlign(7)")


def test_stroke_alignment_moves_the_stroke_out_by_a_fraction() raises -> None:
    assert_equal(StrokeAlign.INSIDE._offset_fraction(), 0.0)
    assert_equal(StrokeAlign.CENTER._offset_fraction(), 0.5)
    assert_equal(StrokeAlign.OUTSIDE._offset_fraction(), 1.0)


def test_stroke_cap_prints_its_name() raises -> None:
    assert_equal(String(StrokeCap.BUTT), "StrokeCap.BUTT")
    assert_equal(String(StrokeCap.ROUND), "StrokeCap.ROUND")
    assert_equal(String(StrokeCap.SQUARE), "StrokeCap.SQUARE")
    assert_equal(String(StrokeCap(7)), "StrokeCap(7)")


def test_shadow_is_visible_only_when_enabled_and_opaque_enough() raises -> None:
    assert_false(
        Style()._resolved(ColorScheme.light())._paint()._shadow_visible()
    )
    assert_true(
        Style(shadow_enabled=True)
        ._resolved(ColorScheme.light())
        ._paint()
        ._shadow_visible()
    )
    assert_false(
        Style(shadow=Color.TRANSPARENT, shadow_enabled=True)
        ._resolved(ColorScheme.light())
        ._paint()
        ._shadow_visible()
    )


def test_fill_gradient_keyword_switches_the_fill_on() raises -> None:
    var sky = Gradient.linear(Color.RED, Color.BLUE)
    var s = _r(Style(fill_gradient=sky))
    assert_true(s.fill_enabled)
    assert_true(s.fill_gradient.value() == sky)
    assert_equal(s.fill_color, Color.WHITE)
    assert_false(_r(Style(fill_gradient=sky, fill_enabled=False)).fill_enabled)


def test_fill_gradient_beside_fill_keeps_both() raises -> None:
    var sky = Gradient.linear(Color.RED, Color.BLUE)
    var s = _r(Style(fill=Color.GREEN, fill_gradient=sky))
    assert_true(s.fill_gradient.value() == sky)
    assert_equal(s.fill_color, Color.GREEN)


def test_fill_visibility_follows_the_gradient() raises -> None:
    assert_true(
        Style(fill_gradient=Gradient.linear(Color.TRANSPARENT, Color.RED))
        ._resolved(ColorScheme.light())
        ._paint()
        ._fill_visible()
    )
    var clear = Gradient.linear(Color.TRANSPARENT, Color.TRANSPARENT)
    assert_false(
        Style(fill=Color.RED, fill_gradient=clear)
        ._resolved(ColorScheme.light())
        ._paint()
        ._fill_visible()
    )


def test_fractional_sizes_are_kept_as_given() raises -> None:
    var s = _r(Style(stroke_thickness=1.5, font_size=13.5))
    assert_equal(s.stroke_thickness, 1.5)
    assert_equal(s.font_size, 13.5)


def test_integer_literals_still_reach_the_float_keywords() raises -> None:
    var s = _r(Style(stroke_thickness=2, font_size=24))
    assert_equal(s.stroke_thickness, 2.0)
    assert_equal(s.font_size, 24.0)
    assert_true(
        _r(Style(stroke_thickness=3, stroke_enabled=False)).stroke_thickness
        == 3.0
    )


def test_fractional_sizes_round_once_scaled() raises -> None:
    """World-unit sizes become whole pixels only at the device: 1.5 units
    at 2 pixels a unit is exactly 3 pixels."""
    var s = Style(stroke_thickness=1.5, font_size=13.5)
    assert_equal(
        stroke_thickness_px(
            s._resolved(ColorScheme.light())._paint(), Transform(scale=2.0), 2.0
        ),
        3,
    )
    assert_equal(
        stroke_thickness_px(
            s._resolved(ColorScheme.light())._paint(), Transform(scale=1.0), 1.0
        ),
        2,
    )
    assert_equal(
        _pixel_size(s._resolved(ColorScheme.light())._text_style(), 2.0), 27
    )


def test_unset_number_keywords_take_none_or_any_number() raises -> None:
    # An integer literal, a float, `None` and a forwarded `Optional` all
    # reach a number keyword, like every other optional keyword.
    var s = _r(Style(shadow_blur=12, shadow_spread=1.5))
    assert_equal(s.shadow_blur, 12.0)
    assert_equal(s.shadow_spread, 1.5)
    assert_true(s.shadow_enabled)

    var unset = _r(Style(shadow_blur=None, stroke_thickness=None))
    assert_equal(unset.shadow_blur, 8.0)
    assert_equal(unset.stroke_thickness, 1.0)
    assert_false(unset.shadow_enabled)

    var forwarded: Optional[Float64] = 3.0
    assert_equal(_r(Style(stroke_thickness=forwarded)).stroke_thickness, 3.0)


def test_float_keywords_take_an_int_variable() raises -> None:
    var radius: Int = 6
    var size: Int = 24
    var opacity: Int = 0
    var s = _r(Style(corner_radius=radius, font_size=size, opacity=opacity))
    assert_equal(s.corner_radius, 6.0)
    assert_equal(s.font_size, 24.0)
    assert_equal(s.opacity, 0.0)
    var defaults = _r(Style())
    assert_equal(defaults.corner_radius, 0.0)
    assert_equal(defaults.font_size, 16.0)
    assert_equal(defaults.opacity, 1.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
