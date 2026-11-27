"""A platformer: a player that runs and double-jumps under gravity across
platforms, and a camera that follows it through a world wider than the
screen.

A and D move, W jumps (again in the air); hold W to jump higher. W still
jumps for 150 ms after running off a ledge (coyote time), and a press of W
up to 150 ms before landing jumps on landing (jump buffering).
"""

from create import *

from player import Player

# The level, in world units. y is up, so the ground's top is below the middle
# of the screen, and a platform higher up has a larger y.
comptime WORLD_LEFT = -2400.0
comptime WORLD_RIGHT = 2400.0
comptime GROUND_TOP = -240.0
comptime PLATFORM_THICKNESS = 24.0
comptime CAMERA_LEAD = 150.0
"""How far above the camera's centre the player climbs before it follows."""

comptime COLORS = ColorScheme.dark()
comptime SKY = COLORS.background
comptime GROUND = COLORS.surface_container
comptime PLATFORM = Color.BLUE
comptime WALL = COLORS.outline_variant
comptime PLAYER = Color.RED
comptime HINT = COLORS.on_surface_variant


def platforms() -> List[Rectangle]:
    """The ground, then the platforms, left to right. Every shape is placed
    by its middle, so each top is half a thickness above its position."""
    var ground_depth = 1000.0
    var level: List[Rectangle] = [
        Rectangle(
            (0.0, GROUND_TOP - ground_depth / 2.0),
            WORLD_RIGHT - WORLD_LEFT,
            ground_depth,
        )
    ]

    # (middle x, top, width): each top within a jump of the one before.
    var layout: List[Tuple[Float64, Float64, Float64]] = [
        (-1900.0, -110.0, 220.0),
        (-1550.0, 30.0, 200.0),
        (-1150.0, -60.0, 260.0),
        (-700.0, 60.0, 200.0),
        (-300.0, -110.0, 240.0),
        (100.0, 20.0, 200.0),
        (450.0, 160.0, 180.0),
        (850.0, 20.0, 220.0),
        (1250.0, -100.0, 260.0),
        (1650.0, 40.0, 200.0),
        (2000.0, 180.0, 180.0),
    ]

    for platform in layout:
        level.append(
            Rectangle(
                (platform[0], platform[1] - PLATFORM_THICKNESS / 2.0),
                platform[2],
                PLATFORM_THICKNESS,
                corner_radius=6,
            )
        )

    return level^


@fieldwise_init
struct Game(Program):
    var player: Player
    var platforms: List[Rectangle]
    """The ground first, then the platforms."""
    var camera: Camera

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Game:
        return Game(
            player=Player(Point(0.0, GROUND_TOP + Player.HEIGHT / 2.0)),
            platforms=platforms(),
            camera=Camera(),
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.player.update(context, self.platforms)

        # The world's edges are the game's to enforce, not the player's.
        var half_w = Player.WIDTH / 2.0
        var position = self.player.position
        self.player.position = Point(
            clamp(position.x, WORLD_LEFT + half_w, WORLD_RIGHT - half_w),
            position.y,
        )

        # Follow the player sideways, and upwards only once it climbs past
        # the lead, so a jump from the ground leaves the view still.
        self.camera.position = Point(
            self.player.position.x,
            max(0.0, self.player.position.y - CAMERA_LEAD),
        )

        canvas.background(SKY)
        canvas.camera(self.camera)

        with canvas.style(stroke_enabled=False):
            canvas.fill(GROUND)
            canvas.draw(self.platforms[0])

            canvas.fill(PLATFORM)
            for i in range(1, len(self.platforms)):
                canvas.draw(self.platforms[i])

            # Walls past either edge, wide enough to fill the view there.
            canvas.fill(WALL)
            canvas.rectangle((WORLD_LEFT - 500.0, 0.0), 1000.0, 4000.0)
            canvas.rectangle((WORLD_RIGHT + 500.0, 0.0), 1000.0, 4000.0)

            canvas.fill(PLAYER)
            canvas.draw(self.player)

        with canvas.overlay():
            with canvas.style(
                text_color=HINT, font_size=20, text_alignment=Align.TOP_LEFT
            ):
                canvas.text(
                    "W: Jump \nA: Left\nD: Right",
                    (canvas.left() + 20.0, canvas.top() - 20.0),
                )


def main() raises:
    run[Game]("Platformer")
