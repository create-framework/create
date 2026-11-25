"""`_Theme`: a widget's look worked out from a theme value and its state,
with no `UI`."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from create.ui.ui import _ImmediateUI
from create.ui._theme import _Theme


def test_the_default_theme_is_a_fresh_uis() raises -> None:
    var fresh = _ImmediateUI()._theme()
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
        ButtonVariant.FILLED,
        40,
        hovered=False,
        pressed=False,
        disabled=False,
    )
    var hovered = theme.button(
        Style(),
        ButtonVariant.FILLED,
        40,
        hovered=True,
        pressed=False,
        disabled=False,
    )
    assert_equal(rest.body.value().fill_color, theme.colors.primary)
    assert_true(hovered.body.value().fill_color != theme.colors.primary)
    assert_false(rest.layer)
    assert_equal(rest.corner_radius, 20.0)  # a pill
    assert_equal(rest.text.text_color, theme.colors.on_primary)


def test_a_text_button_hovers_with_a_layer() raises -> None:
    var look = _Theme.default().button(
        Style(),
        ButtonVariant.TEXT,
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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
