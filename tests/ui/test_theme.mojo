"""`_Theme`: a widget's look worked out from a theme value and its state,
with no `UI`."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from create.ui._theme import _Theme, _faded


def test_the_default_theme_is_a_fresh_uis() raises -> None:
    var fresh = UI()._theme()
    var default = _Theme.default()
    assert_equal(default.corner_radius, fresh.corner_radius)
    assert_equal(default.spacing, fresh.spacing)
    assert_equal(default.control_height, fresh.control_height)
    assert_equal(default.surface, fresh.surface)
    assert_equal(default.content, fresh.content)
    assert_equal(default.colors.primary, ColorScheme.light().primary)


def test_a_button_look_follows_its_state() raises -> None:
    var theme = _Theme.default()
    var rest = theme.button(
        Style(),
        40,
        hovered=False,
        pressed=False,
        disabled=False,
    )
    var hovered = theme.button(
        Style(),
        40,
        hovered=True,
        pressed=False,
        disabled=False,
    )
    assert_equal(rest.body.value().fill_color, theme.colors.primary)
    assert_true(hovered.body.value().fill_color != theme.colors.primary)
    assert_false(rest.layer)
    assert_equal(rest.corner_radius, 4.0)  # the controls' radius
    assert_equal(rest.text.text_color, theme.colors.on_primary)


def test_a_text_button_hovers_with_a_layer() raises -> None:
    var look = _Theme.default().button(
        Button.TEXT,
        40,
        hovered=True,
        pressed=False,
        disabled=False,
    )
    assert_false(look.body)
    assert_true(look.layer)


def test_a_disabled_checkbox_fades() raises -> None:
    var theme = _Theme.default()
    var look = theme.checkbox(
        Style(),
        Style(),
        Style(),
        Style(),
        checked=True,
        hovered=False,
        pressed=False,
        disabled=True,
    )
    assert_true(look.box.fill_color.a < theme.colors.on_surface.a)
    assert_equal(look.tick.stroke_color, theme.surface)


def test_a_fade_past_either_end_stays_in_range() raises -> None:
    # A disabled widget fades its text by `disabled_content`: set above 1,
    # the text is as solid as it can be, not wrapped round to faint.
    var layers = StateLayers()
    layers.disabled_content = 1.5
    var ui = UI()
    ui.state_layers(layers)
    var button = ui.add(Button("B", Rectangle((0, 0), 100, 40), enabled=False))
    var context = Context()
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    assert_equal(ui[button]._look.text.text_color.a, 255)
    assert_equal(_faded(Color(10, 20, 30, 200), -0.5).a, 0)
    assert_equal(_faded(Color(10, 20, 30, 200), 0.5).a, 100)


def test_panels_and_popups_are_rounder_than_controls() raises -> None:
    var theme = _Theme.default()
    theme.corner_radius = 6
    assert_equal(theme.panel(Style()).style.corner_radius, 12.0)
    var dropdown = theme.dropdown(
        Style(), Style(), Style(), hovered=False, pressed=False, disabled=False
    )
    assert_equal(dropdown.field.corner_radius, 6.0)
    assert_equal(dropdown.list.corner_radius, 12.0)
    theme.corner_radius = 20
    var box = theme.checkbox(
        Style(),
        Style(),
        Style(),
        Style(),
        checked=False,
        hovered=False,
        pressed=False,
        disabled=False,
    )
    assert_equal(box.box.corner_radius, 4.5)  # still a box


def test_a_slider_and_a_progress_bar_have_the_same_track() raises -> None:
    var theme = _Theme.default()
    var slider = theme.slider(
        Style(), Style(), Style(), hovered=False, dragging=False, disabled=False
    )
    var bar = theme.progress_bar(Style(), Style(), disabled=False)
    assert_equal(slider.track.stroke_thickness, bar.track.stroke_thickness)
    assert_equal(slider.track.stroke_color, bar.track.stroke_color)
    assert_equal(bar.track.stroke_color, theme.colors.outline_variant)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
