"""Saving the frame, three ways: a screenshot, an image and a recording.

    S          screenshot: what the window shows, at its own pixel size,
               letterbox bars and all
    I          image: what the program drew, at the 800x500 design
               resolution, no bars, identical on every machine
    Shift+I    the same image at 2x, with a transparent background
    R          start or stop recording an animated GIF of what the program
               draws, as the image is drawn, for up to ten seconds
    Shift+R    the same recording, with a transparent background
    X          throw the recording in progress away, keeping any file
               saved before

While Shift is held, the background turns black, the colour of the
letterbox bars, to mark what a transparent capture leaves out.

Resize the window and press S and I to see the difference: the screenshot
follows the window, the image never does. Under `RenderBackend.GPU` the
image and the recording come out byte-identical, because they are
rasterised on the CPU from the frame's recorded commands rather than read
back off the driver. Everything is written to the `out` folder beside this
file.
"""

from std.os import makedirs

from create import *

comptime DESIGN_W = 800
comptime DESIGN_H = 500
comptime RECORD_SECONDS = 10.0

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime TRANSPARENT_BACKGROUND = Color.BLACK
"""The background while Shift is held, matching the letterbox bars."""
comptime RECORDING = Color.RED
comptime TURN_SPEED = 0.6
"""How fast the circles turn, in radians per second."""


def circle_colors() -> List[Color]:
    return [Color.RED, Color.GREEN, Color.BLUE]


@fieldwise_init
struct Capture(Program):
    var angle: Float64
    var saved: String

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Capture:
        # Saving into a folder that isn't there fails, so make it first.
        makedirs(source_path("out"), exist_ok=True)
        return Capture(0.0, "")

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.angle += TURN_SPEED * context.time.delta

        var transparent = context.keyboard.down(Key.SHIFT)

        # Filed the moment the key is read, and written at `present`: the
        # file holds the whole frame however early in `update` it was asked
        # for, so nothing has to be rendered before asking.
        if context.keyboard.pressed(Key.S):
            canvas.save_screenshot("out/screenshot.png")
            self.saved = "screenshot.png: the window, bars included"
        elif context.keyboard.pressed(Key.I):
            if transparent:
                canvas.save_image("out/image@2x.png", 2.0, transparent=True)
                self.saved = "image@2x.png: 1600x1000, transparent"
            else:
                canvas.save_image("out/image.png")
                self.saved = "image.png: 800x500, no bars"
        elif context.keyboard.pressed(Key.R):
            # Recording runs on by itself, frame after frame, until its
            # limit or a stop; the file is complete once it ends.
            if canvas.recording():
                canvas.stop_recording()
                self.saved = "recording.gif"
            else:
                canvas.start_recording(
                    "out/recording.gif",
                    seconds=RECORD_SECONDS,
                    transparent=transparent,
                )
                self.saved = ""
        elif context.keyboard.pressed(Key.X) and canvas.recording():
            canvas.cancel_recording()
            self.saved = ""

        # A transparent capture leaves the background out whatever its
        # colour; the window turns it black only to show that it will.
        canvas.background(TRANSPARENT_BACKGROUND if transparent else BACKGROUND)

        # Three circles turning about the centre, with gaps between them
        # where a transparent capture shows through.
        var colors = circle_colors()
        with canvas.style(stroke_enabled=False):
            for i in range(len(colors)):
                var turn = self.angle + Float64(i) * TAU / 3.0
                canvas.fill(colors[i])
                canvas.circle(Point(0, 0) + Vector.from_angle(turn, 80), 60)

        with canvas.style(
            text_color=TEXT,
            font_size=24,
            text_alignment=Align.TOP,
        ):
            canvas.text(
                "S: screenshot   I: image   R: record   Shift: transparent",
                (0, canvas.top() - 30),
            )

        with canvas.style(text_color=TEXT, font_size=20):
            if canvas.recording():
                var label = String("Recording; R to stop, X to discard")
                # Drawn like everything else, so it is in the recording too.
                var dot = -canvas.text_width(label) / 2.0 - 16.0
                with canvas.style(fill=RECORDING, stroke_enabled=False):
                    canvas.circle((dot, canvas.bottom() + 50), 8)
                canvas.text(label, (0, canvas.bottom() + 50))
            elif self.saved:
                canvas.text("Wrote " + self.saved, (0, canvas.bottom() + 50))


def main() raises:
    run[Capture]("Capture", width=DESIGN_W, height=DESIGN_H)
