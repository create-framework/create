"""`Theme`: the light and dark schemes, and colours given to replace their
own."""
from std.testing import TestSuite, assert_equal, assert_true

from create import *
from create.ui.theme import _contrast


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
    for theme in [
        Theme.light(surface=Color.hex(0xFFF8E7)),
        Theme.dark(surface=Color.BLACK),
        Theme.dark(surface=Color.hex(0x202830)),
    ]:
        for pair in _pairs(theme.colors):
            assert_true(_contrast(pair[0], pair[1]) >= 4.5, String(pair[0]))


def test_the_surface_containers_step_away_from_the_surface() raises -> None:
    for theme in [
        Theme.light(surface=Color.WHITE),
        Theme.dark(surface=Color.BLACK),
    ]:
        var c = theme.colors
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
    var theme = Theme.light(primary=Color.ORANGE)
    assert_equal(theme.colors.primary, Color.ORANGE)
    assert_equal(theme.colors.on_primary, Color.BLACK)
    var dark = Theme.dark(primary=Color.hex(0x203080))
    assert_equal(dark.colors.on_primary, Color.WHITE)


def test_a_partner_given_is_kept() raises -> None:
    var theme = Theme.light(primary=Color.ORANGE, on_primary=Color.WHITE)
    assert_equal(theme.colors.on_primary, Color.WHITE)


def test_a_colour_given_changes_its_container() raises -> None:
    var theme = Theme.light(primary=Color.ORANGE)
    var default = Theme.light()
    assert_true(
        theme.colors.primary_container != default.colors.primary_container
    )
    assert_true(
        _contrast(
            theme.colors.primary_container,
            theme.colors.on_primary_container,
        )
        >= 4.5
    )


def test_a_surface_given_changes_the_colours_drawn_on_it() raises -> None:
    var theme = Theme.dark(surface=Color.BLACK)
    assert_equal(theme.colors.surface, Color.BLACK)
    assert_equal(theme.colors.on_surface, Color.WHITE)
    assert_true(theme.colors.outline != Theme.dark().colors.outline)


def test_the_ui_draws_in_the_theme_it_is_given() raises -> None:
    var ui = UI(Theme.dark())
    assert_equal(ui.theme().colors.surface, ColorScheme.dark().surface)
    ui.theme(Theme.light())
    var context = Context()
    var canvas = Canvas(16, 16)
    with ui.screen(context, canvas) as layer:
        assert_equal(layer.theme().colors.surface, ColorScheme.light().surface)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
