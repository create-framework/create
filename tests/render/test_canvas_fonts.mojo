"""The font as part of the style: several faces in one frame, each `text`
call keeping the face it was drawn in.

The two packaged faces stand in for two fonts. Noto Sans Symbols carries
Latin letters too, hinted a little differently, so "H" comes out differently
in it by a few pixels. Each scene is compared against references drawn in
one face alone, so the tests never depend on how.

On an offscreen 100 x 40 canvas: the left half is x < 50, the right x >= 50.
"""

from std.testing import TestSuite, assert_equal, assert_true

from create import *
from create.text.font import _default_font, _fallback_font


def _canvas() raises -> Canvas:
    var canvas = Canvas(100, 40, antialiasing=Antialiasing.OFF)
    canvas.text_color(Color.BLACK)
    canvas.font_size(24)
    return canvas^


def _symbols() raises -> Font:
    return _fallback_font()


def _alone(font: Optional[Font], x: Float64) raises -> Image:
    """ "H" at `x` in one face, nothing else."""
    var canvas = _canvas()
    if font:
        canvas.font(font.value())
    canvas.text("H", (x, 0))
    return canvas.snapshot()


def _differing_in_half(a: Image, b: Image, right: Bool) -> Int:
    """Pixels that differ between `a` and `b` in one half."""
    var n = 0
    var x0 = 50 if right else 0
    for y in range(a.height()):
        for x in range(x0, x0 + 50):
            if a.pixel(x, y) != b.pixel(x, y):
                n += 1
    return n


def test_the_two_faces_draw_h_differently() raises -> None:
    # The premise of every test below.
    var sans = _alone(None, -25)
    var symbols = _alone(_symbols(), -25)
    assert_true(_differing_in_half(sans, symbols, right=False) > 0)


def test_two_fonts_share_a_frame() raises -> None:
    var canvas = _canvas()
    canvas.font(_symbols())
    canvas.text("H", (-25, 0))
    canvas.font(_default_font())
    canvas.text("H", (25, 0))
    var both = canvas.snapshot()
    assert_equal(
        _differing_in_half(both, _alone(_symbols(), -25), right=False), 0
    )
    assert_equal(_differing_in_half(both, _alone(None, 25), right=True), 0)


def test_text_keeps_the_font_it_was_drawn_in() raises -> None:
    # A later `canvas.font` must not reach back: the face is recorded with the
    # call, not looked up when the frame is drawn.
    var canvas = _canvas()
    canvas.text("H", (-25, 0))
    canvas.font(_symbols())
    canvas.text("H", (25, 0))
    var shot = canvas.snapshot()
    assert_equal(_differing_in_half(shot, _alone(None, -25), right=False), 0)
    assert_equal(
        _differing_in_half(shot, _alone(_symbols(), 25), right=True), 0
    )


def test_a_style_block_restores_the_font() raises -> None:
    var canvas = _canvas()
    with canvas.style(font=_symbols()):
        canvas.text("H", (-25, 0))
    canvas.text("H", (25, 0))
    var shot = canvas.snapshot()
    assert_equal(
        _differing_in_half(shot, _alone(_symbols(), -25), right=False), 0
    )
    assert_equal(_differing_in_half(shot, _alone(None, 25), right=True), 0)


def _alone_italic(x: Float64) raises -> Image:
    """ "H" at `x` in the default face's italic, nothing else."""
    var canvas = _canvas()
    canvas.font_italic(True)
    canvas.text("H", (x, 0))
    return canvas.snapshot()


def test_a_style_block_restores_upright_text() raises -> None:
    var upright = _alone(None, -25)
    var italic = _alone_italic(-25)
    assert_true(_differing_in_half(upright, italic, right=False) > 0)
    var canvas = _canvas()
    with canvas.style(font_italic=True):
        canvas.text("H", (-25, 0))
    canvas.text("H", (25, 0))
    var shot = canvas.snapshot()
    assert_equal(_differing_in_half(shot, italic, right=False), 0)
    assert_equal(_differing_in_half(shot, _alone(None, 25), right=True), 0)


def test_text_width_follows_the_font() raises -> None:
    var canvas = _canvas()
    # Each of these is a pixel wider in the symbols face at this size; "H" is
    # the same width in both.
    var sans = canvas.text_width("BDJLO")
    canvas.font(_symbols())
    assert_true(canvas.text_width("BDJLO") != sans)


def _label_width(canvas: Canvas, label: String) raises -> Float64:
    return canvas.text_width(label)


def test_text_width_reads_through_an_immutable_canvas() raises -> None:
    var canvas = _canvas()
    var before = canvas.text_width("Hi")
    assert_equal(_label_width(canvas, "Hi"), before)
    assert_true(_label_width(canvas, "H") < before)


def test_text_height_counts_the_lines() raises -> None:
    var canvas = _canvas()
    var one = canvas.text_height("H")
    var two = canvas.text_height("H\nH")
    assert_true(two > one)
    assert_equal(canvas.text_height("H\nH\nH") - two, two - one)
    assert_equal(canvas.text_width("H\nHi"), canvas.text_width("Hi"))


def test_wrapped_text_draws_as_its_lines() raises -> None:
    var canvas = _canvas()
    canvas.font_size(12)
    canvas.text_alignment(Align.TOP_LEFT)
    var width = canvas.text_width("there")
    canvas.text("Hi there", (-50, 20), width)
    var wrapped = canvas.snapshot()
    var reference = _canvas()
    reference.font_size(12)
    reference.text_alignment(Align.TOP_LEFT)
    reference.text("Hi\nthere", (-50, 20))
    var broken = reference.snapshot()
    assert_equal(_differing_in_half(wrapped, broken, right=False), 0)
    assert_equal(_differing_in_half(wrapped, broken, right=True), 0)
    assert_equal(
        canvas.text_height("Hi there", width=width),
        canvas.text_height("Hi\nthere"),
    )
    assert_equal(
        canvas.text_width("Hi there", width=width),
        canvas.text_width("there"),
    )


def test_a_style_prints_its_font() raises -> None:
    var font = _symbols()
    var style = Style(font=font)
    assert_true(
        String(style).find('font=Font.load("' + font.path() + '")') >= 0
    )
    assert_true(String(Style()).find("font=None") >= 0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
