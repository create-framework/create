# Coverage the CPU-vs-GPU parity test and the GL batching tests are both
# blind to: `_flush_screenshot_gpu` is a real driver readback, not the CPU
# path's memcpy, and `save_image`'s CPU-replay-under-both-backends contract
# — documented but never checked — is what lets a GPU frame be captured at a
# resolution the window never had. Skips with no GL context, same as the
# other GL tests.

from std.os import remove

from _gif_decode import DecodedGif, decode_gif

from create import *
from create.core.headless import run_headless
from create.render.render_backend import RenderBackend
from create.image.image import Image
from std.testing import TestSuite, assert_equal

comptime _SHOT = "/tmp/mojo_create_test_gl_capture_shot.png"
comptime _IMG_CPU = "/tmp/mojo_create_test_gl_capture_image_cpu.png"
comptime _IMG_GPU = "/tmp/mojo_create_test_gl_capture_image_gpu.png"


def _saved(path: String) raises -> Image:
    """Read back a file one of these programs wrote, then delete it."""
    var back = Image.load(path)
    remove(path)
    return back^


def _px(s: Image, x: Int, y: Int) -> Color:
    var off = (y * s.width() + x) * 4
    return Color(
        s._pixels[][off],
        s._pixels[][off + 1],
        s._pixels[][off + 2],
        s._pixels[][off + 3],
    )


def _scene(mut canvas: Canvas):
    """A black ground with a 20x20 red square on the origin — the same
    layout `test_canvas.mojo`'s capture tests use, so the sample points
    below are proven-safe coordinates rather than newly guessed ones."""
    canvas.background(Color.BLACK)
    canvas.stroke_enabled(False)
    canvas.fill(Color.RED)
    canvas.rectangle((0.0, 0.0), 20.0, 20.0)


@fieldwise_init
struct GPUScreenshot(Program):
    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> GPUScreenshot:
        return GPUScreenshot(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        _scene(canvas)
        canvas.save_screenshot(_SHOT)


def test_gpu_screenshot_has_the_framebuffer_resolution_and_is_opaque() raises -> (
    None
):
    try:
        _ = run_headless[GPUScreenshot](
            200, 100, 1, window_size=(640, 480), backend=RenderBackend.GPU
        )
    except e:
        print("SKIP — no GL context:", e)
        return

    var shot = _saved(_SHOT)
    assert_equal(shot.width(), 640)
    assert_equal(shot.height(), 480)
    # The design area, scaled 3.2x and centred, with the bars either side —
    # same layout `test_canvas.mojo`'s CPU screenshot test checks.
    assert_equal(_px(shot, 320, 240), Color.RED)
    assert_equal(_px(shot, 320, 5), Color.BLACK)
    # _force_opaque runs on this path only: every alpha byte must read 255,
    # including under the red square, where the live frame is already
    # opaque, and under the bars, which the CPU screenshot leaves alone.
    assert_equal(_px(shot, 320, 240).a, 255)
    assert_equal(_px(shot, 320, 5).a, 255)


@fieldwise_init
struct CaptureImageCPU(Program):
    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> CaptureImageCPU:
        return CaptureImageCPU(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        _scene(canvas)
        canvas.save_image(_IMG_CPU)


@fieldwise_init
struct CaptureImageGPU(Program):
    var _unused: Int

    @staticmethod
    def create(
        mut context: Context, mut canvas: Canvas
    ) raises -> CaptureImageGPU:
        return CaptureImageGPU(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        _scene(canvas)
        canvas.save_image(_IMG_GPU)


def test_gpu_save_image_matches_cpu_save_image_byte_for_byte() raises -> None:
    var gpu_m: Image
    try:
        gpu_m = run_headless[CaptureImageGPU](
            200, 100, 1, window_size=(640, 480), backend=RenderBackend.GPU
        )
    except e:
        print("SKIP — no GL context:", e)
        return
    _ = gpu_m^

    # The CPU backend runs unconditionally: it needs no GL context, and the
    # comparison is meaningless without both files present.
    var cpu_m = run_headless[CaptureImageCPU](
        200, 100, 1, window_size=(640, 480)
    )
    _ = cpu_m^

    var cpu = _saved(_IMG_CPU)
    var gpu = _saved(_IMG_GPU)
    assert_equal(cpu.width(), gpu.width())
    assert_equal(cpu.height(), gpu.height())
    var a = cpu._pixels[].unsafe_ptr()
    var b = gpu._pixels[].unsafe_ptr()
    for i in range(cpu.width() * cpu.height() * 4):
        assert_equal(Int(a[unsafe_offset=i]), Int(b[unsafe_offset=i]))


@fieldwise_init
struct RecordFrames[path: StaticString](Program):
    """Records three frames of the scene, moving the square each frame."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        _scene(canvas)
        canvas.start_recording(String(Self.path), frames=3)
        return Self(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        with canvas.transform(translate(Float64(context.frame_count()), 0.0)):
            _scene(canvas)


comptime _GIF_CPU = "/tmp/mojo_create_test_gl_capture_record_cpu.gif"
comptime _GIF_GPU = "/tmp/mojo_create_test_gl_capture_record_gpu.gif"


def test_gpu_recording_matches_cpu_recording_byte_for_byte() raises -> None:
    # A recording replays each frame on the CPU under either backend, as
    # save_image does, so the two files are the same bytes.
    try:
        _ = run_headless[RecordFrames[_GIF_GPU]](
            200, 100, 8, window_size=(640, 480), backend=RenderBackend.GPU
        )
    except e:
        print("SKIP — no GL context:", e)
        return
    _ = run_headless[RecordFrames[_GIF_CPU]](
        200, 100, 8, window_size=(640, 480)
    )
    var cpu = open(_GIF_CPU, "r").read_bytes()
    var gpu = open(_GIF_GPU, "r").read_bytes()
    remove(_GIF_CPU)
    remove(_GIF_GPU)
    assert_equal(len(cpu), len(gpu))
    for i in range(len(cpu)):
        assert_equal(cpu[i], gpu[i])


comptime _GIF_RESTART = "/tmp/mojo_create_test_gl_capture_restart.gif"


@fieldwise_init
struct PaintAcrossARestart(Program):
    """With the autoclear off, white and then a red square more each
    frame, recorded at 50 fps; the third frame changes the antialiasing,
    which on the GPU starts the kept picture over from transparent."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        canvas.autoclear(False)
        canvas.background(Color.WHITE)
        PaintAcrossARestart._square(canvas, 0)
        canvas.start_recording(_GIF_RESTART, frames=4, fps=50)
        return Self(0)

    @staticmethod
    def _square(mut canvas: Canvas, index: Int):
        with canvas.style(fill=Color.RED, stroke_enabled=False):
            canvas.rectangle(
                (canvas.left() + 6.5 + 8.0 * Float64(index), 0.0), 6, 6
            )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.frame_count() == 3:
            canvas.antialiasing(Antialiasing.OFF)
        PaintAcrossARestart._square(canvas, context.frame_count() - 1)


def _mid_rgb(gif: DecodedGif, frame: Int, x: Int) -> Int:
    """Pixel `x` of `frame`'s middle row, as 0xRRGGBB."""
    var o = ((gif.height // 2) * gif.width + x) * 3
    ref p = gif.frames[frame].pixels
    return (Int(p[o]) << 16) | (Int(p[o + 1]) << 8) | Int(p[o + 2])


def test_a_gpu_restart_starts_an_autoclear_off_recording_over() raises -> None:
    try:
        _ = run_headless[PaintAcrossARestart](
            64, 48, 10, backend=RenderBackend.GPU
        )
    except e:
        print("SKIP — no GL context:", e)
        return
    var gif = decode_gif(_GIF_RESTART)
    remove(_GIF_RESTART)
    assert_equal(len(gif.frames), 4)

    # Before the change (frame 1 at 0 ms): square 0 on white.
    assert_equal(_mid_rgb(gif, 0, 6), 0xFF0000)
    assert_equal(_mid_rgb(gif, 0, 6 + 8), 0xFFFFFF)
    # From the change (frame 3, at 32 ms) on: only what was drawn since,
    # on the transparent black the GPU's picture starts over from.
    assert_equal(_mid_rgb(gif, 1, 6 + 8 * 2), 0xFF0000)
    assert_equal(
        _mid_rgb(gif, 1, 6), 0x000000
    )  # square 0 and the white are gone
    assert_equal(_mid_rgb(gif, 1, 6 + 8 * 3), 0x000000)
    assert_equal(_mid_rgb(gif, 2, 6 + 8 * 2), 0xFF0000)
    assert_equal(_mid_rgb(gif, 2, 6 + 8 * 3), 0xFF0000)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
