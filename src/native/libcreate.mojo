"""The compiled library's entry points: `libcreate`, built by `pixi run
native` with `-D CREATE_LIBRARY_BUILD`.

Each entry point takes plain addresses, reads the values there as the types
both halves share, and calls the code a program would otherwise have
compiled itself. One that can fail writes the error's message into the
`String` at `error` and returns `False`; the program's side raises it again.
See `src/create/_native.mojo` for why the library exists and how a program
finds it.

Outside the package, so that precompiling `create` doesn't export these
from every program.
"""

from std.sys import size_of

from create._native import at, stale_source
from create.core._driver import _Driver, _RunSettings
from create.core.headless import _run_headless
from create.core.run import _run
from create.geometry import Rectangle
from create.image.image import Image
from create.math.point import Point
from create.color.color import Color
from create.render._backend import Backend
from create.render._backend_handle import free_backend, new_backend
from create.render.canvas import Canvas, _RecordingRequest, intern_image


@export
def create_check_source(library: Int, source: Int, error: Int) abi("C") -> Bool:
    var why = stale_source(at[String](library), at[String](source))
    if why:
        at[String](error) = why^
        return False
    return True


@export
def create_backend_new(size: Int, error: Int) abi("C") -> Int:
    if size != size_of[Backend]():
        at[String](error) = String(
            "create: the compiled library was built from a different version"
            " of Create than this program. Rebuild it (pixi run native) or"
            " point CREATE_LIBRARY at the matching one."
        )
        return 0
    try:
        return new_backend()
    except e:
        at[String](error) = String(e)
        return 0


@export
def create_backend_free(backend: Int) abi("C"):
    free_backend(backend)


@export
def create_backend_intern_image(backend: Int, image: Int) abi("C") -> Int:
    return intern_image(at[Backend](backend), at[Image](image))


@export
def create_canvas_color_at(
    canvas: Int, position: Int, result: Int, error: Int
) abi("C") -> Bool:
    try:
        at[Color](result) = at[Canvas](canvas)._color_at_here(
            at[Point](position)
        )
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_canvas_snapshot(
    canvas: Int, region: Int, pixel_scale: Float64, image: Int, error: Int
) abi("C") -> Bool:
    try:
        at[Optional[Image]](image) = at[Canvas](canvas)._snapshot_here(
            at[Rectangle](region), pixel_scale
        )
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_canvas_save_image(
    canvas: Int, path: Int, pixel_scale: Float64, transparent: Bool, error: Int
) abi("C") -> Bool:
    try:
        at[Canvas](canvas)._save_image_here(
            at[String](path), pixel_scale, transparent
        )
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_canvas_save_screenshot(
    canvas: Int, path: Int, error: Int
) abi("C") -> Bool:
    try:
        at[Canvas](canvas)._save_screenshot_here(at[String](path))
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_canvas_start_recording(
    canvas: Int, request: Int, error: Int
) abi("C") -> Bool:
    try:
        ref r = at[_RecordingRequest](request)
        at[Canvas](canvas)._start_recording_here(
            r.path,
            r.seconds,
            r.frames,
            r.fps,
            r.scale,
            r.dither,
            r.transparent,
        )
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_canvas_stop_recording(canvas: Int, error: Int) abi("C") -> Bool:
    try:
        at[Canvas](canvas)._state._backend[].captures.finish_recording()
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_canvas_cancel_recording(canvas: Int, error: Int) abi("C") -> Bool:
    try:
        at[Canvas](canvas)._state._backend[].captures.cancel_recording()
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_canvas_measure(
    canvas: Int, text: Int, wrap: Float64, height: Bool, result: Int, error: Int
) abi("C") -> Bool:
    try:
        ref c = at[Canvas](canvas)
        if height:
            at[Float64](result) = c._measure_height_here(at[String](text), wrap)
        else:
            at[Float64](result) = c._measure_width_here(at[String](text), wrap)
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_run(settings: Int, driver: Int, error: Int) abi("C") -> Bool:
    try:
        ref s = at[_RunSettings](settings)
        s.check_layout()
        _run(s, at[_Driver](driver))
        return True
    except e:
        at[String](error) = String(e)
        return False


@export
def create_run_headless(
    settings: Int, driver: Int, image: Int, error: Int
) abi("C") -> Bool:
    try:
        ref s = at[_RunSettings](settings)
        s.check_layout()
        at[Optional[Image]](image) = _run_headless(s, at[_Driver](driver))
        return True
    except e:
        at[String](error) = String(e)
        return False
