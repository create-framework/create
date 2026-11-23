"""A `Camera` over a world wider than the screen, and a label in
`canvas.overlay()` that stays put whatever the camera does.

The mouse is in screen space; `camera.to_world` says where it is in the
world. Zooming keeps the world point under the cursor where it is, and a
click drops a marker there, which then stays put in the world.

Left and Right pan, the mouse wheel zooms, a click drops a marker, C clears
them.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime MARKER = Color.YELLOW
comptime TEXT = COLORS.on_surface
comptime ORIGIN = COLORS.on_surface
comptime PAN_SPEED = 300.0
"""Screen units per second, so a pan feels the same at any zoom."""
comptime ZOOM_STEP = 1.15
"""How much one notch of the wheel zooms in or out."""


def post_color(i: Int) -> Color:
    var colors: List[Color] = [Color.RED, Color.GREEN, Color.BLUE]
    return colors[i % len(colors)]


@fieldwise_init
struct CameraDemo(Program):
    var camera: Camera
    var markers: List[Point]
    """Where the clicks landed, in world space."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> CameraDemo:
        return CameraDemo(Camera(), [])

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var pan = PAN_SPEED * context.time.delta / self.camera.zoom
        if context.keyboard.down(Key.RIGHT):
            self.camera.position += Vector(pan, 0.0)
        if context.keyboard.down(Key.LEFT):
            self.camera.position -= Vector(pan, 0.0)

        # Zoom about the cursor: note the world point under it, zoom, then
        # move the camera so that point is back under the cursor.
        if context.mouse.wheel.y != 0.0:
            var before = self.camera.to_world(context.mouse.position)
            self.camera.zoom = clamp(
                self.camera.zoom * pow(ZOOM_STEP, context.mouse.wheel.y),
                0.3,
                4.0,
            )
            self.camera.position += before - self.camera.to_world(
                context.mouse.position
            )

        if context.mouse.pressed():
            self.markers.append(self.camera.to_world(context.mouse.position))
        if context.keyboard.pressed(Key.C):
            self.markers.clear()

        canvas.background(BACKGROUND)
        canvas.camera(self.camera)

        # World content: a strip of posts stretching far past what any single
        # screen shows, and a marker at the world origin.
        canvas.stroke_enabled(False)
        for i in range(-20, 20):
            var x = Float64(i) * 120.0
            canvas.fill(post_color(i))
            canvas.rectangle((x, 0.0), 40.0, 200.0)

        canvas.fill(ORIGIN)
        canvas.circle((0.0, 140.0), 14.0)

        # In world units, so a marker grows and shrinks with the zoom.
        with canvas.style(fill=MARKER, stroke=TEXT, stroke_thickness=2):
            for marker in self.markers:
                canvas.circle(marker, 10.0)

        # HUD: fixed to the screen regardless of where the camera looks or
        # how far it has zoomed.
        with canvas.overlay():
            with canvas.style(
                text_color=TEXT, font_size=18, text_alignment=Align.TOP
            ):
                canvas.text(
                    "Left/Right pan, the wheel zooms, a click drops a marker, C"
                    + " clears",
                    (0.0, canvas.top() - 16.0),
                )
                var world = self.camera.to_world(context.mouse.position)
                canvas.text(
                    String(
                        "Zoom ",
                        round(self.camera.zoom, 2),
                        "x   Mouse in the world: (",
                        Int(world.x),
                        ", ",
                        Int(world.y),
                        ")",
                    ),
                    (0.0, canvas.top() - 44.0),
                )


def main() raises:
    run[CameraDemo]("Camera", width=800, height=600)
