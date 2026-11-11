"""The frame being recorded: its commands, in order, and its clips.

`Canvas` appends to it through `record` and `record_clear`, opens clips
with `push_clip`, and switches the opening clear with `set_autoclear`; the
presents, reads and captures replay `commands` against `clips`. Nothing here
draws: it is the seam between recording and replay.
"""

from ._clip import _Clip
from ._command import ClearPayload, RenderCommand, _clear_is_opaque


struct CommandBuffer(Movable):
    """The commands recorded so far this frame and the clips they name."""

    var commands: List[RenderCommand]
    """The frame being recorded.

    The buffer lives here rather than travelling out of `Canvas` because a
    `Tuple` of move-only values cannot be unpacked in this Mojo version — see
    `present`, which is also where the buffer is reset. Keeping it means the
    allocation is reused frame to frame instead of being rebuilt per frame.
    """
    var clips: List[_Clip]
    """This frame's `canvas.clip` levels, in the order they were opened;
    a command's `clip` is an index into it, one past. Both replays build their
    own form of each — rows on the CPU, the stencil on the GPU — and it is
    reset with the command buffer."""
    var clip: Int
    """The clip a command recorded now is rendered under: the innermost
    open `canvas.clip`, or 0. `ClipGuard` sets it back on exit."""
    var recorded: Int
    """Records ever made, a clock for `frame_read`: a read is current while
    nothing has been recorded since. A count of commands would not do, since
    `record_clear` can replace one without adding any."""
    var autoclear_head: Bool
    """Whether the frame's first command is still the clear the frame opened
    with, so `set_autoclear` can take it back out. Cleared when a
    `background()` replaces it, which then stays."""

    def __init__(out self):
        self.commands = List[RenderCommand]()
        self.clips = List[_Clip]()
        self.clip = 0
        self.recorded = 0
        self.autoclear_head = False

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
