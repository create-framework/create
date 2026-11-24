from create import *


struct Player(Copyable, Drawable, Movable):
    """A body with a round head that runs, jumps and double-jumps under
    gravity, and lands on whichever platform it falls onto.

    Two allowances make the jump feel fair. Coyote time keeps the jump from
    the ground for a moment after walking off a ledge, and the jump buffer
    keeps a press of W made just before landing, to jump as the player
    lands.

    `Drawable`, so the game draws it with `canvas.draw(player)`, in the
    game's style.
    """

    # All rates are per second, integrated with context.time.delta so the feel
    # is the same at any frame rate. y grows upward, so gravity is negative and
    # a jump is positive.
    comptime WIDTH = 40.0
    comptime HEIGHT = 100.0
    comptime SPEED = 550.0  # units/s
    comptime GRAVITY = -5000.0  # units/s^2
    comptime JUMP_SPEED = 1250.0  # units/s
    comptime JUMP_HOLD = 1500.0  # units/s^2, against gravity while W is held
    comptime JUMPS = 2  # one from the ground, one in the air
    comptime COYOTE_TIME = 0.15  # s after leaving a ledge, the ground jump works
    comptime JUMP_BUFFER = 0.15  # s before landing, a press of W still counts
    comptime HEAD_RADIUS = 18.0
    comptime NECK = 5.0  # the gap between the head and the body

    var position: Point
    """The middle of the player, head included, as every shape is placed."""
    var velocity: Vector
    var jumps_left: Int
    var coyote: Float64
    """How much longer the ground jump lasts in the air, counting down."""
    var jump_buffer: Float64
    """How much longer the last press of W waits to jump, counting down."""

    def __init__(out self, position: Point):
        self.position = position
        self.velocity = Vector.ZERO
        self.jumps_left = Self.JUMPS
        self.coyote = Self.COYOTE_TIME
        self.jump_buffer = 0.0

    def feet(self) -> Float64:
        return self.position.y - Self.HEIGHT / 2.0

    def body(self) -> Rectangle:
        """The body, below the head, standing on the feet."""
        var height = Self.HEIGHT - 2.0 * Self.HEAD_RADIUS - Self.NECK
        return Rectangle(
            (self.position.x, self.feet() + height / 2.0),
            Self.WIDTH,
            height,
            corner_radius=10,
        )

    def head(self) -> Circle:
        var top = self.position.y + Self.HEIGHT / 2.0
        return Circle(
            (self.position.x, top - Self.HEAD_RADIUS), Self.HEAD_RADIUS
        )

    def update(mut self, context: Context, platforms: List[Rectangle]):
        var dt = context.time.delta

        var run = 0.0
        if context.keyboard.down(Key.A):
            run -= Self.SPEED
        if context.keyboard.down(Key.D):
            run += Self.SPEED

        # A press of W waits up to JUMP_BUFFER for a jump to be left, so
        # pressing it just before landing jumps as the player lands.
        self.jump_buffer = max(self.jump_buffer - dt, 0.0)
        if context.keyboard.pressed(Key.W):
            self.jump_buffer = Self.JUMP_BUFFER
        var rise = self.velocity.y
        if self.jump_buffer > 0 and self.jumps_left > 0:
            rise = Self.JUMP_SPEED
            self.jumps_left -= 1
            self.jump_buffer = 0.0
        var gravity = Self.GRAVITY
        if context.keyboard.down(Key.W) and rise > 0:
            gravity += Self.JUMP_HOLD
        self.velocity = Vector(run, rise + gravity * dt)

        var feet_before = self.feet()
        self.position = self.position + self.velocity * dt

        # Platforms are one-way, as in most platformers: jumped through from
        # below, landed on from above.
        if self.velocity.y <= 0 and self.land(feet_before, platforms):
            return
        # In the air. Once coyote time runs out, the jump from the ground is
        # gone, and only the double jump is left: after walking off a ledge,
        # W still jumps from the ground for a moment.
        self.coyote -= dt
        if self.coyote <= 0:
            self.jumps_left = min(self.jumps_left, Self.JUMPS - 1)

    def land(
        mut self, feet_before: Float64, platforms: List[Rectangle]
    ) -> Bool:
        """Stand on the platform whose top the feet crossed this frame, if
        any. Tested as a crossing, so a fast fall can't skip one."""
        for platform in platforms:
            var top = platform.position.y + platform.height / 2.0
            var reach = (platform.width + Self.WIDTH) / 2.0
            if (
                feet_before >= top
                and self.feet() <= top
                and abs(self.position.x - platform.position.x) < reach
            ):
                self.position = Point(self.position.x, top + Self.HEIGHT / 2.0)
                self.velocity = Vector(self.velocity.x, 0.0)
                self.jumps_left = Self.JUMPS
                self.coyote = Self.COYOTE_TIME
                return True
        return False

    def draw_to[T: DrawTarget](self, mut target: T):
        target.draw(self.body())
        target.draw(self.head())
