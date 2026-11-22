"""Playing sounds: a one-shot chime, and a looping ambience to pause, resume
and turn up or down.

Each `play` or `loop` returns a `Playback`, the handle that one playing of a
sound is controlled by; the `Audio` itself holds the overall volume, which
scales every playback's own.

Space plays the chime. L starts or stops the ambience, P pauses and resumes
it, Up and Down set its volume, Left and Right the overall volume.
"""

from create import *

comptime BACKGROUND = Color(40, 40, 44)
comptime TRACK = Color(62, 62, 68)
comptime LEVEL = Color(98, 104, 168)
comptime CHIME = Color(226, 46, 56)
comptime TEXT = Color(240, 236, 222)
comptime HINT = Color(176, 172, 162)
comptime BAR_WIDTH = 360.0
comptime VOLUME_STEP = 0.6
"""How far a held arrow key turns a volume, per second."""


def volume_bar(mut canvas: Canvas, label: String, level: Float64, y: Float64):
    """A labelled bar, filled to `level` of its width."""
    var left = -BAR_WIDTH / 2.0
    with canvas.style(stroke_enabled=False):
        canvas.fill(TRACK)
        canvas.rectangle((0.0, y), BAR_WIDTH, 14.0, corner_radius=7)
        if level > 0.0:
            canvas.fill(LEVEL)
            var w = BAR_WIDTH * level
            canvas.rectangle((left + w / 2.0, y), w, 14.0, corner_radius=7)
    with canvas.style(
        text_color=TEXT, font_size=18, text_alignment=Align.RIGHT
    ):
        canvas.text(label, (left - 20.0, y))
    with canvas.style(text_color=TEXT, font_size=18, text_alignment=Align.LEFT):
        canvas.text(String(Int(level * 100.0 + 0.5), "%"), (-left + 20.0, y))


@fieldwise_init
struct AudioDemo(Program):
    var audio: Audio
    var chime: Sound
    var ambience: Sound
    var ambience_playback: Playback
    """The looping ambience, or `Playback.NONE` while it is stopped."""
    var ambience_volume: Float64
    """Kept here as well as on the playback, so a restarted loop keeps it."""
    var chimed_at: Float64
    """When the chime last played, to flash the circle."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> AudioDemo:
        return AudioDemo(
            audio=Audio(),
            chime=Sound.load("assets/chime.wav"),
            ambience=Sound.load("assets/ambience.wav"),
            ambience_playback=Playback.NONE,
            ambience_volume=0.8,
            chimed_at=-10.0,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var step = VOLUME_STEP * context.time.delta

        if context.keyboard.pressed(Key.SPACE):
            _ = self.audio.play(self.chime)
            self.chimed_at = context.time.elapsed

        if context.keyboard.pressed(Key.L):
            if self.ambience_playback == Playback.NONE:
                self.ambience_playback = self.audio.loop(
                    self.ambience, volume=self.ambience_volume
                )
            else:
                self.audio.stop(self.ambience_playback)
                self.ambience_playback = Playback.NONE
        if (
            context.keyboard.pressed(Key.P)
            and self.ambience_playback != Playback.NONE
        ):
            if self.audio.is_paused(self.ambience_playback):
                self.audio.resume(self.ambience_playback)
            else:
                self.audio.pause(self.ambience_playback)

        if context.keyboard.down(Key.UP) or context.keyboard.down(Key.DOWN):
            var change = step if context.keyboard.down(Key.UP) else -step
            self.ambience_volume = clamp(
                self.ambience_volume + change, 0.0, 1.0
            )
            self.audio.volume(self.ambience_playback, self.ambience_volume)
        if context.keyboard.down(Key.RIGHT):
            self.audio.volume(clamp(self.audio.volume() + step, 0.0, 1.0))
        if context.keyboard.down(Key.LEFT):
            self.audio.volume(clamp(self.audio.volume() - step, 0.0, 1.0))

        canvas.background(BACKGROUND)

        # The chime's flash, fading over half a second.
        var since = context.time.elapsed - self.chimed_at
        var flash = clamp(1.0 - since / 0.5, 0.0, 1.0)
        with canvas.style(fill=TRACK.lerp(CHIME, flash), stroke_enabled=False):
            canvas.circle((-250.0, 40.0), 40.0 + 12.0 * flash)
        with canvas.style(text_color=HINT, font_size=18):
            canvas.text("Space: chime", (-250.0, -30.0))

        var state: String
        if self.audio.is_playing(self.ambience_playback):
            state = "playing"
        elif self.audio.is_paused(self.ambience_playback):
            state = "paused"
        else:
            state = "stopped"
        with canvas.style(text_color=TEXT, font_size=26):
            canvas.text("Ambience " + state, (120.0, 60.0))
        with canvas.style(text_color=HINT, font_size=18):
            canvas.text("L: start/stop   P: pause/resume", (120.0, 20.0))

        volume_bar(canvas, "Ambience", self.ambience_volume, -90.0)
        volume_bar(canvas, "Overall", self.audio.volume(), -140.0)
        with canvas.style(text_color=HINT, font_size=18):
            canvas.text(
                "Up/Down: ambience volume   Left/Right: overall volume",
                (0.0, -200.0),
            )

        with canvas.style(
            text_color=TEXT, font_size=30, text_alignment=Align.TOP
        ):
            canvas.text("Audio", (0, canvas.top() - 20.0))


def main() raises:
    run[AudioDemo]("Audio", width=800, height=500)
