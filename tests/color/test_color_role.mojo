"""`ColorRole` and `OptionalColor`: a colour named by what it is for, and
the colour keywords that take either one or a `Color`."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *


def test_a_scheme_gives_each_role_its_colour() raises -> None:
    var scheme = ColorScheme.dark()
    assert_equal(scheme[ColorRole.PRIMARY], scheme.primary)
    assert_equal(
        scheme[ColorRole.ON_ERROR_CONTAINER], scheme.on_error_container
    )
    assert_equal(
        scheme[ColorRole.SURFACE_CONTAINER_HIGHEST],
        scheme.surface_container_highest,
    )
    assert_equal(scheme[ColorRole.OUTLINE_VARIANT], scheme.outline_variant)
    assert_equal(scheme[ColorRole.ON_BACKGROUND], scheme.on_background)


def test_a_raised_surface_is_lighter_than_the_surface() raises -> None:
    var schemes = [
        ColorScheme.light(),
        ColorScheme.dark(),
        ColorScheme.from_seed(Color.hex(0xE07A2E)),
        ColorScheme.from_seed(Color.hex(0xE07A2E), dark=True),
        ColorScheme.light(surface=Color.hex(0xF0E8D8)),
        ColorScheme.dark(surface=Color.hex(0x202830)),
    ]
    for scheme in schemes:
        assert_true(
            scheme.surface_raised.luminance() > scheme.surface.luminance()
        )
        assert_equal(scheme[ColorRole.SURFACE_RAISED], scheme.surface_raised)
    assert_equal(String(ColorRole.SURFACE_RAISED), "ColorRole.SURFACE_RAISED")


def test_a_role_prints_its_name() raises -> None:
    assert_equal(String(ColorRole.PRIMARY), "ColorRole.PRIMARY")
    assert_equal(String(ColorRole.ON_BACKGROUND), "ColorRole.ON_BACKGROUND")


def test_an_optional_colour_takes_a_colour_a_role_or_nothing() raises -> None:
    var scheme = ColorScheme.light()
    var color: OptionalColor = Color.RED
    var role: OptionalColor = ColorRole.SECONDARY
    var nothing: OptionalColor = None
    assert_true(Bool(color) and Bool(role))
    assert_false(Bool(nothing))
    assert_equal(color.resolve(scheme), Color.RED)
    assert_equal(role.resolve(scheme), scheme.secondary)
    assert_true(role.role().value() == ColorRole.SECONDARY)
    assert_false(Bool(color.role()))
    assert_equal(nothing.or_else(Color.BLUE, scheme), Color.BLUE)
    assert_equal(String(color), "Color(255, 0, 0, 255)")
    assert_equal(String(role), "ColorRole.SECONDARY")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
