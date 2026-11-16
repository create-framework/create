# canvas.start_recording, run headless: the synthetic clock (16 ms a frame) makes
# every recording deterministic, so frame counts and delays are exact. Each
# scenario is one parameter of the program; the GIF is read back with the
# decoder in _gif_decode.mojo.

from std.testing import TestSuite, assert_equal, assert_true

from std.os import remove
from std.os.path import exists

from _gif_decode import DecodedGif, decode_gif
from create import *

comptime _WIDTH = 64
comptime _HEIGHT = 48


def _path(scenario: Int) -> String:
    return "/tmp/create_test_record_" + String(scenario) + ".gif"


@fieldwise_init
struct Recorder[scenario: Int](Program):
    """Red in `create`, a shade of gray after, with a corner square green
    while a recording is in progress and blue once none is."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        canvas.background(Color.RED)
        if Self.scenario == 0:
            canvas.start_recording(_path(0), frames=5)
        elif Self.scenario == 1:
            canvas.start_recording(_path(1), seconds=0.5)
        elif Self.scenario == 2 or Self.scenario == 3:
            canvas.start_recording(_path(Self.scenario))
        elif Self.scenario == 4:
            canvas.start_recording(_path(4))
        elif Self.scenario == 5:
            canvas.start_recording(_path(5), frames=2, scale=0.5)
        elif Self.scenario == 6 or Self.scenario == 7:
            canvas.start_recording(_path(Self.scenario))
        elif Self.scenario == 10:
            canvas.start_recording("/tmp/create_test_record.png")
        elif Self.scenario == 11:
            canvas.start_recording(_path(11), seconds=1, frames=10)
        elif Self.scenario == 12:
            canvas.start_recording(_path(12), fps=60)
        elif Self.scenario == 13:
            var offscreen = Canvas(10, 10)
            offscreen.start_recording(_path(13))
        elif Self.scenario == 14:
            canvas.start_recording(_path(14), frames=0)
        return Self(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var frame = context.frame_count()
        if Self.scenario == 2 and frame == 10:
            canvas.stop_recording()
        if Self.scenario == 6 and frame == 3:
            # Mid-recording, the frames go to the .partial file only.
            if not exists(_path(6) + ".partial"):
                raise Error("no .partial file while recording")
        if Self.scenario == 6 and frame == 5:
            canvas.cancel_recording()
        if Self.scenario == 4 and frame == 6:
            canvas.start_recording(_path(41), frames=3)
        canvas.background(Color(UInt8(frame * 8), UInt8(frame * 8), 100))
        with canvas.style(
            fill=Color.GREEN if canvas.recording() else Color.BLUE,
            stroke_enabled=False,
        ):
            canvas.rectangle((canvas.left() + 4, canvas.top() - 4), 8, 8)


def _square(mut canvas: Canvas, index: Int):
    """A black 6x6 square, the `index`th along the middle row from the
    left: its centre is pixel (6 + 8 * index, `_HEIGHT // 2`)."""
    with canvas.style(fill=Color.BLACK, stroke_enabled=False):
        canvas.rectangle(
            (canvas.left() + 6.5 + 8.0 * Float64(index), 0.0), 6, 6
        )


@fieldwise_init
struct Painter[scenario: Int](Program):
    """With the autoclear off: white once, then a square more each frame,
    recorded at 50 fps from `create` on. A frame lasts 16 ms, so the second
    frame shares the first's slot and is never captured itself."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        canvas.autoclear(False)
        canvas.background(Color.WHITE)
        _square(canvas, 0)
        canvas.start_recording(_path(20 + Self.scenario), frames=4, fps=50)
        return Self(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        _square(canvas, context.frame_count() - 1)


def _rgb(gif: DecodedGif, frame: Int, x: Int, y: Int) -> Tuple[Int, Int, Int]:
    var o = (y * gif.width + x) * 3
    ref pixels = gif.frames[frame].pixels
    return (Int(pixels[o]), Int(pixels[o + 1]), Int(pixels[o + 2]))


def _painted(gif: DecodedGif, frame: Int, index: Int) raises -> Bool:
    """Whether square `index` is in `frame`, which must be black or white
    there."""
    var c = _rgb(gif, frame, 6 + 8 * index, _HEIGHT // 2)
    if c[0] == 0 and c[1] == 0 and c[2] == 0:
        return True
    assert_equal(c[0], 255)
    assert_equal(c[1], 255)
    assert_equal(c[2], 255)
    return False


def _delays(gif: DecodedGif) -> Int:
    var total = 0
    for frame in gif.frames:
        total += frame.delay
    return total


def _no_partial(scenario: Int) raises:
    assert_true(
        not exists(_path(scenario) + ".partial"),
        "a finished recording left its .partial file",
    )


def _write_text(path: String, text: String) raises:
    var f = open(path, "w")
    f.write(text)
    f.close()


def _corner(image: Image) -> Color:
    return image.pixel(2, 2)


def test_a_frame_limit_records_that_many_frames() raises -> None:
    var last = run_headless[Recorder[0]](
        _WIDTH, _HEIGHT, 30, antialiasing=Antialiasing.OFF
    )
    var gif = decode_gif(_path(0))
    assert_equal(gif.width, _WIDTH)
    assert_equal(gif.height, _HEIGHT)
    assert_true(gif.loops)
    assert_equal(len(gif.frames), 5)
    # Five slots of a 30 fps recording: 16.7 hundredths, rounded once.
    assert_equal(_delays(gif), 17)
    for frame in gif.frames:
        assert_true(frame.delay == 3 or frame.delay == 4)
    # The first frame is the one record was called in, which create drew.
    var middle = ((_HEIGHT // 2) * _WIDTH + _WIDTH // 2) * 3
    assert_equal(Int(gif.frames[0].pixels[middle]), 255)
    assert_equal(Int(gif.frames[0].pixels[middle + 1]), 0)
    assert_equal(Int(gif.frames[0].pixels[middle + 2]), 0)
    # Finished at its fifth frame, long before the run ended.
    assert_equal(_corner(last), Color.BLUE)
    _no_partial(0)


def test_a_time_limit_records_that_much_of_the_run() raises -> None:
    _ = run_headless[Recorder[1]](_WIDTH, _HEIGHT, 60)
    var gif = decode_gif(_path(1))
    # Half a second exactly, however the frames fell into it.
    assert_equal(_delays(gif), 50)
    assert_equal(len(gif.frames), 15)


def test_stop_recording_finishes_the_file_at_once() raises -> None:
    var last = run_headless[Recorder[2]](_WIDTH, _HEIGHT, 20)
    assert_equal(_corner(last), Color.BLUE)
    var gif = decode_gif(_path(2))
    # Frames 1 to 9 at 16 ms each span 0.128 s: slots 0 to 3.
    assert_equal(len(gif.frames), 4)


def test_the_run_ending_finishes_the_file() raises -> None:
    var last = run_headless[Recorder[3]](_WIDTH, _HEIGHT, 20)
    assert_equal(_corner(last), Color.GREEN)
    var gif = decode_gif(_path(3))
    # 21 frames, the last at 0.32 s: slots 0 to 9.
    assert_equal(len(gif.frames), 10)
    _no_partial(3)


def test_cancelling_leaves_no_file_and_the_old_one_untouched() raises -> None:
    _write_text(_path(6), "an older take")
    var last = run_headless[Recorder[6]](_WIDTH, _HEIGHT, 20)
    assert_equal(_corner(last), Color.BLUE)
    _no_partial(6)
    assert_equal(open(_path(6), "r").read(), "an older take")
    remove(_path(6))


def test_a_finished_recording_replaces_an_older_file() raises -> None:
    _write_text(_path(7), "an older take")
    _ = run_headless[Recorder[7]](_WIDTH, _HEIGHT, 10)
    var gif = decode_gif(_path(7))
    assert_true(len(gif.frames) > 0)
    _no_partial(7)


def test_a_new_recording_finishes_the_one_before() raises -> None:
    _ = run_headless[Recorder[4]](_WIDTH, _HEIGHT, 30)
    var first = decode_gif(_path(4))
    # Frames 1 to 5, at 0 to 0.064 s: slots 0 to 1.
    assert_equal(len(first.frames), 2)
    var second = decode_gif(_path(41))
    assert_equal(len(second.frames), 3)


def test_scale_sets_the_recordings_size() raises -> None:
    _ = run_headless[Recorder[5]](_WIDTH, _HEIGHT, 10)
    var gif = decode_gif(_path(5))
    assert_equal(gif.width, _WIDTH // 2)
    assert_equal(gif.height, _HEIGHT // 2)


def test_with_the_autoclear_off_a_recording_keeps_what_the_screen_keeps() raises -> (
    None
):
    _ = run_headless[Painter[0]](
        _WIDTH, _HEIGHT, 10, antialiasing=Antialiasing.OFF
    )
    var gif = decode_gif(_path(20))
    assert_equal(len(gif.frames), 4)
    # The frames at 0, 32, 48 and 64 ms: squares 0, 0 to 2, 0 to 3 and 0 to
    # 4. Square 1, drawn in the frame no slot captured, is kept all the same,
    # and the white from create stays under them all.
    var last = [0, 2, 3, 4]
    for frame in range(4):
        for index in range(6):
            assert_equal(
                _painted(gif, frame, index),
                index <= last[frame],
                String("frame ", frame, ", square ", index),
            )
    remove(_path(20))


def _raises[scenario: Int](expected: String) raises:
    var message = String()
    try:
        _ = run_headless[Recorder[scenario]](_WIDTH, _HEIGHT, 1)
    except e:
        message = String(e)
    assert_true(
        expected in message,
        String("expected an error with '", expected, "', got '", message, "'"),
    )


def test_record_refuses_what_it_cannot_do() raises -> None:
    _raises[10](".gif")
    _raises[11]("not both")
    _raises[12]("at most 50")
    _raises[13]("offscreen")
    _raises[14]("positive number of frames")


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
