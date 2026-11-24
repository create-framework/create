"""`ui.button`: a click is a press and a release over the same button, only
the topmost of two overlapping buttons reacts, and the hovered and pressed
states are drawn."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from create.ui.colors import _contrast
from _input import next_frame, point_at, press, release

comptime _A = Rectangle((-60, 0), 100, 40)
comptime _B = Rectangle((60, 0), 100, 40)


def _buttons(
    mut ui: UI, mut context: Context, rects: List[Rectangle]
) raises -> List[Bool]:
    """One frame of a button in each of `rects`, in order: what each
    returned."""
    var canvas = Canvas(200, 100)
    var clicked = List[Bool]()
    with ui.screen(context, canvas) as layer:
        for rect in rects:
            clicked.append(layer.button("OK", rect))
    return clicked^


def test_a_press_and_release_over_a_button_clicks_it_once() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, _A.position)
    assert_false(_buttons(ui, context, [_A])[0])
    next_frame(context)
    press(context, _A.position)
    assert_false(_buttons(ui, context, [_A])[0])
    next_frame(context)
    release(context, _A.position)
    assert_true(_buttons(ui, context, [_A])[0])
    next_frame(context)
    assert_false(_buttons(ui, context, [_A])[0])


def test_a_press_and_release_in_one_frame_clicks() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, _A.position)
    _ = _buttons(ui, context, [_A])
    next_frame(context)
    press(context, _A.position)
    release(context, _A.position)
    assert_true(_buttons(ui, context, [_A])[0])


def test_a_release_on_another_button_clicks_neither() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, _A.position)
    _ = _buttons(ui, context, [_A, _B])
    next_frame(context)
    press(context, _A.position)
    _ = _buttons(ui, context, [_A, _B])
    next_frame(context)
    point_at(context, _B.position)
    _ = _buttons(ui, context, [_A, _B])
    next_frame(context)
    release(context, _B.position)
    var clicked = _buttons(ui, context, [_A, _B])
    assert_false(clicked[0])
    assert_false(clicked[1])


def test_only_the_topmost_of_two_overlapping_buttons_clicks() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, _A.position)
    _ = _buttons(ui, context, [_A, _A])
    next_frame(context)
    press(context, _A.position)
    release(context, _A.position)
    var clicked = _buttons(ui, context, [_A, _A])
    assert_false(clicked[0])
    assert_true(clicked[1])


def test_the_ui_wants_the_mouse_over_a_button_or_holding_one() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, Point(0, 45))
    _ = _buttons(ui, context, [_A])
    next_frame(context)
    _ = _buttons(ui, context, [_A])
    assert_false(ui.wants_mouse(context))
    next_frame(context)
    point_at(context, _A.position)
    _ = _buttons(ui, context, [_A])
    assert_true(ui.wants_mouse(context))
    next_frame(context)
    press(context, _A.position)
    _ = _buttons(ui, context, [_A])
    next_frame(context)
    point_at(context, Point(0, 45))
    _ = _buttons(ui, context, [_A])
    assert_true(ui.wants_mouse(context))  # held, though the pointer has left
    next_frame(context)
    release(context, Point(0, 45))
    _ = _buttons(ui, context, [_A])
    next_frame(context)
    _ = _buttons(ui, context, [_A])
    assert_false(ui.wants_mouse(context))


def test_a_ui_that_stops_drawing_stops_wanting_the_input() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, _A.position)
    _ = _buttons(ui, context, [_A])
    next_frame(context)
    _ = _buttons(ui, context, [_A])
    assert_true(ui.wants_mouse(context))
    next_frame(context)
    assert_true(ui.wants_mouse(context))  # before the block: last frame's
    next_frame(context)  # the menu closed: no layer last frame or this
    assert_false(ui.wants_mouse(context))
    assert_false(ui.wants_keyboard(context))


def _button_pixel(
    mut ui: UI, mut context: Context, colors: ColorScheme
) raises -> Color:
    """The colour of a filled button, beside its text."""
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    with ui.screen(context, canvas, colors) as layer:
        _ = layer.button("OK", _A)
    return canvas.color_at(_A.position + Vector(30, 0))


def test_a_hovered_or_pressed_button_stands_out_in_any_scheme() raises -> None:
    for colors in [ColorScheme.light(), ColorScheme.dark()]:
        var ui = UI()
        var context = Context()
        point_at(context, Point(0, 45))
        var rest = _button_pixel(ui, context, colors)
        assert_equal(rest, colors.primary)
        next_frame(context)
        point_at(context, _A.position)
        _ = _button_pixel(ui, context, colors)
        next_frame(context)
        var hovered = _button_pixel(ui, context, colors)
        assert_true(_contrast(rest, hovered) >= 1.35)
        next_frame(context)
        press(context, _A.position)
        _ = _button_pixel(ui, context, colors)
        next_frame(context)
        var pressed = _button_pixel(ui, context, colors)
        assert_true(_contrast(rest, pressed) >= 1.75)
        # tinted towards the text colour
        assert_true(
            _contrast(pressed, colors.on_primary)
            < _contrast(rest, colors.on_primary)
        )


def test_an_outlined_button_draws_only_its_border() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    with ui.screen(context, canvas) as layer:
        _ = layer.button(
            "OK",
            _A,
            variant=ButtonVariant.OUTLINED,
            style=Style(stroke_thickness=4, corner_radius=0),
        )
    assert_equal(canvas.color_at(_A.position + Vector(30, 0)), Color.WHITE)
    assert_equal(
        canvas.color_at(_A.position + Vector(0.0, 18.5)),
        ColorScheme.light().outline,
    )


def test_a_partial_style_keeps_the_variants_colours() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    with ui.screen(context, canvas) as layer:
        _ = layer.button("OK", _A, style=Style(corner_radius=0))
    var primary = ColorScheme.light().primary
    # square corners, filled with the variant's primary to the very corner
    assert_equal(canvas.color_at(_A.position + Vector(49.5, 19.5)), primary)


def test_a_thickness_alone_outlines_a_filled_button() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    with ui.screen(context, canvas) as layer:
        _ = layer.button(
            "OK", _A, style=Style(stroke_thickness=4, corner_radius=0)
        )
    assert_equal(
        canvas.color_at(_A.position + Vector(0.0, 18.5)),
        ColorScheme.light().outline,
    )


def test_a_button_takes_a_gradient_fill() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    var fade = Gradient.linear(Color.RED, Color.BLUE, direction=Vector.RIGHT)
    with ui.screen(context, canvas) as layer:
        _ = layer.button(
            "", _A, style=Style(fill_gradient=fade, corner_radius=0)
        )
    var left = canvas.color_at(_A.position + Vector(-35, 0))
    var right = canvas.color_at(_A.position + Vector(45, 0))
    assert_true(left.r > left.b)
    assert_true(right.b > right.r)


def test_a_label_lets_the_pointer_through() raises -> None:
    var ui = UI()
    var context = Context()
    point_at(context, _A.position)
    var canvas = Canvas(200, 100)
    for frame in range(2):
        if frame == 1:
            next_frame(context)
            press(context, _A.position)
            release(context, _A.position)
        with ui.screen(context, canvas) as layer:
            var clicked = layer.button("OK", _A)
            layer.label("over it", _A)
            if frame == 1:
                assert_true(clicked)


def _ink_near_the_left(alignment: Optional[Align], style: Style) raises -> Bool:
    """Whether a label across the canvas, drawn by `alignment` and `style`,
    puts ink within its leftmost 20 units."""
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    with ui.screen(context, canvas) as layer:
        layer.label(
            "MM",
            Rectangle((0, 0), 180, 40),
            alignment=alignment,
            style=style.over(Style(text_color=Color.BLACK)),
        )
    for x in range(-90, -70):
        for y in range(-20, 20):
            if canvas.color_at((Float64(x) + 0.5, Float64(y) + 0.5)).r < 128:
                return True
    return False


def test_a_label_takes_its_alignment_from_the_call_or_its_style() raises -> (
    None
):
    assert_false(_ink_near_the_left(None, Style()))  # centred
    assert_true(_ink_near_the_left(Align.LEFT, Style()))
    assert_true(_ink_near_the_left(None, Style(text_alignment=Align.LEFT)))
    assert_false(  # the call's wins
        _ink_near_the_left(Align.CENTER, Style(text_alignment=Align.LEFT))
    )


def _corner_is_filled(corner_radius: Float64) raises -> Bool:
    """Whether a button at `_A`, in a `UI` of `corner_radius`, paints its
    top-left corner pixel."""
    var ui = UI()
    ui.corner_radius(corner_radius)
    var context = Context()
    var canvas = Canvas(300, 100, antialiasing=Antialiasing.OFF)
    canvas.background(Color.WHITE)
    with ui.screen(context, canvas) as layer:
        _ = layer.button("", _A)
    return canvas.color_at((-109.5, 19.5)) != Color.WHITE


def test_a_buttons_corners_follow_the_uis_corner_radius() raises -> None:
    assert_false(_corner_is_filled(16))  # a pill
    assert_false(_corner_is_filled(32))  # no rounder than a pill
    assert_true(_corner_is_filled(0))  # square


def test_an_image_fills_its_rectangle() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(200, 100, antialiasing=Antialiasing.OFF)
    var pixels = List[UInt8]()
    for _ in range(4):
        pixels += [255, 0, 0, 255]
    var red = Image.from_rgba(2, 2, pixels)
    with ui.screen(context, canvas) as layer:
        layer.image(red, _A)
    assert_equal(canvas.color_at(_A.position + Vector(45, 15)), Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
