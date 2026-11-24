"""`BlendMode`: the per-mode formulas in the CPU rasteriser, and the mode
travelling from `canvas.blend_mode` through the recording to the replay.

The GPU half is `test_gl_batching.mojo`'s blend-mode case, which renders
`BlendModes` below through the GL backend and expects the same colours.
"""

from std.testing import TestSuite, assert_equal, assert_true

from create import *
from create.render._raster import blend, fill_all, fill_span
from create.render._surface import MemorySurface

comptime _DST = Color(100, 150, 200)
comptime _SRC = Color(200, 100, 50)


def _one_pixel(mode: BlendMode, src: Color) raises -> Color:
    var mem = MemorySurface(1, 1)
    fill_all(mem.surface(), _DST)
    blend(mem.surface()._with_blend_mode(mode), 0, src)
    return mem.pixel(0, 0)


def test_blend_mode_writes_its_constant_name() raises -> None:
    assert_equal(String(BlendMode.NORMAL), "BlendMode.NORMAL")
    assert_equal(String(BlendMode.SCREEN), "BlendMode.SCREEN")
    assert_equal(String(BlendMode(99)), "BlendMode(99)")


def test_each_mode_composites_an_opaque_source_by_its_formula() raises -> None:
    assert_equal(_one_pixel(BlendMode.NORMAL, _SRC), _SRC)
    assert_equal(_one_pixel(BlendMode.ADD, _SRC), Color(255, 250, 250))
    assert_equal(_one_pixel(BlendMode.SUBTRACT, _SRC), Color(0, 50, 150))
    assert_equal(_one_pixel(BlendMode.MULTIPLY, _SRC), Color(78, 58, 39))
    assert_equal(_one_pixel(BlendMode.SCREEN, _SRC), Color(222, 192, 211))


def test_source_alpha_scales_how_much_of_the_mode_shows() raises -> None:
    var half = _SRC.with_alpha(128)
    # `ADD` adds `s * a`: 100 + 100, 150 + 50, 200 + 25.
    assert_equal(_one_pixel(BlendMode.ADD, half), Color(200, 200, 225))
    # The others lerp from the destination towards the full result.
    var m = _one_pixel(BlendMode.MULTIPLY, half)
    assert_true(m.r > 78 and m.r < 100, "MULTIPLY at half alpha: " + String(m))
    assert_equal(_one_pixel(BlendMode.SCREEN, _SRC.with_alpha(0)), _DST)


def test_alpha_composites_source_over_in_every_mode() raises -> None:
    var mem = MemorySurface(1, 1)
    blend(mem.surface()._with_blend_mode(BlendMode.ADD), 0, _SRC.with_alpha(64))
    assert_equal(mem.pixel(0, 0).a, 64)


def test_a_span_matches_one_pixel_at_a_time_in_every_mode() raises -> None:
    # Seven pixels: one four-wide `SIMD` step, then a scalar tail of three.
    var modes = [
        BlendMode.ADD,
        BlendMode.SUBTRACT,
        BlendMode.MULTIPLY,
        BlendMode.SCREEN,
    ]
    for mode in modes:
        for a in [255, 128, 7]:
            var src = _SRC.with_alpha(UInt8(a))
            var mem = MemorySurface(7, 1)
            fill_all(mem.surface(), _DST)
            fill_span(mem.surface()._with_blend_mode(mode), 0, 7, src)
            var expected = _one_pixel(mode, src)
            for x in range(7):
                assert_equal(
                    mem.pixel(x, 0),
                    expected,
                    String(mode, " alpha ", a, " pixel ", x),
                )


def _modes() -> List[BlendMode]:
    return [
        BlendMode.ADD,
        BlendMode.SUBTRACT,
        BlendMode.MULTIPLY,
        BlendMode.SCREEN,
    ]


def test_every_mode_over_a_transparent_pixel_gives_the_source() raises -> None:
    # Nothing is under the source to blend with, so it shows as itself,
    # rather than blended with the transparent pixel's black.
    for mode in _modes():
        for a in [255, 128, 7]:
            var src = _SRC.with_alpha(UInt8(a))
            var mem = MemorySurface(1, 1)
            blend(mem.surface()._with_blend_mode(mode), 0, src)
            assert_equal(mem.pixel(0, 0), src, String(mode, " alpha ", a))


def test_over_a_translucent_pixel_the_mode_shows_as_much_as_it_covers() raises -> (
    None
):
    # An opaque source over a half-transparent pixel: half of it shows the
    # mode's result over the pixel, and the other half the source itself.
    var mem = MemorySurface(1, 1)
    blend(mem.surface(), 0, _DST.with_alpha(128))
    blend(mem.surface()._with_blend_mode(BlendMode.MULTIPLY), 0, _SRC)
    var full = _one_pixel(BlendMode.MULTIPLY, _SRC)

    # The source weighs 127 parts in 255, the mode's result 128.
    def mix(s: UInt8, m: UInt8) -> UInt8:
        return UInt8((Int(s) * 127 + Int(m) * 128 + 127) // 255)

    assert_equal(
        mem.pixel(0, 0),
        Color(
            mix(_SRC.r, full.r), mix(_SRC.g, full.g), mix(_SRC.b, full.b), 255
        ),
    )


def test_a_span_over_translucent_pixels_matches_one_pixel_at_a_time() raises -> (
    None
):
    # Opaque, transparent and translucent pixels in one four-wide step and
    # a tail: each must take what `blend` gives it alone.
    var under = [
        _DST,
        Color(0, 0, 0, 0),
        _DST.with_alpha(100),
        _DST,
        _DST.with_alpha(200),
        Color(0, 0, 0, 0),
    ]
    for mode in _modes():
        for a in [255, 128]:
            var src = _SRC.with_alpha(UInt8(a))
            var mem = MemorySurface(len(under), 1)
            var alone = MemorySurface(len(under), 1)
            for x in range(len(under)):
                blend(mem.surface(), x * 4, under[x])
                blend(alone.surface(), x * 4, under[x])
                blend(alone.surface()._with_blend_mode(mode), x * 4, src)
            fill_span(mem.surface()._with_blend_mode(mode), 0, len(under), src)
            for x in range(len(under)):
                assert_equal(
                    mem.pixel(x, 0),
                    alone.pixel(x, 0),
                    String(mode, " alpha ", a, " pixel ", x),
                )


@fieldwise_init
struct BlendModes(Program):
    """One square per mode on a `_DST` background, left to right: `ADD`,
    `SUBTRACT`, `MULTIPLY`, `SCREEN`, then `NORMAL` once the guard exits."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> BlendModes:
        return BlendModes(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(_DST)
        canvas.stroke_enabled(False)
        canvas.fill(_SRC)
        var modes = [
            BlendMode.ADD,
            BlendMode.SUBTRACT,
            BlendMode.MULTIPLY,
            BlendMode.SCREEN,
        ]
        for i in range(4):
            with canvas.style(blend_mode=modes[i]):
                canvas.rectangle((Float64(i * 20 - 40), 0.0), 12.0, 12.0)
        canvas.rectangle((40.0, 0.0), 12.0, 12.0)


def test_the_canvas_records_the_mode_and_the_guard_restores_it() raises -> None:
    var m = run_headless[BlendModes](100, 40)
    assert_equal(m.pixel(10, 20), Color(255, 250, 250), "ADD")
    assert_equal(m.pixel(30, 20), Color(0, 50, 150), "SUBTRACT")
    assert_equal(m.pixel(50, 20), Color(78, 58, 39), "MULTIPLY")
    assert_equal(m.pixel(70, 20), Color(222, 192, 211), "SCREEN")
    assert_equal(m.pixel(90, 20), _SRC, "NORMAL after the guard")
    assert_equal(m.pixel(50, 5), _DST, "background under a mode")


@fieldwise_init
struct BackgroundUnderAdd(Program):
    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> BackgroundUnderAdd:
        return BackgroundUnderAdd(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(_DST)
        canvas.blend_mode(BlendMode.ADD)
        canvas.background(_SRC)


def test_background_ignores_the_blend_mode() raises -> None:
    var m = run_headless[BackgroundUnderAdd](10, 10)
    assert_equal(m.pixel(5, 5), _SRC)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
