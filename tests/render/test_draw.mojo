"""`canvas.draw(shape)`: the canvas draws every shape and curve itself, and
drawing one paints exactly what the named method for its kind paints. A
program's own `Drawable` made of shapes draws as its parts.

Offscreen 120 x 100 canvases, antialiasing off, compared pixel for pixel.
"""
from std.testing import TestSuite, assert_equal, assert_true

from create import *


def _canvas() raises -> Canvas:
    var canvas = Canvas(120, 100, antialiasing=Antialiasing.OFF)
    canvas.fill(Color(0x40, 0x80, 0xFF))
    canvas.stroke(Color.BLACK, thickness=3)
    return canvas^


def _assert_same(mut a: Canvas, mut b: Canvas, what: String) raises:
    var x = a.snapshot()
    var y = b.snapshot()
    var inked = 0
    for j in range(x.height()):
        for i in range(x.width()):
            var p = x.pixel(i, j)
            if p != y.pixel(i, j):
                assert_equal(p, y.pixel(i, j), what)
            if p != Color.TRANSPARENT:
                inked += 1
    assert_true(inked > 0, what + " drew nothing")


def test_draw_matches_each_named_method() raises -> None:
    var drawn = _canvas()
    var named = _canvas()
    drawn.draw(Rectangle((-30.0, 20.0), 40.0, 30.0, corner_radius=6.0))
    named.rectangle((-30.0, 20.0), 40.0, 30.0, corner_radius=6.0)
    drawn.draw(Circle((30.0, 20.0), 18.0))
    named.circle((30.0, 20.0), 18.0)
    drawn.draw(Triangle((-50.0, -40.0), (-10.0, -40.0), (-30.0, -5.0)))
    named.triangle((-50.0, -40.0), (-10.0, -40.0), (-30.0, -5.0))
    drawn.draw(Sector((20.0, -30.0), 25.0, 0.2, 2.0, corner_radius=4.0))
    named.sector((20.0, -30.0), 25.0, 0.2, 2.0, corner_radius=4.0)
    _assert_same(drawn, named, "regions")


def test_draw_matches_polygons() raises -> None:
    var drawn = _canvas()
    var named = _canvas()
    drawn.draw(
        Polygon(
            Point(-40.0, -30.0),
            Point(40.0, -30.0),
            Point(0.0, 10.0),
            Point(30.0, 40.0),
            Point(-30.0, 40.0),
            corner_radius=3.0,
        )
    )
    named.polygon(
        (-40.0, -30.0),
        (40.0, -30.0),
        (0.0, 10.0),
        (30.0, 40.0),
        (-30.0, 40.0),
        corner_radius=3.0,
    )
    _assert_same(drawn, named, "polygon")


def test_polygon_takes_a_list() raises -> None:
    var listed = _canvas()
    var named = _canvas()
    var vertices = List[Point]()
    for i in range(5):
        vertices.append(Point(Vector.from_angle(TAU * Float64(i) / 5.0, 40.0)))
    listed.polygon(vertices.copy(), corner_radius=3.0)
    named.draw(Polygon(vertices^, corner_radius=3.0))
    _assert_same(listed, named, "polygon list")


def test_draw_matches_lines_and_curves() raises -> None:
    var drawn = _canvas()
    var named = _canvas()
    drawn.draw(Line((-55.0, -45.0), (55.0, -35.0)))
    named.line((-55.0, -45.0), (55.0, -35.0))
    drawn.draw(Bezier((-50.0, 0.0), (-20.0, 40.0), (20.0, -40.0), (50.0, 0.0)))
    named.bezier((-50.0, 0.0), (-20.0, 40.0), (20.0, -40.0), (50.0, 0.0))
    drawn.draw(Arc((0.0, 10.0), 30.0, 0.0, PI))
    named.arc((0.0, 10.0), 30.0, 0.0, PI)
    var points: List[Point] = [
        Point(-50.0, 40.0),
        Point(-10.0, 30.0),
        Point(20.0, 45.0),
        Point(50.0, 35.0),
    ]
    drawn.draw(Spline(points.copy()))
    named.spline(points^)
    _assert_same(drawn, named, "curves")


@fieldwise_init
struct _Badge(Drawable):
    """A program's own type: a rounded plate with a disc on it."""

    var plate: Rectangle
    var disc: Circle

    def draw_to(self, mut canvas: Canvas):
        canvas.draw(self.plate)
        canvas.draw(self.disc)


def test_a_compound_drawable_draws_its_parts() raises -> None:
    var badge = _Badge(
        Rectangle((0.0, 0.0), 80.0, 50.0, corner_radius=10.0),
        Circle((20.0, 0.0), 12.0),
    )
    var drawn = _canvas()
    drawn.draw(badge)
    var parts = _canvas()
    parts.draw(badge.plate)
    parts.draw(badge.disc)
    _assert_same(drawn, parts, "badge")


def _draw_all[G: Geometry](mut canvas: Canvas, shapes: List[G]):
    for shape in shapes:
        canvas.draw(shape)


def test_a_generic_helper_draws_any_geometry() raises -> None:
    var circles: List[Circle] = [
        Circle((-30.0, 0.0), 10.0),
        Circle((0.0, 0.0), 10.0),
        Circle((30.0, 0.0), 10.0),
    ]
    var drawn = _canvas()
    _draw_all(drawn, circles)
    var named = _canvas()
    for c in circles:
        named.circle(c.position, c.radius)
    _assert_same(drawn, named, "helper")


def test_draw_uses_the_current_style() raises -> None:
    var canvas = Canvas(100, 100, antialiasing=Antialiasing.OFF)
    canvas.stroke_enabled(False)
    with canvas.style(fill=Color.RED):
        canvas.draw(Rectangle((0.0, 0.0), 40.0, 40.0))
    canvas.fill(Color.GREEN)
    canvas.draw(Circle((35.0, 35.0), 8.0))
    assert_equal(canvas.color_at((0.0, 0.0)), Color.RED)
    assert_equal(canvas.color_at((35.0, 35.0)), Color.GREEN)


def test_draw_in_a_style_applies_it_for_that_call_alone() raises -> None:
    var canvas = Canvas(100, 100, antialiasing=Antialiasing.OFF)
    canvas.stroke_enabled(False)
    canvas.fill(Color.GREEN)
    canvas.draw(Rectangle((-25.0, 0.0), 40.0, 40.0), Style(fill=Color.RED))
    canvas.draw(Rectangle((25.0, 0.0), 40.0, 40.0))
    assert_equal(canvas.color_at((-25.0, 0.0)), Color.RED)
    assert_equal(canvas.color_at((25.0, 0.0)), Color.GREEN)


def test_draw_in_a_style_keeps_the_parts_it_leaves_unset() raises -> None:
    var canvas = Canvas(100, 100, antialiasing=Antialiasing.OFF)
    canvas.fill(Color.GREEN)
    canvas.stroke_enabled(False)
    # names only the stroke: the fill stays green
    canvas.draw(
        Rectangle((0.0, 0.0), 60.0, 60.0),
        Style(stroke=Color.BLUE, stroke_thickness=6),
    )
    assert_equal(canvas.color_at((0.0, 0.0)), Color.GREEN)
    assert_equal(canvas.color_at((29.0, 0.0)), Color.BLUE)


@fieldwise_init
struct _Target(Drawable):
    """A program's own type whose parts take styles of their own: a ring in
    the style around it, and a blue bull's-eye."""

    var ring: Circle
    var centre: Circle

    def draw_to(self, mut canvas: Canvas):
        canvas.draw(self.ring)
        canvas.draw(self.centre, Style(fill=Color.BLUE))


def test_styles_nest_through_a_drawable() raises -> None:
    var canvas = Canvas(100, 100, antialiasing=Antialiasing.OFF)
    canvas.stroke_enabled(False)
    canvas.fill(Color.GREEN)
    var target = _Target(Circle((0.0, 0.0), 40.0), Circle((0.0, 0.0), 10.0))
    canvas.draw(target, Style(fill=Color.RED))
    canvas.draw(Circle((40.0, 40.0), 5.0))
    assert_equal(canvas.color_at((0.0, 0.0)), Color.BLUE)
    assert_equal(canvas.color_at((25.0, 0.0)), Color.RED)
    assert_equal(canvas.color_at((40.0, 40.0)), Color.GREEN)


def _text_canvas() raises -> Canvas:
    var canvas = Canvas(120, 100, antialiasing=Antialiasing.OFF)
    canvas.text_color(Color.BLACK)
    canvas.font_size(14)
    return canvas^


def test_text_draws_what_canvas_text_draws() raises -> None:
    var drawn = _text_canvas()
    var named = _text_canvas()
    drawn.draw(Text("Hello", (0.0, 20.0)))
    named.text("Hello", (0.0, 20.0))
    drawn.text_alignment(Align.TOP_LEFT)
    named.text_alignment(Align.TOP_LEFT)
    drawn.draw(Text("one two three four", (-55.0, 0.0), width=60))
    named.text("one two three four", (-55.0, 0.0), 60.0)
    _assert_same(drawn, named, "text")


def test_text_takes_a_style_of_its_own() raises -> None:
    var drawn = _text_canvas()
    var named = _text_canvas()
    drawn.draw(Text("Red", (0.0, 0.0)), Style(text_color=Color.RED))
    with named.style(text_color=Color.RED):
        named.text("Red", (0.0, 0.0))
    _assert_same(drawn, named, "styled text")


def test_text_moves_as_a_value() raises -> None:
    var text = Text("Hi", (1.0, 2.0))
    assert_equal(text.translate(Vector(10, 0)).position, Point(11.0, 2.0))
    assert_equal(text.move_to((5.0, 5.0)).position, Point(5.0, 5.0))
    assert_equal(text.position, Point(1.0, 2.0))
    assert_true(text == Text("Hi", (1.0, 2.0)))
    assert_true(text != Text("Hi", (1.0, 2.0), width=40))


def test_text_prints_as_source() raises -> None:
    assert_equal(
        String(Text("Hi", (1.0, 2.0))),
        'Text(value="Hi", position=Point(1.0, 2.0))',
    )
    assert_equal(
        String(Text('say "hi"\n', (0.0, 0.0), width=50)),
        'Text(value="say \\"hi\\"\\n", position=Point(0.0, 0.0), width=50.0)',
    )


def _ink_inside(mut canvas: Canvas, bounds: Rectangle, what: String) raises:
    """Every pixel the text inked lies within `bounds`, give or take a pixel,
    and the ink reaches near each of its four sides."""
    var image = canvas.snapshot()
    var grown = bounds.inset(-1.0)
    var reach_left = False
    var reach_right = False
    var reach_top = False
    var reach_bottom = False
    for j in range(image.height()):
        for i in range(image.width()):
            if image.pixel(i, j).a == 0:
                continue
            var p = Point(Float64(i) - 59.5, 49.5 - Float64(j))
            assert_true(grown.contains(p), what + ": ink outside " + String(p))
            reach_left = reach_left or p.x < bounds.left() + 3
            reach_right = reach_right or p.x > bounds.right() - 3
            # The box runs from the font's ascent to its descent, which
            # leave room above capitals for accents.
            reach_top = reach_top or p.y > bounds.top() - bounds.height * 0.4
            reach_bottom = reach_bottom or (
                p.y < bounds.bottom() + bounds.height * 0.4
            )
    assert_true(reach_left and reach_right, what + ": ink misses a side")
    assert_true(reach_top and reach_bottom, what + ": ink misses top or bottom")


def test_bounds_cover_the_drawn_text_under_each_alignment() raises -> None:
    var alignments = [Align.TOP_LEFT, Align.CENTER, Align.BOTTOM_RIGHT]
    for align in alignments:
        var canvas = Canvas(120, 100, antialiasing=Antialiasing.OFF)
        canvas.background(Color.TRANSPARENT)
        canvas.text_color(Color.BLACK)
        canvas.font_size(16)
        canvas.text_alignment(align)
        var text = Text("Hilly", (5.0, -5.0))
        canvas.draw(text)
        _ink_inside(canvas, canvas.bounds(text), String(align))


def test_bounds_follow_the_alignment() raises -> None:
    var canvas = _text_canvas()
    var text = Text("Hello", (10.0, 20.0))
    canvas.text_alignment(Align.TOP_LEFT)
    var corner = canvas.bounds(text)
    assert_equal(corner.left(), 10.0)
    assert_equal(corner.top(), 20.0)
    assert_equal(corner.width, canvas.text_width("Hello"))
    assert_equal(corner.height, canvas.text_height("Hello"))
    canvas.text_alignment(Align.CENTER)
    assert_equal(canvas.bounds(text).position, Point(10.0, 20.0))


def test_bounds_wrap_and_take_a_style() raises -> None:
    var canvas = _text_canvas()
    var text = Text("one two three four", (0.0, 0.0), width=60)
    var wrapped = canvas.bounds(text)
    assert_equal(wrapped.width, canvas.text_width(text.value, width=60))
    assert_equal(wrapped.height, canvas.text_height(text.value, width=60))
    var bigger = canvas.bounds(text, Style(font_size=28))
    assert_true(bigger.height > wrapped.height)
    assert_equal(canvas.bounds(text), wrapped)  # the style is as it was


comptime _IMAGE = "../fixtures/test_2x2.png"


def test_picture_draws_what_canvas_image_draws() raises -> None:
    var image = Image.load(_IMAGE)
    var drawn = _canvas()
    var named = _canvas()
    drawn.draw(Picture(image, (-30.0, 20.0)))
    named.image(image, (-30.0, 20.0))
    drawn.draw(Picture(image, (10.0, -10.0), 40, 30))
    named.image(image, (10.0, -10.0), 40, 30)
    _assert_same(drawn, named, "picture")


def test_picture_takes_a_style_of_its_own() raises -> None:
    var image = Image.load(_IMAGE)
    var drawn = _canvas()
    var named = _canvas()
    var tinted = Style(tint=Color.RED, opacity=0.5)
    drawn.draw(Picture(image, (0.0, 0.0), 50.0, 50.0), tinted)
    with named.style(tinted):
        named.image(image, (0.0, 0.0), 50.0, 50.0)
    _assert_same(drawn, named, "tinted picture")


def test_picture_is_placed_as_a_value() raises -> None:
    var picture = Picture(Image.load(_IMAGE), (5.0, 5.0), 40, 20)
    assert_equal(picture.bounds(), Rectangle((5.0, 5.0), 40.0, 20.0))
    assert_equal(Picture(picture.image, (0.0, 0.0)).bounds().width, 2.0)
    assert_equal(picture.translate(Vector(10, 0)).position, Point(15.0, 5.0))
    assert_equal(picture.move_to((0.0, 0.0)).position, Point(0.0, 0.0))
    assert_equal(picture.position, Point(5.0, 5.0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
