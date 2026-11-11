from std.testing import TestSuite, assert_equal, assert_true, assert_false

from create.color.color import Color
from create.color.gradient import Gradient
from create.render.style import Style
from create.render._command import (
    CirclePayload,
    ClearPayload,
    CurvesPayload,
    ImagePayload,
    LetterboxPayload,
    LinePayload,
    RectPayload,
    RenderCommand,
    TextPayload,
    TrianglePayload,
    clear_command,
    rect_command,
    circle_command,
    line_command,
    triangle_command,
    image_command,
    text_command,
    letterbox_command,
    bezier_command,
    bezier_chain_command,
)
from create.geometry.bezier import Bezier
from create.math.point2d import Point2D
from create.math.matrix import identity, translate, rotate


def _styled() -> Style:
    var s = Style()
    s.fill_color = Color(10, 20, 30)
    s.stroke_color = Color(40, 50, 60)
    s.stroke_thickness = 3
    s.font_size = 21
    return s^


def test_rect_packs_centre_and_extent() raises -> None:
    var c = rect_command(identity[3](), Style(), 1.0, 2.0, 3.0, 4.0)
    assert_true(c.payload.isa[RectPayload]())
    ref rect = c.payload[RectPayload]
    assert_equal(rect.center, Point2D(1.0, 2.0))
    assert_equal(rect.w, 3.0)
    assert_equal(rect.h, 4.0)
    assert_equal(rect.corner_radius, 0.0)


def test_circle_packs_centre_and_radius() raises -> None:
    var c = circle_command(identity[3](), Style(), -5.0, 6.0, 7.0)
    assert_true(c.payload.isa[CirclePayload]())
    assert_equal(c.payload[CirclePayload].center, Point2D(-5.0, 6.0))
    assert_equal(c.payload[CirclePayload].r, 7.0)


def test_line_packs_both_endpoints() raises -> None:
    var c = line_command(identity[3](), Style(), 1.0, 2.0, 3.0, 4.0)
    assert_true(c.payload.isa[LinePayload]())
    assert_equal(c.payload[LinePayload].start, Point2D(1.0, 2.0))
    assert_equal(c.payload[LinePayload].end, Point2D(3.0, 4.0))


def test_triangle_packs_all_three_vertices() raises -> None:
    var c = triangle_command(
        identity[3](), Style(), 1.0, 2.0, 3.0, 4.0, 5.0, 6.0
    )
    assert_true(c.payload.isa[TrianglePayload]())
    for i in range(6):
        assert_equal(c.payload[TrianglePayload].corners[i], Float64(i + 1))


def test_bezier_is_a_chain_of_one() raises -> None:
    var curve = Bezier((1.0, 2.0), (3.0, 4.0), (5.0, 6.0), (7.0, 8.0))
    var c = bezier_command(identity[3](), Style(), curve)
    assert_true(c.payload.isa[CurvesPayload]())
    ref controls = c.payload[CurvesPayload].points
    assert_equal(len(controls), 4)
    assert_equal(controls[0], curve.start)
    assert_equal(controls[1], curve.control1)
    assert_equal(controls[2], curve.control2)
    assert_equal(controls[3], curve.end)


def test_bezier_chain_keeps_its_points() raises -> None:
    var points: List[Point2D] = [
        (0.0, 0.0),
        (1.0, 1.0),
        (2.0, 1.0),
        (3.0, 0.0),
        (4.0, -1.0),
        (5.0, -1.0),
        (6.0, 0.0),
    ]
    var c = bezier_chain_command(identity[3](), Style(), points.copy())
    assert_true(c.payload.isa[CurvesPayload]())
    ref controls = c.payload[CurvesPayload].points
    assert_equal(len(controls), 7)
    for i in range(7):
        assert_equal(controls[i], points[i])


def test_image_carries_an_image_id_not_a_pointer() raises -> None:
    var c = image_command(
        identity[3](), Style(), 1.0, 2.0, 30.0, 40.0, 77, 16, 24
    )
    assert_true(c.payload.isa[ImagePayload]())
    ref image = c.payload[ImagePayload]
    assert_equal(image.w, 30.0)
    assert_equal(image.image, 77)
    assert_equal(image.image_w, 16)
    assert_equal(image.image_h, 24)
    assert_false(image.silhouette)


def test_text_owns_its_string() raises -> None:
    var s = String("hello")
    var c = text_command(identity[3](), Style(), 8.0, 9.0, s^)
    assert_true(c.payload.isa[TextPayload]())
    assert_equal(c.payload[TextPayload].text, "hello")
    assert_equal(c.payload[TextPayload].position, Point2D(8.0, 9.0))


def test_clear_carries_its_colour_in_the_fill() raises -> None:
    var c = clear_command(Color(1, 2, 3, 4))
    assert_true(c.payload.isa[ClearPayload]())
    assert_equal(c.paint.fill_color.r, 1)
    assert_equal(c.paint.fill_color.a, 4)
    assert_true(c.paint.fill_enabled)


def test_letterbox_carries_the_device_content_rect() raises -> None:
    var c = letterbox_command(Color(9, 9, 9), 10.0, 20.0, 110.0, 220.0)
    assert_true(c.payload.isa[LetterboxPayload]())
    assert_equal(c.payload[LetterboxPayload].x0, 10.0)
    assert_equal(c.payload[LetterboxPayload].y1, 220.0)
    assert_equal(c.paint.fill_color.g, 9)


def test_the_transform_is_kept_whole_not_applied() raises -> None:
    # Geometry must stay local: a pre-mapped device rect could not represent a
    # rotated rectangle, which is the whole reason the matrix travels along.
    var m = rotate(0.5) @ translate(100.0, 200.0)
    var c = rect_command(m, Style(), 0.0, 0.0, 10.0, 10.0)
    assert_equal(c.payload[RectPayload].center, Point2D(0.0, 0.0))
    for r in range(3):
        for col in range(3):
            assert_equal(c.transform[r, col], m[r, col])


def test_the_style_is_resolved_at_record_time() raises -> None:
    var s = _styled()
    var c = rect_command(identity[3](), s, 0.0, 0.0, 1.0, 1.0)
    # Mutating the style afterwards must not reach the recorded command.
    s.fill_color = Color(200, 200, 200)
    s.stroke_thickness = 99
    s.font_size = 99
    assert_equal(c.paint.fill_color.r, 10)
    assert_equal(c.paint.stroke_thickness, 3)
    var t = text_command(identity[3](), _styled(), 0.0, 0.0, String("hi"))
    assert_equal(t.payload[TextPayload].style[].font_size, 21)


def test_only_text_carries_how_text_is_set() raises -> None:
    # A shape's command keeps what it paints with; the font, its size and
    # the text colour ride on a text command's payload alone.
    var s = Style(text_color=Color.RED, font_size=30, font_italic=True)
    var t = text_command(identity[3](), s, 0.0, 0.0, String("hi"))
    ref text = t.payload[TextPayload].style[]
    assert_equal(text.text_color, Color.RED)
    assert_equal(text.font_size, 30.0)
    assert_true(text.font_italic)


def test_commands_collect_into_a_buffer() raises -> None:
    # The recording shape Canvas will use: one heterogeneous list, in order.
    var cmds = List[RenderCommand]()
    cmds.append(clear_command(Color.BLACK))
    cmds.append(rect_command(identity[3](), Style(), 0.0, 0.0, 4.0, 4.0))
    cmds.append(text_command(identity[3](), Style(), 0.0, 0.0, String("hi")))
    assert_equal(len(cmds), 3)
    assert_true(cmds[0].payload.isa[ClearPayload]())
    assert_true(cmds[1].payload.isa[RectPayload]())
    assert_true(cmds[2].payload.isa[TextPayload]())
    assert_equal(cmds[2].payload[TextPayload].text, "hi")


def test_opacity_folds_into_the_shadow_color() raises -> None:
    var s = Style(opacity=0.5)
    s.shadow_color = Color(0, 0, 0, 200)
    var c = rect_command(identity[3](), s, 0.0, 0.0, 1.0, 1.0)
    assert_equal(c.paint.shadow_color.a, 100)


def test_opacity_folds_into_the_fill_gradient() raises -> None:
    var s = Style(
        fill_gradient=Gradient.linear(Color.RED, Color.BLUE.with_alpha(200)),
        opacity=0.5,
    )
    var c = rect_command(identity[3](), s, 0.0, 0.0, 1.0, 1.0)
    ref stops = c.paint.fill_gradient.value()._stops[]
    assert_equal(stops[0][1].a, 127)
    assert_equal(stops[1][1].a, 100)
    # The style it was recorded from still holds the full-alpha stops.
    assert_equal(s.fill_gradient.value()._stops[][0][1].a, 255)


def test_tint_folds_into_every_colour() raises -> None:
    var s = Style(
        fill=Color(200, 100, 50),
        stroke=Color.WHITE,
        text_color=Color.WHITE,
        tint=Color(255, 128, 0, 128),
        opacity=0.5,
    )
    var c = rect_command(identity[3](), s, 0.0, 0.0, 1.0, 1.0)
    assert_equal(c.paint.fill_color, Color(200, 50, 0, 64))
    assert_equal(c.paint.stroke_color, Color(255, 128, 0, 64))
    var t = text_command(identity[3](), s, 0.0, 0.0, String("hi"))
    assert_equal(
        t.payload[TextPayload].style[].text_color, Color(255, 128, 0, 64)
    )
    # An image takes none of the style's colours: its tint carries both.
    var image = image_command(identity[3](), s, 0.0, 0.0, 1.0, 1.0, 1, 1, 1)
    assert_equal(image.payload[ImagePayload].tint, Color(255, 128, 0, 64))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
