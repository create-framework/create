# The boundary between a program and the compiled library (see
# src/create/_native.mojo): what crosses it in each direction, an error's
# message, the program itself, and the check that refuses a stale library.

from std.os import makedirs, remove
from std.os.path import exists
from std.testing import TestSuite, assert_equal, assert_false, assert_true
from std.time import sleep

from create import *
from create._native import stale_source

comptime _DROPPED = "/tmp/create_test_native_dropped"
"""Written by `Counter`'s destructor, which a test can't observe otherwise."""


@fieldwise_init
struct FailsInUpdate(Program):
    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        return Self(0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        raise Error("update failed on frame ", context.frame_count())


@fieldwise_init
struct FailsInCreate(Program):
    var _unused: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        raise Error("create failed")

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        pass


struct Counter(Program):
    """Counts its updates, drawing as many columns as it has counted, and
    writes the count to `_DROPPED` when it is dropped."""

    var updates: Int

    def __init__(out self):
        self.updates = 0

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        return Self()

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.updates += 1
        canvas.fill(Color.RED)
        canvas.stroke_enabled(False)
        for i in range(self.updates):
            canvas.rectangle((Float64(i * 4 - 18), 0.0), 2.0, 40.0)

    def __deinit__(deinit self):
        try:
            with open(_DROPPED, "w") as file:
                file.write(String(self.updates))
        except:
            pass


def test_an_error_in_update_reaches_the_caller_with_its_message() raises -> (
    None
):
    var message = String()
    try:
        _ = run_headless[FailsInUpdate](40, 40, frames=3)
    except e:
        message = String(e)
    assert_equal(message, "update failed on frame 2")


def test_an_error_in_create_reaches_the_caller_with_its_message() raises -> (
    None
):
    var message = String()
    try:
        _ = run_headless[FailsInCreate](40, 40, frames=3)
    except e:
        message = String(e)
    assert_equal(message, "create failed")


def test_an_error_in_a_canvas_read_reaches_the_caller() raises -> None:
    var canvas = Canvas(10, 10)
    var message = String()
    try:
        _ = canvas.snapshot(pixel_scale=-1.0)
    except e:
        message = String(e)
    assert_equal(message, "snapshot needs a positive pixel_scale, got -1.0")


def test_the_program_keeps_its_state_and_is_dropped_after_the_run() raises -> (
    None
):
    if exists(_DROPPED):
        remove(_DROPPED)
    var image = run_headless[Counter](40, 40, frames=5)
    # Five updates drew five columns: the program kept its count between
    # frames, though the library's loop called it.
    var columns = 0
    for x in range(40):
        if image.pixel(x, 20) == Color.RED and (
            x == 0 or image.pixel(x - 1, 20) != Color.RED
        ):
            columns += 1
    assert_equal(columns, 5)
    assert_true(exists(_DROPPED))
    assert_equal(open(_DROPPED, "r").read(), "5")
    remove(_DROPPED)


def _write(path: String) raises:
    with open(path, "w") as file:
        file.write("x")


def _checkout(root: String) raises -> Tuple[String, String]:
    """A checkout's layout under `root`, with a library built after its
    source: the paths of its `_native.mojo` and of the library."""
    makedirs(root + "/src/create/render", exist_ok=True)
    makedirs(root + "/src/native", exist_ok=True)
    _write(root + "/src/create/_native.mojo")
    _write(root + "/src/create/render/canvas.mojo")
    _write(root + "/src/native/libcreate.mojo")
    sleep(0.02)
    _write(root + "/libcreate.so")
    return (root + "/src/create/_native.mojo", root + "/libcreate.so")


def test_a_library_newer_than_the_source_is_used() raises -> None:
    var paths = _checkout("/tmp/create_test_native_fresh")
    assert_equal(stale_source(paths[1], paths[0]), "")


def test_a_library_older_than_the_source_is_refused() raises -> None:
    var root = "/tmp/create_test_native_stale"
    var paths = _checkout(root)
    sleep(0.02)
    _write(root + "/src/create/render/canvas.mojo")
    var why = stale_source(paths[1], paths[0])
    assert_true(root + "/src/create/render/canvas.mojo" in why)
    assert_true("pixi run native" in why)


def test_a_library_without_source_beside_it_is_not_checked() raises -> None:
    # An installed package: the source the program names is gone.
    var root = "/tmp/create_test_native_installed"
    makedirs(root, exist_ok=True)
    _write(root + "/libcreate.so")
    assert_false(
        Bool(stale_source(root + "/libcreate.so", root + "/gone/_native.mojo"))
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
