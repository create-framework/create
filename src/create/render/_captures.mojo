"""The captures a canvas files while it records, serviced when the frame
is presented: `save_image`, `save_screenshot` and `start_recording`.

Present is the only place holding both the finished frame and its unconsumed
commands, so a capture is a request until then. `Captures` keeps the
requests and the recording's state — its GIF writer and its timing, the
run's clock cut into `1 / fps` slots — and `Backend` does the part that
needs a replay: it replays the commands for a `save_image` or a recording's
frame on the CPU, then hands the pixels back here.
"""

from std.math import floor

from create.math.matrix import Matrix

from ._gif import GifWriter, encode_frame
from ._gl_backend import GLRenderer
from ._png import write_png
from ._surface import MemorySurface, Surface, _force_opaque
from std.memory import unsafe_memcpy


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


struct Captures(Movable):
    """The capture requests filed this frame and the recording in progress."""

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

    def __init__(out self):
        self.recording = None
        self.clock = 0.0
        self.pending_screenshot = Optional[String]()
        self.pending_image = Optional[_ImageRequest]()

    def request_image(mut self, var request: _ImageRequest):
        """File a design-size capture of the frame being recorded."""
        self.pending_image = Optional(request^)

    def request_screenshot(mut self, path: String):
        """File a framebuffer-resolution capture of the frame being recorded."""
        self.pending_screenshot = Optional(path)

    def flush_screenshot[o: Origin[mut=True]](mut self, s: Surface[o]) raises:
        """Service a pending `save_screenshot` by copying the finished buffer.

        After the replay, so the bars are in it — a screenshot is what the user
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

    def flush_screenshot_gpu(
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

    def frame_due(mut self) raises -> Optional[Int]:
        """The slot the presented frame should be captured in, or `None`
        when there is no recording or its next slot has not begun. Starts
        the recording's clock at its first present, and finishes it once
        its `seconds` are up instead of asking for a frame."""
        if not self.recording:
            return None
        ref recording = self.recording.value()
        if not recording.started:
            recording.started = True
            recording.start = self.clock
        # A hair of slack, so a clock landing exactly on a slot's start
        # counts as inside it despite rounding.
        var slot = Int(
            floor((self.clock - recording.start) * recording.fps + 1e-6)
        )
        if slot < recording.next_slot:
            return None
        if recording.max_slots and slot >= recording.max_slots.value():
            var done = self.recording.take()
            done.write_pending(done.max_slots.value())
            done.writer.finish()
            return None
        return slot

    def add_frame(mut self, mem: MemorySurface, slot: Int) raises:
        """Encode `mem`, the frame `frame_due` asked for, as the frame of
        `slot`: the one before it is written now that its length is known,
        and the recording finishes once it has its `frames`."""
        ref recording = self.recording.value()
        var frame = encode_frame(
            mem.data, recording.width, recording.height, recording.dither
        )
        recording.write_pending(slot)
        recording.pending = Optional(frame^)
        recording.pending_slot = slot
        recording.next_slot = slot + 1
        recording.frames += 1
        if (
            recording.max_frames
            and recording.frames >= recording.max_frames.value()
        ):
            self.finish_recording()
