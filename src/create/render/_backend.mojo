from std.collections import Optional
from std.math import max, min, ceil, floor

from create.math.matrix import (
    Matrix,
    identity,
    inverse,
    _apply as mat_apply,
    scale as mat_scale,
    translate as mat_translate,
)

from ._command import RenderCommand
from ._gl_backend import GLRenderer
from ._surface import MemorySurface, Surface
from ._resources import Resources
from ._captures import Captures
from ._command_buffer import CommandBuffer
from ._cpu_replay import CpuReplay
from .antialiasing import Antialiasing


def _design_pixels(width: Int, height: Int) -> Matrix[3, 3]:
    """Screen space to the pixels of a `width` x `height` design-size
    image: origin centred and y up to origin top-left and y down."""
    return mat_translate(
        Float64(width) / 2.0, Float64(height) / 2.0
    ) @ mat_scale(1.0, -1.0)


def _clear_off_screen(
    mut mem: MemorySurface,
    to_target: Matrix[3, 3],
    width: Float64,
    height: Float64,
):
    """Make every pixel of `mem` whose centre is off the `width` x
    `height` screen transparent. A clear paints the whole target, and a
    read's target may reach past the screen, where the frame has nothing."""
    var a = mat_apply(to_target, -width / 2.0, height / 2.0)
    var b = mat_apply(to_target, width / 2.0, -height / 2.0)
    # Pixels whose centre `i + 0.5` lies in `[lo, hi)`.
    var x0 = max(Int(ceil(min(a[0], b[0]) - 0.5)), 0)
    var x1 = min(Int(ceil(max(a[0], b[0]) - 0.5)), mem.width)
    var y0 = max(Int(ceil(min(a[1], b[1]) - 0.5)), 0)
    var y1 = min(Int(ceil(max(a[1], b[1]) - 0.5)), mem.height)
    if x0 == 0 and y0 == 0 and x1 == mem.width and y1 == mem.height:
        return
    for y in range(mem.height):
        for x in range(mem.width):
            if y >= y0 and y < y1 and x >= x0 and x < x1:
                continue
            var off = (y * mem.width + x) * 4
            for k in range(4):
                mem.data[off + k] = 0


def _seed(
    mut mem: MemorySurface,
    last: MemorySurface,
    last_from_screen: Matrix[3, 3],
    to_target: Matrix[3, 3],
):
    """Fill `mem` from the pixels `last`, placed by `last_from_screen`
    (screen space to `last`'s pixels), each pixel the one under its centre:
    so a read with the autoclear off starts from what the frame itself
    started from, and an offscreen canvas is read at any scale."""
    var to_last = last_from_screen @ inverse(to_target)
    for y in range(mem.height):
        for x in range(mem.width):
            var p = mat_apply(to_last, Float64(x) + 0.5, Float64(y) + 0.5)
            var lx = Int(floor(p[0]))
            var ly = Int(floor(p[1]))
            if lx < 0 or ly < 0 or lx >= last.width or ly >= last.height:
                continue
            var src = (ly * last.width + lx) * 4
            var dst = (y * mem.width + x) * 4
            for k in range(4):
                mem.data[dst + k] = last.data[src + k]


struct Backend(Movable):
    """Where a frame's recorded commands become pixels.

    One struct with a runtime branch on `kind` rather than a trait: Mojo 1.0
    has no dynamic trait dispatch, so a trait in type position would form an
    inert `AnyTrait[T]` that nothing converts into.

    This is what survives the frame boundary. Fonts and glyph masks already
    had to — reloading a face every frame would be absurd — and GPU resources
    join them for exactly the same reason, so the backend is the natural owner
    of both.
    """

    var antialiasing: Antialiasing
    """How the CPU replay smooths shapes' edges, live or for a read; the GPU
    multisamples its own framebuffer, chosen with its window."""
    var cpu: CpuReplay
    """The CPU replay: the CPU backend's presents, and every capture and
    read on either backend."""
    var resources: Resources
    """The fonts' glyph cache and the interned images, which every replay
    reads: the CPU's here, the GPU's through `present_gpu`."""
    var captures: Captures
    """The `save_image`, `save_screenshot` and recording requests filed by
    the canvas, serviced at present."""
    var screen_inv: Matrix[3, 3]
    """This frame's window-pixel-to-screen mapping, the inverse of the base
    every command's transform starts from; set by `begin_frame`. A read
    composes it in front of its own screen-to-target mapping, as a capture
    does."""
    var screen_w: Float64
    var screen_h: Float64
    """This frame's screen extent in design units, `canvas.width()` and
    `canvas.height()`."""
    var frame_w: Int
    var frame_h: Int
    """The screen extent rounded to whole units: the size of a read at
    design size, `frame_read`'s and `last_frame`'s, centred on the
    screen."""
    var frame_read: Optional[MemorySurface]
    """The frame so far at design size, as `canvas.color_at` last read
    it; `frame_read_at` is the `recorded` it was read at."""
    var frame_read_at: Int
    var keep_frames: Bool
    """Whether `present` keeps a copy of each finished frame in
    `last_frame`. Switched on by the first read made with the autoclear off,
    the one case where a frame starts from the last one's pixels rather than
    from its own commands."""
    var last_frame: Optional[MemorySurface]
    """The last presented frame at design size, while `keep_frames`
    is on: what a read with the autoclear off starts from."""
    var target: Optional[MemorySurface]
    """The pixels of an offscreen canvas, present exactly when this backend
    records for one. Such a canvas has no frames to present, so `bake`
    replays onto this instead, and its reads come from it."""
    var buffer: CommandBuffer
    """The frame being recorded: its commands and clips."""

    def __init__(out self) raises:
        self.antialiasing = Antialiasing.OFF
        self.cpu = CpuReplay()
        self.buffer = CommandBuffer()
        self.resources = Resources()
        self.captures = Captures()
        self.screen_inv = identity[3]()
        self.screen_w = 0.0
        self.screen_h = 0.0
        self.frame_w = 0
        self.frame_h = 0
        self.frame_read = None
        self.frame_read_at = -1
        self.keep_frames = False
        self.last_frame = None
        self.target = None

    def _flush_image(mut self, cmds: List[RenderCommand]) raises:
        """Service a pending `save_image` by replaying `cmds` a second time.

        Onto an owned buffer of the capture's own size, through the CPU
        rasteriser under both backends — the glyph cache and the image cache
        live here rather than on `GLRenderer`, so a GPU frame needs no readback
        to be captured at a resolution the window never had.

        The bars are dropped by contract: the capture is the design area, and
        a bar is a property of the window it is not being saved at. A
        transparent capture drops the frame's clear as well, so the background
        keeps the buffer's alpha 0.
        """
        if not self.captures.pending_image:
            return
        var request = self.captures.pending_image.take()
        var mem = MemorySurface(request.width, request.height)
        self.replay(
            mem.surface(),
            cmds,
            request.scale,
            pre=request.rebase,
            skip_letterbox=True,
            skip_clear=request.transparent,
        )
        mem.save(request.path, opaque=not request.transparent)

    def _record_frame(mut self, cmds: List[RenderCommand]) raises:
        """Capture the presented frame into the recording, if its slot is due.

        Replayed on the CPU onto a buffer of the recording's own size, as
        `_flush_image` captures, so both backends record the same pixels.
        """
        var slot = self.captures.frame_due()
        if not slot:
            return
        ref recording = self.captures.recording.value()
        var mem = MemorySurface(recording.width, recording.height)
        var scale = recording.scale
        var pre = recording.capture_base @ self.screen_inv
        self.replay(mem.surface(), cmds, scale, pre=pre, skip_letterbox=True)
        self.captures.add_frame(mem, slot.value())

    def begin_frame(
        mut self, screen: Matrix[3, 3], width: Float64, height: Float64
    ):
        """Note the frame's screen-to-window mapping and extent, for reads
        and for keeping the finished frame."""
        self.screen_inv = inverse(screen)
        self.screen_w = width
        self.screen_h = height
        self.frame_w = Int(width + 0.5)
        self.frame_h = Int(height + 0.5)
        self.buffer.autoclear_head = False

    def read(
        mut self,
        width: Int,
        height: Int,
        scale: Float64,
        to_target: Matrix[3, 3],
        seeded: Bool,
    ) raises -> MemorySurface:
        """The frame so far, `width` x `height` pixels, placed by
        `to_target` (screen space to the target's pixels) at `scale` pixels
        per screen unit.

        Replayed on the CPU from the commands recorded up to now, as
        `save_image` is, so both backends read the same pixels and the GPU
        is never asked. `seeded` starts from the last presented frame rather
        than transparent — for a frame drawn with the autoclear off, which
        is how the frame itself started. The first such read only switches
        keeping frames on, so it starts transparent.
        """
        var mem = MemorySurface(width, height)
        if seeded:
            if self.last_frame:
                ref last = self.last_frame.value()
                _seed(
                    mem,
                    last,
                    _design_pixels(last.width, last.height),
                    to_target,
                )
            self.keep_frames = True
        var cmds = self.buffer.commands^
        self.buffer.commands = List[RenderCommand]()
        self.replay(
            mem.surface(),
            cmds,
            scale,
            pre=to_target @ self.screen_inv,
            skip_letterbox=True,
        )
        self.buffer.commands = cmds^
        _clear_off_screen(mem, to_target, self.screen_w, self.screen_h)
        return mem^

    def read_frame(mut self, seeded: Bool) raises:
        """Bring `frame_read` up to the frame so far at design size,
        reading again only if something has been recorded since the last
        time."""
        if not self.frame_read or self.frame_read_at != self.buffer.recorded:
            self.frame_read = self.read(
                self.frame_w,
                self.frame_h,
                1.0,
                _design_pixels(self.frame_w, self.frame_h),
                seeded,
            )
            self.frame_read_at = self.buffer.recorded

    def _keep_frame[o: Origin[mut=True]](mut self, s: Surface[o]):
        """Sample the finished frame on `s` (window pixels) down or up to
        design size, nearest pixel, into `last_frame`."""
        var mem = MemorySurface(self.frame_w, self.frame_h)
        var to_window = inverse(self.screen_inv)
        var from_design = to_window @ inverse(
            _design_pixels(self.frame_w, self.frame_h)
        )
        for y in range(self.frame_h):
            for x in range(self.frame_w):
                var p = mat_apply(
                    from_design, Float64(x) + 0.5, Float64(y) + 0.5
                )
                var wx = Int(floor(p[0]))
                var wy = Int(floor(p[1]))
                if wx < 0 or wy < 0 or wx >= s.width or wy >= s.height:
                    continue
                var src = s.offset(wx, wy)
                var dst = (y * self.frame_w + x) * 4
                for k in range(4):
                    mem.data[dst + k] = s.px[unsafe_offset=src + k]
        self.last_frame = mem^

    def present[
        o: Origin[mut=True]
    ](mut self, s: Surface[o], scale: Float64) raises:
        """Render the recorded frame onto `s` and start a new recording.

        The buffer is moved out and back rather than iterated in place: replay
        needs `self` mutably (the glyph cache and the image cache both fill in
        as it runs), which it cannot have while borrowing a field of `self`.
        Moving it back keeps its capacity for the next frame.
        """
        var cmds = self.buffer.commands^
        self.buffer.commands = List[RenderCommand]()
        self.replay(s, cmds, scale)
        self.captures.flush_screenshot(s)
        self._flush_image(cmds)
        self._record_frame(cmds)
        if self.keep_frames:
            self._keep_frame(s)
        cmds.clear()
        self.buffer.commands = cmds^
        self.buffer.clips.clear()
        self.buffer.clip = 0
        self.frame_read = None
        _ = self.resources.expire_images()

    def discard(mut self):
        """Drop everything recorded so far, and an offscreen canvas's
        pixels with it. The clips stay while one is open, as in `bake`."""
        self.buffer.commands.clear()
        if self.buffer.clip == 0:
            self.buffer.clips.clear()
        self.buffer.autoclear_head = False
        self.buffer.recorded += 1
        if self.target:
            ref target = self.target.value()
            target.data = List[UInt8](
                length=target.width * target.height * 4, fill=0
            )

    def bake(mut self, scale: Float64) raises:
        """Replay what has been recorded onto `target` and drop it: an
        offscreen canvas's `present`, run by each read.

        Its pixels are where the next replay starts, so a canvas kept as a
        field and drawn into every frame holds its pixels, not every command
        it was ever given. The clips go with the commands only while none is
        open: a command recorded inside an open `canvas.clip` after this
        still names its level by index.
        """
        if len(self.buffer.commands) == 0:
            return
        var cmds = self.buffer.commands^
        self.buffer.commands = List[RenderCommand]()
        var mem = self.target.take()
        self.replay(mem.surface(), cmds, scale, skip_letterbox=True)
        self.target = mem^
        cmds.clear()
        self.buffer.commands = cmds^
        if self.buffer.clip == 0:
            self.buffer.clips.clear()
        self.buffer.recorded += 1
        _ = self.resources.expire_images()

    def present_gpu(
        mut self, mut gl: GLRenderer, width: Int, height: Int, scale: Float64
    ) raises:
        """The GPU counterpart of `present`, onto the current drawable
        through `gl`, which the GL loop owns: it holds the context's
        resources, so it is built after the window and dies before it.

        Same contract: the frame is consumed and the recording left empty with
        its capacity intact. There is no `Surface` because there is no host
        pixel buffer — `width` and `height` are the drawable's, which is what
        the letterbox bars and `glViewport` are sized from.
        """
        var cmds = self.buffer.commands^
        self.buffer.commands = List[RenderCommand]()
        gl.render(
            cmds,
            self.buffer.clips,
            self.resources.images,
            self.resources.text[],
            width,
            height,
            scale,
            self.antialiasing._gpu_samples(),
        )
        self.captures.flush_screenshot_gpu(gl, width, height)
        self._flush_image(cmds)
        self._record_frame(cmds)
        cmds.clear()
        self.buffer.commands = cmds^
        self.buffer.clips.clear()
        self.buffer.clip = 0
        self.frame_read = None
        gl.forget_images(self.resources.expire_images())

    def replay[
        o: Origin[mut=True]
    ](
        mut self,
        s: Surface[o],
        cmds: List[RenderCommand],
        scale: Float64,
        pre: Matrix[3, 3] = identity[3](),
        skip_letterbox: Bool = False,
        skip_clear: Bool = False,
    ) raises:
        """Render `cmds` onto `s` on the CPU, against this backend's images,
        clips and antialiasing level; see `CpuReplay.replay`."""
        self.cpu.replay(
            self.resources,
            s,
            cmds,
            self.buffer.clips,
            self.antialiasing,
            scale,
            pre,
            skip_letterbox,
            skip_clear,
        )
