# How save_image, save_screenshot and start_recording name their files. The
# numbers a run hands out are kept for the whole process, so each test uses a
# folder or a name of its own.

from std.testing import TestSuite, assert_equal, assert_false, assert_true

from std.os import listdir, makedirs, remove, rmdir
from std.os.path import exists

from create import *

comptime _ROOT = "/tmp/create_test_file_naming/"


def _folder(name: String) raises -> String:
    """An empty folder for one test."""
    var folder = _ROOT + name + "/"
    if exists(folder):
        for file in listdir(folder):
            remove(folder + file)
        rmdir(folder)
    makedirs(folder)
    return folder


def _touch(path: String) raises:
    with open(path, "w") as f:
        f.write("")


def _canvas() raises -> Canvas:
    var canvas = Canvas(20, 10)
    canvas.background(Color.BLUE)
    return canvas^


def test_it_prints_by_name() raises -> None:
    assert_equal(String(FileNaming.EXACT), "FileNaming.EXACT")
    assert_equal(String(FileNaming.NUMBERED), "FileNaming.NUMBERED")


def test_a_path_is_used_exactly_and_replaced() raises -> None:
    var folder = _folder("exact")
    var canvas = _canvas()
    canvas.save_image(folder + "poster.png")
    canvas.save_image(folder + "poster.png")
    assert_equal(listdir(folder), ["poster.png"])
    assert_equal(Image.load(folder + "poster.png").width(), 20)


def test_numbered_saves_count_up_from_one() raises -> None:
    var folder = _folder("count")
    var canvas = _canvas()
    canvas.save_image(folder + "frame.png", naming=FileNaming.NUMBERED)
    canvas.save_image(folder + "frame.png", naming=FileNaming.NUMBERED)
    assert_true(exists(folder + "frame-0001.png"))
    assert_true(exists(folder + "frame-0002.png"))
    assert_false(exists(folder + "frame.png"))


def test_numbering_carries_on_after_the_highest_in_the_folder() raises -> None:
    var folder = _folder("carry_on")
    _touch(folder + "shot-0003.png")
    _touch(folder + "shot-0007.png")
    _touch(folder + "shot-12345678901.png")  # too long to be a number
    _touch(folder + "shot-0099.gif")  # another extension
    _touch(folder + "shot-final.png")
    _touch(folder + "other-0042.png")
    var canvas = _canvas()
    canvas.save_image(folder + "shot.png", naming=FileNaming.NUMBERED)
    assert_true(exists(folder + "shot-0008.png"))


def test_numbers_grow_past_four_digits() raises -> None:
    var folder = _folder("wide")
    _touch(folder + "big-9999.png")
    var canvas = _canvas()
    canvas.save_image(folder + "big.png", naming=FileNaming.NUMBERED)
    assert_true(exists(folder + "big-10000.png"))


def test_a_name_without_an_extension_is_numbered_at_its_end() raises -> None:
    var folder = _folder("bare")
    var canvas = _canvas()
    canvas.save_image(folder + "frame", naming=FileNaming.NUMBERED)
    assert_true(exists(folder + "frame-0001"))


def test_screenshots_are_numbered_too() raises -> None:
    var folder = _folder("screenshot")
    var canvas = _canvas()
    canvas.save_screenshot(folder + "shot.png", naming=FileNaming.NUMBERED)
    canvas.save_screenshot(folder + "shot.png", naming=FileNaming.NUMBERED)
    assert_true(exists(folder + "shot-0001.png"))
    assert_true(exists(folder + "shot-0002.png"))


def test_with_no_path_each_is_numbered_beside_the_caller() raises -> None:
    # Beside this file, so clear away what an earlier run left.
    var here = source_path("")
    for file in listdir(here):
        if file.startswith("image-") or file.startswith("screenshot-"):
            remove(here + file)
    var canvas = _canvas()
    canvas.save_image()
    canvas.save_image()
    canvas.save_screenshot()
    var image = exists(here + "image-0001.png")
    var second = exists(here + "image-0002.png")
    var screenshot = exists(here + "screenshot-0001.png")
    for file in listdir(here):
        if file.startswith("image-") or file.startswith("screenshot-"):
            remove(here + file)
    assert_true(image)
    assert_true(second)
    assert_true(screenshot)


@fieldwise_init
struct Saver(Program):
    """Saves its frame, numbered, on frames 1 and 3, and records two frames
    from frame 1."""

    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        canvas.save_image(
            _ROOT + "frames/frame.png", naming=FileNaming.NUMBERED
        )
        canvas.start_recording(
            _ROOT + "frames/clip.gif", naming=FileNaming.NUMBERED, frames=2
        )
        return Self(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.frame_count() == 3:
            canvas.save_image(
                _ROOT + "frames/frame.png", naming=FileNaming.NUMBERED
            )


def test_a_run_numbers_its_frames_and_recordings() raises -> None:
    var folder = _folder("frames")
    _ = run_headless[Saver](40, 30, frames=4)
    assert_true(exists(folder + "frame-0001.png"))
    assert_true(exists(folder + "frame-0002.png"))
    assert_true(exists(folder + "clip-0001.gif"))
    assert_false(exists(folder + "frame-0003.png"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
