# The GIF writer behind canvas.start_recording, checked against the decoder in
# _gif_decode.mojo: LZW round trips at every code size (a full table cleared
# included), exact and quantised palettes, and a whole file's header,
# frames, delays and trailer.

from std.testing import TestSuite, assert_equal, assert_true

from create import *
from _gif_decode import decode_gif, lzw_decode
from create.render._gif import (
    DISPOSE_BACKGROUND,
    DISPOSE_KEEP,
    GifWriter,
    encode_frame,
    lzw_encode,
    quantise,
)


def _random_bytes(count: Int, symbols: Int, seed: UInt64) -> List[UInt8]:
    var random = Random(seed)
    var out = List[UInt8]()
    for _ in range(count):
        out.append(UInt8(random.int(0, symbols)))
    return out^


def test_lzw_round_trips_at_every_code_size() raises -> None:
    for min_code_size in range(2, 9):
        var symbols = 1 << min_code_size
        # Long enough to fill the 4096-code table and clear it, and short
        # runs that hit the code width's first steps.
        for count in [1, 2, 7, 300, 40000]:
            var data = _random_bytes(count, symbols, UInt64(count))
            var back = lzw_decode(
                lzw_encode(data, min_code_size), min_code_size
            )
            assert_equal(len(back), count)
            for i in range(count):
                assert_equal(back[i], data[i])


def test_lzw_round_trips_repetitive_data() raises -> None:
    # Long runs grow long table entries, the opposite case to noise.
    var data = List[UInt8]()
    for i in range(60000):
        data.append(UInt8((i // 97) % 3))
    var back = lzw_decode(lzw_encode(data, 2), 2)
    assert_equal(len(back), len(data))
    for i in range(len(data)):
        assert_equal(back[i], data[i])


def _rgba[
    colour: def(Int, Int) thin -> Color
](width: Int, height: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for y in range(height):
        for x in range(width):
            var c = colour(x, y)
            out.append(c.r)
            out.append(c.g)
            out.append(c.b)
            out.append(255)
    return out^


def _stripes(x: Int, y: Int) -> Color:
    var colors: List[Color] = [
        Color.RED,
        Color(12, 34, 56),
        Color.WHITE,
        Color(90, 170, 255),
        Color.BLACK,
    ]
    return colors[(x + 2 * y) % len(colors)]


def _ramp(x: Int, y: Int) -> Color:
    return Color(UInt8(x * 4), UInt8(y * 4), UInt8((x + y) * 2))


def test_few_colours_quantise_exactly() raises -> None:
    var pixels = _rgba[_stripes](20, 11)
    var q = quantise(pixels, 20, 11, dither=False)
    assert_equal(q.bits, 3)  # five colours, padded to eight
    for i in range(20 * 11):
        var index = Int(q.indices[i])
        for c in range(3):
            assert_equal(q.palette[index * 3 + c], pixels[i * 4 + c])


def _worst_error(
    pixels: List[UInt8],
    q_palette: List[UInt8],
    q_indices: List[UInt8],
    count: Int,
) -> Int:
    var worst = 0
    for i in range(count):
        var index = Int(q_indices[i])
        for c in range(3):
            var d = abs(Int(pixels[i * 4 + c]) - Int(q_palette[index * 3 + c]))
            worst = max(worst, d)
    return worst


def test_many_colours_quantise_closely() raises -> None:
    # 4096 distinct colours into 256: median cut keeps every pixel near.
    var pixels = _rgba[_ramp](64, 64)
    var q = quantise(pixels, 64, 64, dither=False)
    assert_equal(q.bits, 8)
    assert_true(_worst_error(pixels, q.palette, q.indices, 64 * 64) <= 24)


def test_dithering_keeps_the_average_colour() raises -> None:
    # Dithering trades a pixel's error for its neighbourhood's: a flat colour
    # between palette entries averages out to itself.
    var pixels = _rgba[_ramp](64, 64)
    var q = quantise(pixels, 64, 64, dither=True)
    var wanted = 0
    var got = 0
    for i in range(64 * 64):
        wanted += Int(pixels[i * 4])
        got += Int(q.palette[Int(q.indices[i]) * 3])
    assert_true(abs(wanted - got) <= 64 * 64)  # within a level on average


def test_a_written_gif_decodes_frame_by_frame() raises -> None:
    var path = String("/tmp/create_test_gif_frames.gif")
    var writer = GifWriter(path, 20, 11)
    writer.write_frame(encode_frame(_rgba[_stripes](20, 11), 20, 11, False), 3)
    writer.write_frame(encode_frame(_rgba[_ramp](20, 11), 20, 11, False), 7)
    writer.finish()

    var gif = decode_gif(path)
    assert_equal(gif.width, 20)
    assert_equal(gif.height, 11)
    assert_true(gif.loops)
    assert_equal(len(gif.frames), 2)
    assert_equal(gif.frames[0].delay, 3)
    assert_equal(gif.frames[1].delay, 7)
    var stripes = _rgba[_stripes](20, 11)
    for i in range(20 * 11):
        for c in range(3):
            assert_equal(gif.frames[0].pixels[i * 4 + c], stripes[i * 4 + c])


def _with_holes(var pixels: List[UInt8], width: Int) -> List[UInt8]:
    """`pixels` with every third pixel along a diagonal at alpha 0, and
    the pixels either side of those at 127 and 128, just under and at
    half."""
    for i in range(len(pixels) // 4):
        var k = (i % width + i // width) % 3
        pixels[i * 4 + 3] = UInt8(0 if k == 0 else (127 if k == 1 else 128))
    return pixels^


def _assert_transparency(
    pixels: List[UInt8],
    q_palette: List[UInt8],
    q_indices: List[UInt8],
    q_transparent: Optional[Int],
) raises:
    """Every pixel under half alpha takes the transparent index, and no
    other pixel does."""
    assert_true(Bool(q_transparent))
    var transparent = q_transparent.value()
    for i in range(len(q_indices)):
        var hidden = Int(pixels[i * 4 + 3]) < 128
        assert_equal(Int(q_indices[i]) == transparent, hidden)


def test_transparent_pixels_quantise_to_their_own_index() raises -> None:
    var pixels = _with_holes(_rgba[_stripes](20, 11), 20)
    var q = quantise(pixels, 20, 11, dither=False, transparent=True)
    _assert_transparency(pixels, q.palette, q.indices, q.transparent)
    for i in range(20 * 11):
        if Int(pixels[i * 4 + 3]) < 128:
            continue
        var index = Int(q.indices[i])
        for c in range(3):
            assert_equal(q.palette[index * 3 + c], pixels[i * 4 + c])
    # Without `transparent`, alpha is ignored as ever.
    var opaque = quantise(pixels, 20, 11, dither=False)
    assert_true(not opaque.transparent)


def test_transparent_pixels_survive_median_cut_and_dithering() raises -> None:
    var pixels = _with_holes(_rgba[_ramp](64, 64), 64)
    for dither in [False, True]:
        var q = quantise(pixels, 64, 64, dither=dither, transparent=True)
        assert_equal(q.bits, 8)
        _assert_transparency(pixels, q.palette, q.indices, q.transparent)
    var q = quantise(pixels, 64, 64, dither=False, transparent=True)
    var worst = 0
    for i in range(64 * 64):
        if Int(pixels[i * 4 + 3]) < 128:
            continue
        var index = Int(q.indices[i])
        for c in range(3):
            var d = abs(Int(pixels[i * 4 + c]) - Int(q.palette[index * 3 + c]))
            worst = max(worst, d)
    assert_true(worst <= 24)


def _solid(color: Color, width: Int, height: Int) -> List[UInt8]:
    var out = List[UInt8]()
    for _ in range(width * height):
        out.append(color.r)
        out.append(color.g)
        out.append(color.b)
        out.append(color.a)
    return out^


def test_a_partial_frame_is_drawn_over_the_one_kept_before_it() raises -> None:
    var path = String("/tmp/create_test_gif_partial.gif")
    var writer = GifWriter(path, 20, 11)
    writer.write_frame(
        encode_frame(_rgba[_stripes](20, 11), 20, 11, False), 3, DISPOSE_KEEP
    )
    # A red 6x4 rectangle at (3, 2), with holes the stripes show through.
    var patch = _with_holes(_solid(Color.RED, 6, 4), 6)
    writer.write_frame(
        encode_frame(patch, 6, 4, False, transparent=True, left=3, top=2), 3
    )
    writer.finish()
    var gif = decode_gif(path)
    assert_equal(len(gif.frames), 2)
    assert_equal(gif.frames[1].left, 3)
    assert_equal(gif.frames[1].top, 2)
    assert_equal(gif.frames[1].width, 6)
    var stripes = _rgba[_stripes](20, 11)
    for y in range(11):
        for x in range(20):
            var o = (y * 20 + x) * 4
            var inside = x >= 3 and x < 9 and y >= 2 and y < 6
            var red = (
                inside and Int(patch[((y - 2) * 6 + x - 3) * 4 + 3]) >= 128
            )
            var want = Color.RED if red else Color(
                stripes[o], stripes[o + 1], stripes[o + 2]
            )
            assert_equal(gif.frames[1].pixels[o], want.r)
            assert_equal(gif.frames[1].pixels[o + 1], want.g)
            assert_equal(gif.frames[1].pixels[o + 2], want.b)
            assert_equal(Int(gif.frames[1].pixels[o + 3]), 255)


def test_a_frame_disposed_to_the_background_is_cleared() raises -> None:
    var path = String("/tmp/create_test_gif_dispose.gif")
    var writer = GifWriter(path, 20, 11)
    var first = _with_holes(_rgba[_stripes](20, 11), 20)
    writer.write_frame(
        encode_frame(first, 20, 11, False, transparent=True),
        3,
        DISPOSE_BACKGROUND,
    )
    writer.write_frame(
        encode_frame(
            _solid(Color.BLUE, 2, 2),
            2,
            2,
            False,
            transparent=True,
            left=1,
            top=1,
        ),
        3,
        DISPOSE_BACKGROUND,
    )
    writer.finish()
    var gif = decode_gif(path)
    for i in range(20 * 11):
        var alpha = Int(gif.frames[0].pixels[i * 4 + 3])
        assert_equal(alpha, 0 if Int(first[i * 4 + 3]) < 128 else 255)
        var x = i % 20
        var y = i // 20
        var blue = x >= 1 and x < 3 and y >= 1 and y < 3
        assert_equal(Int(gif.frames[1].pixels[i * 4 + 3]), 255 if blue else 0)
    assert_equal(gif.frames[0].dispose, DISPOSE_BACKGROUND)


def test_a_frame_must_lie_inside_the_image() raises -> None:
    var writer = GifWriter("/tmp/create_test_gif_outside.gif", 20, 11)
    var raised = False
    try:
        writer.write_frame(
            encode_frame(_solid(Color.RED, 4, 4), 4, 4, False, left=18), 1
        )
    except:
        raised = True
    writer.cancel()
    assert_true(raised)


def test_a_gif_needs_an_area() raises -> None:
    var raised = False
    try:
        _ = GifWriter("/tmp/create_test_gif_empty.gif", 0, 10)
    except:
        raised = True
    assert_true(raised)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
