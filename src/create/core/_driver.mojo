"""How the run loops call a program they are not generic over.

`run[P]` is generic over the program, so the loops it starts were compiled
again for every program, and they reach everything: the window, both
replays, the captures. Instead `run[P]` hands its loop a `_Driver`: the
program's `create` and `update` as two C functions, `_create_frame[P]` and
`_update_frame[P]`, and the address of the `_Host[P]` that keeps the program
between frames. The loops call the driver where they called `P`, so they
are the same code for every program.

An error raised by `create` or `update` can't unwind through a C function,
so a callback catches it and passes its message back, and the driver raises
it again, from where it ends the run as before.
"""

from create._native import Slot, address, at, check
from create.render.antialiasing import Antialiasing
from create.render.autoscale import Autoscale
from create.render.canvas import Canvas
from create.render.render_backend import RenderBackend
from .window_mode import WindowMode
from .context import Context
from .program import Program

comptime _FrameCallback = def(Int, Int, Int, Int) thin abi("C") -> Bool
"""`create` or `update`, given the host's, the context's, the canvas's and an
error `String`'s addresses; `False`, with the error written, if it raised."""


struct _Host[P: Program](Movable):
    """The program between frames, on the program's side."""

    var program: Optional[Self.P]

    def __init__(out self):
        self.program = None


def _create_frame[
    P: Program
](host: Int, context: Int, canvas: Int, error: Int) abi("C") -> Bool:
    try:
        at[_Host[P]](host).program = P.create(
            at[Context](context), at[Canvas](canvas)
        )
        return True
    except e:
        at[String](error) = String(e)
        return False


def _update_frame[
    P: Program
](host: Int, context: Int, canvas: Int, error: Int) abi("C") -> Bool:
    try:
        at[_Host[P]](host).program.value().update(
            at[Context](context), at[Canvas](canvas)
        )
        return True
    except e:
        at[String](error) = String(e)
        return False


@fieldwise_init
struct _Driver(Movable):
    """A program's `create` and `update`, as the loops call them."""

    var host: Int
    var create_frame: _FrameCallback
    var update_frame: _FrameCallback

    @staticmethod
    def of[P: Program](host: Int) -> _Driver:
        """Call `P`'s `create` and `update`, keeping the program in the
        `_Host[P]` at `host`: in a `Slot`, since the callbacks write it."""
        return _Driver(
            host=host,
            create_frame=_create_frame[P],
            update_frame=_update_frame[P],
        )

    def create(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Build the program, which draws frame 1."""
        var error = Slot(String())
        var ok = self.create_frame(
            self.host, address(context), address(canvas), error.address()
        )
        check(ok, error^)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        """Advance the program by a frame."""
        var error = Slot(String())
        var ok = self.update_frame(
            self.host, address(context), address(canvas), error.address()
        )
        check(ok, error^)


struct _RunSettings(Movable):
    """`run`'s and `run_headless`'s arguments, passed to their loops in
    one."""

    var title: String
    var mode: WindowMode
    var width: Int
    var height: Int
    var backend: RenderBackend
    var resizable: Bool
    var antialiasing: Antialiasing
    var autoscale: Autoscale
    var frames: Int
    """Headless only: how many `update`s to run."""
    var window_size: Optional[Tuple[Int, Int]]
    """Headless only: the pixel size of the window it stands in for."""

    def __init__(
        out self,
        title: String,
        mode: WindowMode,
        width: Int,
        height: Int,
        backend: RenderBackend,
        resizable: Bool,
        antialiasing: Antialiasing,
        autoscale: Autoscale,
        frames: Int = 0,
        window_size: Optional[Tuple[Int, Int]] = None,
    ):
        self.title = title
        self.mode = mode
        self.width = width
        self.height = height
        self.backend = backend
        self.resizable = resizable
        self.antialiasing = antialiasing
        self.autoscale = autoscale
        self.frames = frames
        self.window_size = window_size
