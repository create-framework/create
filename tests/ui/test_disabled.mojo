"""Disabled widgets: `disabled=True` on a call, or `ui.disabled` around a
block. They are drawn faded, ignore the pointer and return `False`, but
still cover what is beneath them."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, release

comptime _A = Rectangle((0, 0), 120, 40)


def _click(
    mut ui: UI, mut context: Context, disabled: Bool, scoped: Bool
) raises -> Bool:
    """Two frames of a button at `_A`, clicked in the second: what it
    returned then."""
    var canvas = Canvas(200, 100)
    var clicked = False
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, _A.position)
            release(context, _A.position)
        with ui.screen(context, canvas) as layer:
            with layer.disabled(scoped):
                clicked = layer.button("OK", _A, disabled=disabled)
    return clicked


def test_a_disabled_button_does_not_click() raises -> None:
    var context = Context()
    point_at(context, _A.position)
    var ui = UI()
    assert_false(_click(ui, context, disabled=True, scoped=False))


def test_a_disabled_block_disables_its_widgets() raises -> None:
    var context = Context()
    point_at(context, _A.position)
    var ui = UI()
    assert_false(_click(ui, context, disabled=False, scoped=True))


def test_a_block_disabled_on_a_false_condition_works_as_usual() raises -> None:
    var context = Context()
    point_at(context, _A.position)
    var ui = UI()
    assert_true(_click(ui, context, disabled=False, scoped=False))


def test_nested_blocks_end_where_they_end() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100)
    with ui.screen(context, canvas) as layer:
        with layer.disabled():
            with layer.disabled(False):
                assert_true(layer._disabled(False))  # the outer block holds
            assert_true(layer._disabled(False))
        assert_false(layer._disabled(False))


def test_a_disabled_widget_covers_what_is_beneath() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, _A.position)
    var canvas = Canvas(200, 100)
    var below_clicked = False
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, _A.position)
            release(context, _A.position)
        with ui.screen(context, canvas) as layer:
            below_clicked = layer.button("Below", _A)
            _ = layer.button("Above", _A, disabled=True)
    assert_false(below_clicked)


def test_a_disabled_slider_keeps_its_value() raises -> None:
    var ui = UI()
    var context = Context()
    var value = 0.5
    point_at(context, Point(40, 0))
    var canvas = Canvas(200, 100)
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, Point(40, 0))
        with ui.screen(context, canvas) as layer:
            layer.slider(value, 0, 1, _A, disabled=True)
            assert_false(layer.changed())
    assert_equal(value, 0.5)


def test_a_disabled_button_is_drawn_faded() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    canvas.background(ColorScheme.light().surface)
    with ui.screen(context, canvas) as layer:
        _ = layer.button("OK", _A, disabled=True)
    var colors = ColorScheme.light()
    var expected = colors.surface.lerp(
        colors.on_surface, ui.state_layers().disabled_container
    )
    var pixel = canvas.color_at(_A.position + Vector(40.0, 0.0))
    assert_true(abs(Int(pixel.r) - Int(expected.r)) <= 2)
    assert_true(abs(Int(pixel.g) - Int(expected.g)) <= 2)
    assert_true(abs(Int(pixel.b) - Int(expected.b)) <= 2)


def test_a_disabled_widget_on_a_panel_is_drawn_against_it() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    var value = 0.5
    with ui.screen(context, canvas) as layer:
        with layer.panel(
            Rectangle((0, 0), 200, 100), style=Style(fill=Color.BLACK)
        ):
            layer.slider(value, 0, 1, _A, disabled=True)
    var colors = ColorScheme.light()
    # the handle, solid over the track: the panel's black towards on_surface
    var expected = Color.BLACK.lerp(
        colors.on_surface, ui.state_layers().disabled_content
    )
    var pixel = canvas.color_at(_A.position)
    assert_true(abs(Int(pixel.r) - Int(expected.r)) <= 2)
    assert_true(abs(Int(pixel.g) - Int(expected.g)) <= 2)
    assert_true(abs(Int(pixel.b) - Int(expected.b)) <= 2)


def _label_and_image(disabled: Bool) raises -> Canvas:
    """A black label at `_A` and a red image under it, in a block disabled
    or not, on white."""
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    var pixels = List[UInt8]()
    for _ in range(4):
        pixels += [255, 0, 0, 255]
    var red = Image.from_rgba(2, 2, pixels)
    with ui.screen(context, canvas) as layer:
        with layer.disabled(disabled):
            layer.image(red, Rectangle((0, -40), 40, 10))
            layer.label(
                "MMMM", _A, style=Style(text_color=Color.BLACK, font_size=30)
            )
    return canvas^


def _darkest(mut canvas: Canvas) raises -> Int:
    """The lowest red channel across `_A`: how dark the label's ink is."""
    var darkest = 255
    for x in range(-60, 60):
        for y in range(-20, 20):
            var pixel = canvas.color_at((Float64(x) + 0.5, Float64(y) + 0.5))
            darkest = min(darkest, Int(pixel.r))
    return darkest


def test_a_disabled_block_fades_labels_and_images() raises -> None:
    var usual = _label_and_image(False)
    var faded = _label_and_image(True)
    assert_equal(_darkest(usual), 0)
    assert_true(_darkest(faded) > 100)  # black at 38%: a mid grey
    assert_equal(usual.color_at((0, -40)), Color.RED)
    var pink = faded.color_at((0, -40))
    assert_true(pink.g > 100 and pink.r == 255)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
