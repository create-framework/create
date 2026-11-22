"""`ColorScheme` and `Theme`: the light and dark schemes, colours given to
replace their own, and schemes from a seed colour."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from create.ui.theme import _contrast
from create.ui.layer import _body_text, _label_text, _over


def _pairs(c: ColorScheme) -> List[Tuple[Color, Color]]:
    return [
        (c.primary, c.on_primary),
        (c.primary_container, c.on_primary_container),
        (c.secondary, c.on_secondary),
        (c.secondary_container, c.on_secondary_container),
        (c.tertiary, c.on_tertiary),
        (c.tertiary_container, c.on_tertiary_container),
        (c.error, c.on_error),
        (c.error_container, c.on_error_container),
        (c.surface, c.on_surface),
        (c.surface_dim, c.on_surface),
        (c.surface_bright, c.on_surface),
        (c.surface_container_lowest, c.on_surface),
        (c.surface_container_low, c.on_surface),
        (c.surface_container, c.on_surface),
        (c.surface_container_high, c.on_surface),
        (c.surface_container_highest, c.on_surface),
        (c.surface_container_highest, c.on_surface_variant),
        (c.background, c.on_background),
    ]


def test_every_pair_of_the_built_in_schemes_reads_well() raises -> None:
    for scheme in [ColorScheme.light(), ColorScheme.dark()]:
        for pair in _pairs(scheme):
            assert_true(_contrast(pair[0], pair[1]) >= 4.5, String(pair[0]))


def test_every_pair_of_a_scheme_from_a_given_surface_reads_well() raises -> (
    None
):
    for colors in [
        ColorScheme.light(surface=Color.hex(0xFFF8E7)),
        ColorScheme.dark(surface=Color.BLACK),
        ColorScheme.dark(surface=Color.hex(0x202830)),
    ]:
        for pair in _pairs(colors):
            assert_true(_contrast(pair[0], pair[1]) >= 4.5, String(pair[0]))


def test_the_surface_containers_step_away_from_the_surface() raises -> None:
    for c in [
        ColorScheme.light(surface=Color.WHITE),
        ColorScheme.dark(surface=Color.BLACK),
    ]:
        var steps = [
            c.surface_container_low,
            c.surface_container,
            c.surface_container_high,
            c.surface_container_highest,
        ]
        var last = 1.0
        for step in steps:
            var contrast = _contrast(c.surface, step)
            assert_true(contrast > last)
            last = contrast
        assert_equal(c.background, c.surface)


def test_a_colour_given_gets_a_readable_partner() raises -> None:
    var colors = ColorScheme.light(primary=Color.ORANGE)
    assert_equal(colors.primary, Color.ORANGE)
    assert_equal(colors.on_primary, Color.BLACK)
    var dark = ColorScheme.dark(primary=Color.hex(0x203080))
    assert_equal(dark.on_primary, Color.WHITE)


def test_a_partner_given_is_kept() raises -> None:
    var colors = ColorScheme.light(primary=Color.ORANGE, on_primary=Color.WHITE)
    assert_equal(colors.on_primary, Color.WHITE)


def test_a_colour_given_changes_its_container() raises -> None:
    var colors = ColorScheme.light(primary=Color.ORANGE)
    var default = ColorScheme.light()
    assert_true(colors.primary_container != default.primary_container)
    assert_true(
        _contrast(
            colors.primary_container,
            colors.on_primary_container,
        )
        >= 4.5
    )


def test_a_surface_given_changes_the_colours_drawn_on_it() raises -> None:
    var colors = ColorScheme.dark(surface=Color.BLACK)
    assert_equal(colors.surface, Color.BLACK)
    assert_equal(colors.on_surface, Color.WHITE)
    assert_true(colors.outline != ColorScheme.dark().outline)


def test_a_theme_takes_its_colours_from_the_scheme() raises -> None:
    assert_equal(
        String(Theme.light(primary=Color.ORANGE).colors),
        String(ColorScheme.light(primary=Color.ORANGE)),
    )
    assert_equal(
        String(Theme.from_seed(Color.ORANGE, dark=True).colors),
        String(ColorScheme.from_seed(Color.ORANGE, dark=True)),
    )


def test_the_ui_draws_in_the_theme_it_is_given() raises -> None:
    var ui = UI(Theme.dark())
    assert_equal(ui.theme().colors.surface, ColorScheme.dark().surface)
    ui.theme(Theme.light())
    var context = Context()
    var canvas = Canvas(16, 16)
    with ui.screen(context, canvas) as layer:
        assert_equal(layer.theme().colors.surface, ColorScheme.light().surface)


def _seeds() -> List[Color]:
    return [
        Color.hex(0xFFD400),  # yellow
        Color.hex(0x2050E0),  # blue
        Color.hex(0x808080),  # grey
        Color.hex(0xE07A2E),  # orange
        Color.hex(0x1FA060),  # green
        Color.hex(0xD02030),  # red
        Color.hex(0x8040C0),  # purple
    ]


def test_every_pair_of_a_seeded_scheme_reads_well() raises -> None:
    for seed in _seeds():
        for dark in [False, True]:
            var colors = ColorScheme.from_seed(seed, dark=dark)
            for pair in _pairs(colors):
                assert_true(
                    _contrast(pair[0], pair[1]) >= 4.5,
                    String(
                        seed, " dark=", dark, ": ", pair[0], " on ", pair[1]
                    ),
                )


def test_a_seeded_primary_keeps_the_seeds_hue() raises -> None:
    var seed = Color.hex(0x2050E0)
    var primary = ColorScheme.from_seed(seed).primary.to_oklch()
    assert_true(abs(primary[2] - seed.to_oklch()[2]) < 5)
    assert_true(primary[1] > 0.08)  # a blue, not a grey


def test_a_grey_seed_gives_grey_colours() raises -> None:
    var colors = ColorScheme.from_seed(Color.hex(0x808080))
    assert_true(colors.primary.to_oklch()[1] < 0.02)
    assert_true(colors.surface.to_oklch()[1] < 0.02)


def test_a_seeded_tertiary_is_turned_round_the_wheel() raises -> None:
    var seed = Color.hex(0x2050E0)
    var colors = ColorScheme.from_seed(seed)
    var turned = colors.tertiary.to_oklch()[2] - colors.primary.to_oklch()[2]
    if turned < 0:
        turned += 360
    assert_true(abs(turned - 60) < 8)


def test_every_built_in_theme_has_a_control_height_of_40() raises -> None:
    for theme in [
        Theme.light(),
        Theme.dark(),
        Theme.from_seed(Color.hex(0x2050E0)),
        Theme.from_seed(Color.hex(0x2050E0), dark=True),
    ]:
        assert_equal(theme.control_height, 40.0)


def test_a_theme_prints_its_control_height() raises -> None:
    assert_true("control_height=40.0" in String(Theme.light()))


def test_widgets_draw_their_text_in_the_default_styles() raises -> None:
    assert_equal(_body_text().font_size.value(), 16.0)
    assert_equal(_body_text().font_weight.value(), FontWeight.REGULAR)
    assert_equal(_label_text().font_size.value(), 14.0)
    assert_equal(_label_text().font_weight.value(), FontWeight.MEDIUM)
    assert_false(Bool(_body_text().text_color))  # set where it is drawn


def test_a_widgets_text_style_keeps_the_rest_of_the_default() raises -> None:
    var label = _label_text()
    var bigger = _over(Style(font_size=30), label)
    assert_equal(bigger.font_size.value(), 30.0)
    assert_equal(bigger.font_weight.value(), FontWeight.MEDIUM)
    assert_equal(String(_over(None, label)), String(label))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
