from std.collections import Optional
from std.memory import unsafe_memcpy
from std.math import max, min, ceil, floor

from create.math.matrix import (
    Matrix,
    identity,
    inverse,
    _apply as mat_apply,
    scale as mat_scale,
    translate as mat_translate,
)

from ._command import ClearPayload, RenderCommand, _clear_is_opaque
from ._gl_backend import GLRenderer
from ._clip import _Clip
from ._transform import uniform
from ._gif import GifWriter, encode_frame
from ._png import write_png
from ._surface import MemorySurface, Surface, _force_opaque
from ._resources import Resources
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


@fieldwise_init
struct _ImageRequest(Movable):
    """A `canvas.save_image` that has not been serviced yet.

    Filed while recording and flushed at present, because present is the only
    place holding both the finished command buffer and a target to replay it
    onto. Deferring also makes the contract honest: the file gets the *whole*
    frame no matter where in `update` the call was made.
    """

    var path: String
    var width: Int
    var height: Int
    var scale: Float64
    """The capture's pixel scale — the fallback for commands whose transform
    is not uniform, exactly as the live frame's autoscale factor is."""
    var rebase: Matrix[3, 3]
    """`capture_base @ window_base_inv` — see `replay`'s `pre`."""
    var transparent: Bool


def _centiseconds(slot: Int, fps: Float64) -> Int:
    """When `slot` starts, in a GIF's hundredths of a second from the first.
    Delays are differences of these, so rounding never accumulates."""
    return Int(Float64(slot) * 100.0 / fps + 0.5)


struct _Recording(Movable):
    """A `canvas.start_recording` in progress, captured at each present it is due.

    The run's clock is cut into slots `1 / fps` long from the frame the
    recording starts in; a frame is captured in each slot the clock enters,
    and a slot no frame entered (a slow frame) extends the frame before it.
    A frame's delay is written ahead of its pixels, so the latest capture
    waits in `pending` until the next one says how many slots it covered.
    """

    var writer: GifWriter
    var width: Int
    var height: Int
    var scale: Float64
    """The capture's pixel scale, as `_ImageRequest.scale`."""
    var capture_base: Matrix[3, 3]
    """Design space to the capture's pixels; composed with each frame's own
    `screen_inv` at present, so a resized window records the same."""
    var fps: Float64
    var dither: Bool
    var max_slots: Optional[Int]
    """From `seconds`: the slots the recording may fill."""
    var max_frames: Optional[Int]
    var started: Bool
    var start: Float64
    """The clock at the first present: slot 0 begins there."""
    var next_slot: Int
    var frames: Int
    """Frames captured so far, the pending one included."""
    var pending: Optional[List[UInt8]]
    var pending_slot: Int
    var written: Int
    """Centiseconds already given to the frames written."""

    def __init__(
        out self,
        var writer: GifWriter,
        scale: Float64,
        capture_base: Matrix[3, 3],
        fps: Float64,
        dither: Bool,
        max_slots: Optional[Int],
        max_frames: Optional[Int],
    ):
        self.width = writer.width
        self.height = writer.height
        self.writer = writer^
        self.scale = scale
        self.capture_base = capture_base
        self.fps = fps
        self.dither = dither
        self.max_slots = max_slots
        self.max_frames = max_frames
        self.started = False
        self.start = 0.0
        self.next_slot = 0
        self.frames = 0
        self.pending = None
        self.pending_slot = 0
        self.written = 0

    def write_pending(mut self, until_slot: Int) raises:
        """Write the waiting frame, shown until `until_slot` begins."""
        if not self.pending:
            return
        var end = _centiseconds(until_slot, self.fps)
        var frame = self.pending.take()
        self.writer.write_frame(frame, end - self.written)
        self.written = end


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
    var recording: Optional[_Recording]
    """A `canvas.start_recording` in progress; see `_record_frame`."""
    var clock: Float64
    """The run's elapsed time at the frame being recorded, handed in by the
    loops (render never imports core): what a recording is timed by."""
    var pending_screenshot: Optional[String]
    """A `save_screenshot` filed by this frame, serviced at present.

    Just a path: a screenshot has no geometry to decide, which is the whole
    difference from `_ImageRequest` — it is whatever the framebuffer holds
    once the frame has been rendered.
    """
    var pending_image: Optional[_ImageRequest]
    """A `save_image` filed by this frame, serviced at present.

    One per frame: a second call overwrites the first, which is the only
    sensible reading of two saves of the same frame to two paths being asked
    for by accident.
    """
    var clips: List[_Clip]
    """This frame's `canvas.clip` levels, in the order they were opened;
    a command's `clip` is an index into it, one past. Both replays build their
    own form of each — rows on the CPU, the stencil on the GPU — and it is
    reset with the command buffer."""
    var clip: Int
    """The clip a command recorded now is rendered under: the innermost
    open `canvas.clip`, or 0. `ClipGuard` sets it back on exit."""
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
    var recorded: Int
    """Records ever made, a clock for `frame_read`: a read is current while
    nothing has been recorded since. A count of commands would not do, since
    `record_clear` can replace one without adding any."""
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
    var autoclear_head: Bool
    """Whether the frame's first command is still the clear the frame opened
    with, so `set_autoclear` can take it back out. Cleared when a
    `background()` replaces it, which then stays."""
    var target: Optional[MemorySurface]
    """The pixels of an offscreen canvas, present exactly when this backend
    records for one. Such a canvas has no frames to present, so `bake`
    replays onto this instead, and its reads come from it."""
    var commands: List[RenderCommand]
    """The frame being recorded.

    The buffer lives here rather than travelling out of `Canvas` because a
    `Tuple` of move-only values cannot be unpacked in this Mojo version — see
    `present`, which is also where the buffer is reset. Keeping it means the
    allocation is reused frame to frame instead of being rebuilt per frame.
    """

    def __init__(out self) raises:
        self.antialiasing = Antialiasing.OFF
        self.cpu = CpuReplay()
        self.resources = Resources()
        self.commands = List[RenderCommand]()
        self.clips = List[_Clip]()
        self.clip = 0
        self.screen_inv = identity[3]()
        self.screen_w = 0.0
        self.screen_h = 0.0
        self.frame_w = 0
        self.frame_h = 0
        self.recorded = 0
        self.autoclear_head = False
        self.frame_read = None
        self.frame_read_at = -1
        self.keep_frames = False
        self.last_frame = None
        self.target = None
        self.pending_image = Optional[_ImageRequest]()
        self.pending_screenshot = Optional[String]()
        self.recording = None
        self.clock = 0.0

    def record(mut self, var c: RenderCommand):
        """Append one render to the frame being recorded, under the current
        clip."""
        c.clip = self.clip
        self.recorded += 1
        self.commands.append(c^)

    def push_clip(mut self, var region: RenderCommand, invert: Bool) -> Int:
        """Open a clip nested in the current one and make it current.
        Returns the clip it replaced, for the guard to restore."""
        var previous = self.clip
        self.clips.append(_Clip(region^, invert, previous))
        self.clip = len(self.clips)
        return previous

    def record_clear(mut self, var c: RenderCommand):
        """Append a clear, replacing an adjacent one it would erase anyway.

        An opaque clear covers the whole framebuffer, so any clear recorded
        immediately before it — with no render in between to survive — paints
        nothing. Dropping it here rather than at replay keeps both backends
        and both captures agreeing, and costs the common case nothing: a
        program that keeps `canvas.autoclear` on and also opens `update` with
        `background()` records one clear, not two. A clipped clear covers only
        its clip, so it replaces nothing.
        """
        c.clip = self.clip
        self.recorded += 1
        if (
            c.clip == 0
            and _clear_is_opaque(c)
            and len(self.commands) > 0
            and self.commands[len(self.commands) - 1].payload.isa[
                ClearPayload
            ]()
        ):
            if len(self.commands) == 1:
                self.autoclear_head = False
            self.commands[len(self.commands) - 1] = c^
            return
        self.commands.append(c^)

    def open_with_clear(mut self, var clear: RenderCommand):
        """Record the clear a frame opens with, as its first command."""
        self.record_clear(clear^)
        self.autoclear_head = True

    def set_autoclear(mut self, enabled: Bool, var clear: RenderCommand):
        """Take the frame's opening clear back out, or put `clear` in as
        its first command, partway through recording.

        Off removes only the clear the frame opened with: an opaque
        `background()` that replaced it is the program's own and stays. On
        does nothing if the frame already opens with an opaque clear. Either
        change counts as a record, so a cached read is replayed.
        """
        if not enabled:
            if self.autoclear_head:
                _ = self.commands.pop(0)
                self.autoclear_head = False
                self.recorded += 1
            return
        if self.autoclear_head:
            return
        if (
            len(self.commands) > 0
            and self.commands[0].payload.isa[ClearPayload]()
            and self.commands[0].clip == 0
            and _clear_is_opaque(self.commands[0])
        ):
            return
        clear.clip = 0
        self.commands.insert(0, clear^)
        self.autoclear_head = True
        self.recorded += 1

    def request_image(mut self, var request: _ImageRequest):
        """File a design-size capture of the frame being recorded."""
        self.pending_image = Optional(request^)

    def request_screenshot(mut self, path: String):
        """File a framebuffer-resolution capture of the frame being recorded."""
        self.pending_screenshot = Optional(path)

    def _flush_screenshot[o: Origin[mut=True]](mut self, s: Surface[o]) raises:
        """Service a pending `save_screenshot` by copying the finished buffer.

        After `replay`, so the bars are in it — a screenshot is what the user
        saw, and at this point `s` already is that. Near-free: a copy of the
        frame, with no second rasterisation.
        """
        if not self.pending_screenshot:
            return
        var path = self.pending_screenshot.take()
        var mem = MemorySurface(s.width, s.height)
        unsafe_memcpy(
            dest=mem.data.unsafe_ptr(),
            src=s.px,
            count=s.width * s.height * 4,
        )
        mem.save(path)

    def _flush_screenshot_gpu(
        mut self, mut gl: GLRenderer, width: Int, height: Int
    ) raises:
        """The GPU counterpart: read the real framebuffer back off the driver.

        There is no host buffer to copy from here, so this is the one capture
        that costs a pipeline stall — see `GLRenderer.read_frame`. It runs
        after `render` and before the run loop's buffer swap, which is the only
        window in which the finished frame is still the one being read.
        """
        if not self.pending_screenshot:
            return
        var path = self.pending_screenshot.take()
        var frame = gl.read_frame(width, height)
        _force_opaque(frame)
        write_png(frame, width, height, path)

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
        if not self.pending_image:
            return
        var request = self.pending_image.take()
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

    def start_recording(mut self, var recording: _Recording) raises:
        """Make `recording` the one in progress, finishing any before it."""
        self.finish_recording()
        self.recording = Optional(recording^)

    def finish_recording(mut self) raises:
        """Write the last frame and the trailer, and close the file. Nothing
        happens without a recording in progress."""
        if not self.recording:
            return
        var recording = self.recording.take()
        recording.write_pending(recording.pending_slot + 1)
        recording.writer.finish()

    def cancel_recording(mut self) raises:
        """End the recording in progress without saving it. Nothing happens
        without one."""
        if not self.recording:
            return
        var recording = self.recording.take()
        recording.writer.cancel()

    def _record_frame(mut self, cmds: List[RenderCommand]) raises:
        """Capture the presented frame into the recording, if its slot is due.

        Replayed on the CPU onto a buffer of the recording's own size, as
        `_flush_image` captures, so both backends record the same pixels.
        """
        if not self.recording:
            return
        var recording = self.recording.take()
        if not recording.started:
            recording.started = True
            recording.start = self.clock
        # A hair of slack, so a clock landing exactly on a slot's start
        # counts as inside it despite rounding.
        var slot = Int(
            floor((self.clock - recording.start) * recording.fps + 1e-6)
        )
        if slot < recording.next_slot:
            self.recording = Optional(recording^)
            return
        if recording.max_slots and slot >= recording.max_slots.value():
            recording.write_pending(recording.max_slots.value())
            recording.writer.finish()
            return
        var mem = MemorySurface(recording.width, recording.height)
        self.replay(
            mem.surface(),
            cmds,
            recording.scale,
            pre=recording.capture_base @ self.screen_inv,
            skip_letterbox=True,
        )
        var frame = encode_frame(
            mem.data, recording.width, recording.height, recording.dither
        )
        recording.write_pending(slot)
        recording.pending = Optional(frame^)
        recording.pending_slot = slot
        recording.next_slot = slot + 1
        recording.frames += 1
        self.recording = Optional(recording^)
        if (
            self.recording.value().max_frames
            and self.recording.value().frames
            >= self.recording.value().max_frames.value()
        ):
            self.finish_recording()

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
        self.autoclear_head = False

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
        var cmds = self.commands^
        self.commands = List[RenderCommand]()
        self.replay(
            mem.surface(),
            cmds,
            scale,
            pre=to_target @ self.screen_inv,
            skip_letterbox=True,
        )
        self.commands = cmds^
        _clear_off_screen(mem, to_target, self.screen_w, self.screen_h)
        return mem^

    def read_frame(mut self, seeded: Bool) raises:
        """Bring `frame_read` up to the frame so far at design size,
        reading again only if something has been recorded since the last
        time."""
        if not self.frame_read or self.frame_read_at != self.recorded:
            self.frame_read = self.read(
                self.frame_w,
                self.frame_h,
                1.0,
                _design_pixels(self.frame_w, self.frame_h),
                seeded,
            )
            self.frame_read_at = self.recorded

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
        var cmds = self.commands^
        self.commands = List[RenderCommand]()
        self.replay(s, cmds, scale)
        self._flush_screenshot(s)
        self._flush_image(cmds)
        self._record_frame(cmds)
        if self.keep_frames:
            self._keep_frame(s)
        cmds.clear()
        self.commands = cmds^
        self.clips.clear()
        self.clip = 0
        self.frame_read = None
        _ = self.resources.expire_images()

    def discard(mut self):
        """Drop everything recorded so far, and an offscreen canvas's
        pixels with it. The clips stay while one is open, as in `bake`."""
        self.commands.clear()
        if self.clip == 0:
            self.clips.clear()
        self.autoclear_head = False
        self.recorded += 1
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
        if len(self.commands) == 0:
            return
        var cmds = self.commands^
        self.commands = List[RenderCommand]()
        var mem = self.target.take()
        self.replay(mem.surface(), cmds, scale, skip_letterbox=True)
        self.target = mem^
        cmds.clear()
        self.commands = cmds^
        if self.clip == 0:
            self.clips.clear()
        self.recorded += 1
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
        var cmds = self.commands^
        self.commands = List[RenderCommand]()
        gl.render(
            cmds,
            self.clips,
            self.resources.images,
            self.resources.text[],
            width,
            height,
            scale,
            self.antialiasing._gpu_samples(),
        )
        self._flush_screenshot_gpu(gl, width, height)
        self._flush_image(cmds)
        self._record_frame(cmds)
        cmds.clear()
        self.commands = cmds^
        self.clips.clear()
        self.clip = 0
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
            self.clips,
            self.antialiasing,
            scale,
            pre,
            skip_letterbox,
            skip_clear,
        )
