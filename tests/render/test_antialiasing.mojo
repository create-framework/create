"""CPU antialiasing: a shape's edge pixels take the share of their samples
the shape covers, its fill and stroke meet without a seam, and an edge on
the pixel grid comes out as it would without antialiasing.

A 100 x 100 design maps 1:1, its origin at device pixel (50, 50).
"""

from std.math import sqrt
from std.testing import TestSuite, assert_equal, assert_true

from create import *
from create.core.headless import run_headless


@fieldwise_init
struct OffGrid[gradient: Bool](Program):
    """A red square whose left edge lies at device x 40.25: a quarter into
    column 40."""

    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> OffGrid[Self.gradient]:
        return OffGrid[Self.gradient](0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.BLACK)
        canvas.stroke_enabled(False)
        comptime if Self.gradient:
            canvas.fill(Gradient.linear(Color.RED, Color.RED))
        else:
            canvas.fill(Color.RED)
        canvas.rectangle((0.25, 0.0), 20.0, 20.0)


def test_an_edge_off_the_pixel_grid_is_partly_covered() raises -> None:
    # MEDIUM samples 4 x 4 per pixel: three of column 40's four sample
    # columns lie right of 40.25.
    var m = run_headless[OffGrid[False]](100, 100)
    assert_equal(m.pixel(40, 50), Color(191, 0, 0, 255))
    assert_equal(m.pixel(41, 50), Color.RED)
    assert_equal(m.pixel(39, 50), Color.BLACK)
    # Without antialiasing the pixel centre (40.5) decides: all or nothing.
    var hard = run_headless[OffGrid[False]](
        100, 100, antialiasing=Antialiasing.OFF
    )
    assert_equal(hard.pixel(40, 50), Color.RED)


def test_a_gradient_edge_is_partly_covered() raises -> None:
    var m = run_headless[OffGrid[True]](100, 100)
    assert_equal(m.pixel(40, 50), Color(191, 0, 0, 255))
    assert_equal(m.pixel(45, 50), Color.RED)


@fieldwise_init
struct InsetOffGrid[triangle: Bool, shadowed: Bool = True](Program):
    """A black shape on black with a red inset shadow banding its inside,
    its left edge at device x 40.25, as `OffGrid`'s: a rectangle, whose
    inset shadow is analytic, or a right triangle, whose is a mask. Not
    `shadowed`, the shape is red instead, to show what it covers."""

    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> InsetOffGrid[Self.triangle, Self.shadowed]:
        return InsetOffGrid[Self.triangle, Self.shadowed](0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.BLACK)
        canvas.stroke_enabled(False)
        comptime if Self.shadowed:
            canvas.fill(Color.BLACK)
            canvas.shadow(Color.RED, offset=Vector(0, 0), blur=0, spread=4)
            canvas.shadow(inset=True)
        else:
            canvas.fill(Color.RED)
        comptime if Self.triangle:
            canvas.triangle((-9.75, -30.0), (20.0, -30.0), (-9.75, 30.0))
        else:
            canvas.rectangle((0.25, 0.0), 20.0, 20.0)


def test_an_inset_shadow_edge_is_partly_covered() raises -> None:
    # The shadow is clipped to the shape's inside, so its edge pixel takes
    # the shape's share of samples, as the shape's own edge does.
    var rect = run_headless[InsetOffGrid[False]](100, 100)
    assert_equal(rect.pixel(40, 50), Color(191, 0, 0, 255))
    assert_equal(rect.pixel(41, 50), Color.RED)
    assert_equal(rect.pixel(39, 50), Color.BLACK)
    var triangle = run_headless[InsetOffGrid[True]](100, 100)
    assert_equal(triangle.pixel(40, 50), Color(191, 0, 0, 255))
    assert_equal(triangle.pixel(41, 50), Color.RED)
    assert_equal(triangle.pixel(39, 50), Color.BLACK)
    # The shadow paints with the shape, so it covers what the shape's own
    # edge covers, antialiased or not.
    for aa in [Antialiasing.OFF, Antialiasing.MEDIUM]:
        for triangle in [False, True]:
            var shadowed: Image
            var plain: Image
            if triangle:
                shadowed = run_headless[InsetOffGrid[True]](
                    100, 100, antialiasing=aa
                )
                plain = run_headless[InsetOffGrid[True, False]](
                    100, 100, antialiasing=aa
                )
            else:
                shadowed = run_headless[InsetOffGrid[False]](
                    100, 100, antialiasing=aa
                )
                plain = run_headless[InsetOffGrid[False, False]](
                    100, 100, antialiasing=aa
                )
            for x in range(36, 44):  # the band, 4 deep from 40.25
                assert_equal(
                    Int(shadowed.pixel(x, 50).r),
                    Int(plain.pixel(x, 50).r),
                    String(x),
                )


@fieldwise_init
struct WhollyShadowed[kind: Int](Program):
    """A cyan shape on black under an opaque black inset shadow thrown so
    far that it covers the whole of the shape's inside: a circle, whose
    shadow is analytic, a rounded triangle, a Bézier or text."""

    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> WhollyShadowed[Self.kind]:
        return WhollyShadowed[Self.kind](0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.BLACK)
        canvas.fill(Color(0, 255, 255))
        canvas.stroke(Color(0, 255, 255), 12)
        canvas.text_color(Color(0, 255, 255))
        canvas.font_size(60)
        canvas.shadow(Color.BLACK, offset=Vector(500, -500), blur=0)
        canvas.shadow(inset=True)
        with canvas.transform(Transform(rotation=0.3)):
            comptime if Self.kind == 0:
                canvas.stroke_enabled(False)
                canvas.circle((0.3, 0.0), 30.0)
            elif Self.kind == 1:
                canvas.stroke_enabled(False)
                canvas.triangle((-30, -25), (30, -25), (0, 30), corner_radius=6)
            elif Self.kind == 2:
                canvas.bezier((-40, -30), (-40, 60), (40, -60), (40, 30))
            else:
                canvas.text("W", (0, 0))


def _no_cyan(image: Image, name: String) raises:
    for y in range(100):
        for x in range(100):
            assert_equal(Int(image.pixel(x, y).g), 0, name + String(x, ",", y))


def test_an_inset_shadow_lets_nothing_through_at_the_edge() raises -> None:
    # Drawn after the shape over a partly covered pixel, the shadow would
    # leave some of the fill showing there: the shape's share, darkened by
    # the shadow only as much as that share.
    _no_cyan(run_headless[WhollyShadowed[0]](100, 100), "circle ")
    _no_cyan(run_headless[WhollyShadowed[1]](100, 100), "triangle ")
    _no_cyan(run_headless[WhollyShadowed[2]](100, 100), "bezier ")
    _no_cyan(run_headless[WhollyShadowed[3]](100, 100), "text ")


@fieldwise_init
struct OnGrid(Program):
    """Shapes whose every edge lies on a pixel boundary."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> OnGrid:
        return OnGrid(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.BLACK)
        canvas.fill(Color.RED)
        canvas.stroke(Color.WHITE, 3)
        canvas.rectangle((0.0, 0.0), 40.0, 20.0)
        canvas.rectangle((-30.0, 30.0), 10.0, 10.0)


def test_an_edge_on_the_pixel_grid_is_unchanged() raises -> None:
    var soft = run_headless[OnGrid](100, 100)
    var hard = run_headless[OnGrid](100, 100, antialiasing=Antialiasing.OFF)
    for y in range(100):
        for x in range(100):
            assert_equal(soft.pixel(x, y), hard.pixel(x, y), String(x, ", ", y))


@fieldwise_init
struct SameColorRing(Program):
    """An opaque red disc whose stroke is red too, at a radius off the
    pixel grid: inside its outer edge it must be solid red throughout."""

    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> SameColorRing:
        return SameColorRing(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.BLACK)
        canvas.fill(Color.RED)
        canvas.stroke(Color.RED, 3)
        canvas.circle((0.0, 0.0), 30.3)


def test_fill_and_stroke_meet_without_a_seam() raises -> None:
    # The stroke's inner edge, near radius 27.3, crosses pixels the fill
    # shares with it: each must be fill and stroke together, whole.
    var m = run_headless[SameColorRing](100, 100)
    var checked = 0
    for y in range(100):
        for x in range(100):
            var dx = Float64(x) + 0.5 - 50.0
            var dy = Float64(y) + 0.5 - 50.0
            if sqrt(dx * dx + dy * dy) < 29.0:
                assert_equal(m.pixel(x, y), Color.RED, String(x, ", ", y))
                checked += 1
    assert_true(checked > 2000)
    # The outer edge itself is soft: something between black and red.
    var soft = 0
    for x in range(50, 100):
        var r = m.pixel(x, 50).r
        if r > 0 and r < 255:
            soft += 1
    assert_true(soft >= 1, "the outer edge came out hard")


def test_antialiasing_writes_its_constant_name() raises -> None:
    assert_equal(String(Antialiasing.OFF), "Antialiasing.OFF")
    assert_equal(String(Antialiasing.HIGH), "Antialiasing.HIGH")
    assert_equal(String(Antialiasing(9)), "Antialiasing(9)")


@fieldwise_init
struct SwitchedOffLate[backend: Int](Program):
    """`OffGrid`'s square, then antialiasing switched off after drawing it."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        return Self(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.BLACK)
        canvas.stroke_enabled(False)
        canvas.fill(Color.RED)
        canvas.rectangle((0.25, 0.0), 20.0, 20.0)
        comptime if Self.backend == 0:
            # Column 40, a quarter uncovered: read at MEDIUM, then again.
            assert_equal(canvas.color_at((-9.6, 0.0)), Color(191, 0, 0, 255))
        canvas.antialiasing(Antialiasing.OFF)
        assert_true(canvas.antialiasing() == Antialiasing.OFF)
        comptime if Self.backend == 0:
            assert_equal(canvas.color_at((-9.6, 0.0)), Color.RED, "read again")


def test_switching_off_late_covers_the_whole_frame() raises -> None:
    var m = run_headless[SwitchedOffLate[0]](100, 100)
    assert_equal(m.pixel(40, 50), Color.RED)


def test_switching_off_late_covers_the_whole_gpu_frame() raises -> None:
    var m: Image
    try:
        m = run_headless[SwitchedOffLate[1]](
            100, 100, backend=RenderBackend.GPU
        )
    except e:
        print("SKIP — no GL context:", e)
        return
    for y in range(40, 60):
        var c = m.pixel(40, y)
        assert_true(
            c == Color.RED or c == Color.BLACK, "hard at row " + String(y)
        )


@fieldwise_init
struct OffFromCreate(Program):
    """Antialiasing switched off once, in `create`."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        canvas.antialiasing(Antialiasing.OFF)
        return Self(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.BLACK)
        canvas.stroke_enabled(False)
        canvas.fill(Color.RED)
        canvas.rectangle((0.25, 0.0), 20.0, 20.0)


def test_a_level_set_in_create_lasts() raises -> None:
    var m = run_headless[OffFromCreate](100, 100, 3)
    assert_equal(m.pixel(40, 50), Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
