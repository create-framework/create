# The autoclear off on the GPU backend: a frame starts from the last one's
# pixels, as on the CPU, although a window's back buffer holds nothing
# defined after a swap, and a read with the autoclear off starts from the
# last frame too. Skips with no GL context, same as the parity test.

from std.testing import TestSuite, assert_equal, assert_true

from create.app._window import GLWindow

from create import *
from create._native import Slot
from create.app._driver import _Driver, _Host
from create.app._step import first_step, step
from create.app.headless import run_headless
from create.render._gl import GL, GL_COLOR_BUFFER_BIT
from create.render._gl_backend import GLRenderer
from create.render._gl_target import _GLTarget
from create.render._surface import MemorySurface
from create.render.canvas import _PersistentCanvasState
from create.render.render_backend import RenderBackend


comptime _SWAPPED = Color.BLUE
"""What the drawable holds after each simulated swap."""


@fieldwise_init
struct InkOnce(Program):
    """A red square in `create`, the autoclear off, and nothing after."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> InkOnce:
        canvas.autoclear(False)
        with canvas.style(fill=Color.RED, stroke_enabled=False):
            canvas.rectangle((0, 0), 20, 20)
        return InkOnce(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        pass


def _swapped_frames[
    P: Program
](antialiasing: Antialiasing, frames: Int) raises -> MemorySurface:
    """`P` through the GL backend into a 64 x 64 target that is overwritten
    with `_SWAPPED` after every present, as a swap leaves a window's back
    buffer undefined; the last frame, read back."""
    var target = _GLTarget(GL(), 64, 64)
    var gl = GLRenderer()
    var state = _PersistentCanvasState()
    state._backend[].antialiasing = antialiasing
    var context = Context()
    context.design_size(64, 64)
    context._set_viewport(state, 64, 64)
    var host = Slot(_Host[P]())
    var program = _Driver.of[P](host.address())
    first_step(program, context, state)
    var now = 0
    context.time._start(now)
    for i in range(frames + 1):
        if i > 0:
            now += 16
            context._advance_frame(now)
            state = step(program, context, state^)
        state._backend[].present_gpu(gl, 64, 64, state._view.scale)
        if i < frames:
            target.gl.clear_color(0.0, 0.0, 1.0, 1.0)
            target.gl.clear(GL_COLOR_BUFFER_BIT)
    var mem = MemorySurface(64, 64)
    mem.data = gl.read_frame(64, 64)
    _ = state^
    _ = program^
    _ = host^
    _ = gl^
    _ = target^
    return mem^


def test_a_frame_with_the_autoclear_off_survives_the_swap() raises -> None:
    var win: GLWindow
    try:
        win = GLWindow("gl_autoclear", 64, 64, offscreen=True)
    except e:
        print("SKIP — no GL context:", e)
        return
    for level in [Antialiasing.OFF, Antialiasing.MEDIUM]:
        var m = _swapped_frames[InkOnce](level, 3)
        assert_equal(m.pixel(32, 32), Color.RED, String(level))
        assert_equal(m.pixel(4, 4), Color.TRANSPARENT, String(level))
    _ = win^


@fieldwise_init
struct ReadsOnTop(Program):
    """Red in `create`, read once to keep frames; a blue square in frame 2;
    frame 3 reads both back."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> ReadsOnTop:
        canvas.autoclear(False)
        canvas.background(Color.RED)
        _ = canvas.color_at((0, 0))
        return ReadsOnTop(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.frame_count() == 2:
            assert_equal(canvas.color_at((0, 0)), Color.RED, "frame 2")
            with canvas.style(fill=Color.BLUE, stroke_enabled=False):
                canvas.rectangle((0, 0), 10, 10)
        else:
            assert_equal(canvas.color_at((0, 0)), Color.BLUE, "frame 3")
            assert_equal(canvas.color_at((20, 0)), Color.RED, "frame 3")


def test_a_read_with_the_autoclear_off_starts_from_the_last_frame() raises -> (
    None
):
    try:
        _ = GLWindow("gl_autoclear", 64, 64, offscreen=True)
    except e:
        print("SKIP — no GL context:", e)
        return
    # Outside the `try`: the program's own assertions must fail the test.
    var m = run_headless[ReadsOnTop](64, 32, 2, backend=RenderBackend.GPU)
    assert_equal(m.pixel(32, 16), Color.BLUE)
    assert_equal(m.pixel(4, 4), Color.RED)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
