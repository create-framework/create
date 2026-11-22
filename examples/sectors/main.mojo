"""Sectors: a pie chart whose slice under the mouse slides out, and a chewing
pac-man that `contains` and `overlaps` test exactly, its mouth outside it.

Drag the ball into the pac-man's mouth and let go as it shuts.
"""

from create import *

comptime BACKGROUND = Color(40, 40, 44)
"""Light enough for the pac-man's shadow to show against it."""
comptime TEXT = Color(240, 236, 222)
comptime PACMAN_BODY = Color(250, 200, 40)
comptime HOVERED = Color(240, 236, 222)
comptime HIT = Color(226, 46, 56)
comptime SHADOW = Color(0, 0, 0, 170)
comptime BALL = Color(98, 104, 168)

comptime PIE = Point(-260.0, -20.0)
comptime PIE_RADIUS = 190.0
comptime POP = 16.0
"""How far the slice under the mouse slides out, in design units."""

comptime PACMAN = Point(240.0, -20.0)
comptime CHEW = 4.0
"""How fast the pac-man's mouth works; it shuts every `PI / CHEW` seconds."""

comptime BALL_HOME = Point(500.0, -280.0)
comptime RESPAWN = 3.0
"""Seconds an eaten ball stays gone before it is back at `BALL_HOME`."""


def shares() -> List[Float64]:
    """The pie chart's slices, as fractions of the whole."""
    return [0.38, 0.24, 0.17, 0.13, 0.08]


def slice_color(i: Int) -> Color:
    var colors: List[Color] = [
        Color(98, 104, 168),
        Color(201, 140, 150),
        Color(150, 154, 206),
        Color(240, 236, 222),
        Color(226, 46, 56),
    ]
    return colors[i % len(colors)]


@fieldwise_init
struct App(Program):
    var ball: Circle
    """Dragged over the pac-man to test the overlap."""

    var respawn_in: Float64
    """Seconds until the eaten ball comes back; 0 while it is out."""

    var dragging: Bool

    var bites: Int
    """How many times the mouth has shut."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(
            ball=Circle(BALL_HOME, 40),
            respawn_in=0.0,
            dragging=False,
            bites=0,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # No camera, so the mouse is already in the space the shapes are in.
        var mouse = context.mouse.position

        # A pac-man wider than a half turn: its mouth is the missing wedge,
        # outside it, so the mouse there touches nothing. The mouth is a
        # sector of its own, the rest of the turn.
        var chew = context.time.elapsed * CHEW
        var gape = 0.4 + 0.35 * abs(sin(chew))
        var pacman = Sector(PACMAN, 150, gape, TAU - 2.0 * gape)
        var mouth = Sector(pacman.position, pacman.radius, -gape, 2.0 * gape)

        if self.respawn_in > 0.0:
            self.respawn_in -= context.time.delta
            if self.respawn_in <= 0.0:
                self.respawn_in = 0.0
                self.ball = self.ball.move_to(BALL_HOME)
        var eaten = self.respawn_in > 0.0

        if not eaten:
            if context.mouse.pressed() and self.ball.contains(mouse):
                self.dragging = True
            if context.mouse.released():
                self.dragging = False
            if self.dragging:
                self.ball = self.ball.move_to(mouse)

        # The mouth is most shut where the sine crosses zero, once per bite:
        # a ball let go in it then is swallowed; one still held is safe.
        var bites = Int(chew / PI)
        if bites != self.bites:
            self.bites = bites
            if (
                not eaten
                and not self.dragging
                and mouth.contains(self.ball.center())
            ):
                self.respawn_in = RESPAWN

        canvas.background(BACKGROUND)

        # A pie chart: slices laid clockwise from the top. The one under the
        # mouse slides out along the middle of its sweep.
        canvas.stroke(BACKGROUND, thickness=3)
        var all_shares = shares()
        var start = PI / 2.0
        for i in range(len(all_shares)):
            var slice = Sector(PIE, PIE_RADIUS, start, -TAU * all_shares[i])
            if slice.contains(mouse):
                var middle = start - PI * all_shares[i]
                slice = slice.translate(Vector(cos(middle), sin(middle)) * POP)
            canvas.fill(slice_color(i))
            canvas.draw(slice)
            start = slice.end_angle()

        var body = PACMAN_BODY
        if pacman.contains(mouse):
            body = HOVERED
        var hit = not eaten and pacman.overlaps(self.ball)
        with canvas.style(
            fill=body,
            stroke=HIT if hit else BACKGROUND,
            stroke_thickness=6,
            shadow=SHADOW,
            shadow_offset=Vector(8, -12),
            shadow_blur=20,
        ):
            canvas.draw(pacman)

        if self.respawn_in == 0.0:
            canvas.stroke_enabled(False)
            canvas.fill(BALL)
            canvas.draw(self.ball)

        canvas.text_color(TEXT)
        canvas.font_size(30)
        canvas.text_alignment(Align.TOP)
        canvas.text("Sectors", (0, canvas.top() - 38))
        canvas.font_size(18)
        canvas.text(
            "Hover the pie and the pac-man; feed it the ball",
            (0, canvas.top() - 78),
        )


def main() raises:
    run[App]("Sectors", width=1280, height=800)
