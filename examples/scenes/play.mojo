from create import *
from scene import Scene

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime DOT = Color.YELLOW
comptime PADDLE = Color.CYAN

comptime ROUND_LENGTH = 20.0  # seconds
comptime SPAWN_INTERVAL = 0.4  # seconds between dots
comptime FALL_SPEED = 320.0  # units a second
comptime DOT_RADIUS = 12.0
comptime PADDLE_WIDTH = 140.0
comptime PADDLE_HEIGHT = 18.0


struct Play(Movable):
    """The game: dots fall, and the paddle under the mouse catches them
    until the round's time runs out.

    `update` moves the game on and draws it; `draw` only draws it, so the
    pause scene can show the game, frozen, under its menu.
    """

    var score: Int
    var time_left: Float64
    var until_spawn: Float64
    var dots: List[Point]
    var paddle: Rectangle
    var random: Random

    def __init__(out self):
        self.score = 0
        self.time_left = ROUND_LENGTH
        self.until_spawn = 0
        self.dots = []
        self.paddle = Rectangle((0, 0), PADDLE_WIDTH, PADDLE_HEIGHT)
        self.random = Random()

    def enter(mut self):
        """Start a new round. `App` calls it when play starts from the title
        or the game-over scene, but not when it resumes from the pause."""
        self.score = 0
        self.time_left = ROUND_LENGTH
        self.until_spawn = 0
        self.dots.clear()

    def update(mut self, context: Context, mut canvas: Canvas) raises -> Scene:
        var delta = context.time.delta
        self.time_left -= delta

        # The paddle follows the mouse along the bottom, kept on screen.
        var half = PADDLE_WIDTH / 2
        var x = clamp(
            context.mouse.position.x,
            canvas.left() + half,
            canvas.right() - half,
        )
        self.paddle = self.paddle.move_to((x, canvas.bottom() + 50))

        # Drop a new dot from the top every SPAWN_INTERVAL seconds.
        self.until_spawn -= delta
        if self.until_spawn <= 0:
            self.until_spawn += SPAWN_INTERVAL
            var margin = DOT_RADIUS * 2
            self.dots.append(
                Point(
                    self.random.float(
                        canvas.left() + margin, canvas.right() - margin
                    ),
                    canvas.top() + DOT_RADIUS,
                )
            )

        # Keep the dots still falling: not caught, and not off the bottom.
        var falling = List[Point]()
        for dot in self.dots:
            var moved = dot + Vector.DOWN * FALL_SPEED * delta
            if Circle(moved, DOT_RADIUS).overlaps(self.paddle):
                self.score += 1
            elif moved.y > canvas.bottom() - DOT_RADIUS:
                falling.append(moved)
        self.dots = falling^

        self.draw(canvas)

        if self.time_left <= 0:
            return Scene.OVER
        if context.keyboard.pressed(Key.ESCAPE):
            return Scene.PAUSE
        return Scene.PLAY

    def draw(self, mut canvas: Canvas):
        canvas.background(BACKGROUND)

        with canvas.style(fill=DOT, stroke_enabled=False):
            for dot in self.dots:
                canvas.circle(dot, DOT_RADIUS)

        with canvas.style(fill=PADDLE, stroke_enabled=False, corner_radius=9):
            canvas.draw(self.paddle)

        with canvas.style(
            text_color=TEXT, font_size=24, text_alignment=Align.TOP_LEFT
        ):
            canvas.text(
                "Score: " + String(self.score),
                (canvas.left() + 20, canvas.top() - 20),
            )

        with canvas.style(
            text_color=TEXT, font_size=24, text_alignment=Align.TOP_RIGHT
        ):
            canvas.text(
                String(Int(ceil(max(self.time_left, 0.0)))) + " s",
                (canvas.right() - 20, canvas.top() - 20),
            )
