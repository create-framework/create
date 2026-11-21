"""Sectors: a pie chart whose slice under the mouse slides out, and a chewing
pac-man that `contains` and `overlaps` test exactly, its mouth outside it.

Drag the ball into the pac-man's mouth and let go as it shuts.
"""

from create import *

comptime _BACKGROUND = Color(40, 40, 44)
"""Light enough for the pac-man's shadow to show against it."""
comptime _TEXT = Color(240, 236, 222)
comptime _PACMAN_BODY = Color(250, 200, 40)
comptime _HOVERED = Color(240, 236, 222)
comptime _HIT = Color(226, 46, 56)
comptime _SHADOW = Color(0, 0, 0, 170)
comptime _BALL = Color(98, 104, 168)

comptime _PIE = Point(-260.0, -20.0)
comptime _PIE_RADIUS = 190.0
comptime _POP = 16.0
"""How far the slice under the mouse slides out, in design units."""

comptime _PACMAN = Point(240.0, -20.0)
comptime _CHEW = 4.0
"""How fast the pac-man's mouth works; it shuts every `PI / _CHEW` seconds."""

comptime _BALL_HOME = Point(500.0, -280.0)
comptime _RESPAWN = 3.0
"""Seconds an eaten ball stays gone before it is back at `_BALL_HOME`."""


def _shares() -> List[Float64]:
    """The pie chart's slices, as fractions of the whole."""
    return [0.38, 0.24, 0.17, 0.13, 0.08]


def _slice_color(i: Int) -> Color:
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
            ball=Circle(_BALL_HOME, 40),
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
        var chew = context.time.elapsed * _CHEW
        var gape = 0.4 + 0.35 * abs(sin(chew))
        var pacman = Sector(_PACMAN, 150, gape, TAU - 2.0 * gape)
        var mouth = Sector(pacman.position, pacman.radius, -gape, 2.0 * gape)

        if self.respawn_in > 0.0:
            self.respawn_in -= context.time.delta
            if self.respawn_in <= 0.0:
                self.respawn_in = 0.0
                self.ball = self.ball.move_to(_BALL_HOME)
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
                self.respawn_in = _RESPAWN

        canvas.background(_BACKGROUND)

        # A pie chart: slices laid clockwise from the top. The one under the
        # mouse slides out along the middle of its sweep.
        canvas.stroke(_BACKGROUND, thickness=3)
        var shares = _shares()
        var start = PI / 2.0
        for i in range(len(shares)):
            var slice = Sector(_PIE, _PIE_RADIUS, start, -TAU * shares[i])
            if slice.contains(mouse):
                var middle = start - PI * shares[i]
                slice = slice.translate(Vector(cos(middle), sin(middle)) * _POP)
            canvas.fill(_slice_color(i))
            canvas.draw(slice)
            start = slice.end_angle()

        var body = _PACMAN_BODY
        if pacman.contains(mouse):
            body = _HOVERED
        var hit = not eaten and pacman.overlaps(self.ball)
        with canvas.style(
            fill=body,
            stroke=_HIT if hit else _BACKGROUND,
            stroke_thickness=6,
            shadow=Shadow(_SHADOW, offset=Vector(8, -12), blur=20),
        ):
            canvas.draw(pacman)

        if self.respawn_in == 0.0:
            canvas.stroke_enabled(False)
            canvas.fill(_BALL)
            canvas.draw(self.ball)

        canvas.text_color(_TEXT)
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
