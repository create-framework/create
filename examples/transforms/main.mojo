"""Nested transforms: a planet orbits the sun and a moon the planet, each a
rotation inside the one before, beside two spinning clusters.

Hover the sun: `canvas.to_local` tests the mouse in the frame the sun is
drawn in.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime SUN = Color.YELLOW
comptime HOVERED_SUN = Color.RED
comptime ORBIT = COLORS.outline_variant
comptime PLANET = Color.BLUE
comptime MOON = COLORS.on_surface_variant
comptime HUB = COLORS.outline_variant
comptime COOL = Color.CYAN
comptime WARM = Color.MAGENTA


@fieldwise_init
struct Transforms(Program):
    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Transforms:
        return Transforms()

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var elapsed = context.time.elapsed

        canvas.background(BACKGROUND)

        var planet_angle = elapsed * TAU / 10
        var moon_angle = elapsed * TAU / 3.5

        # The sun sits at the origin, so it needs no transform of its own.
        # Hit-test it in the space it is drawn in: `to_local` maps a screen
        # position, which is what `context.mouse.position` is, into that space.
        var sun = Circle((0, 0), 40)
        var sun_hovered = sun.contains(canvas.to_local(context.mouse.position))

        canvas.stroke_enabled(False)
        canvas.fill(HOVERED_SUN if sun_hovered else SUN)
        canvas.draw(sun)

        # The planet: turn, then move out along the turned x axis, so it
        # orbits the sun.
        with canvas.transform():
            canvas.rotate(planet_angle)
            canvas.translate(Vector(160, 0))

            # The moon's orbit, drawn in the planet's space.
            canvas.stroke(ORBIT, thickness=1)
            canvas.fill_enabled(False)
            canvas.circle((0, 0), 45)

            canvas.stroke_enabled(False)
            canvas.fill(PLANET)
            canvas.circle((0, 0), 18)

            # The moon orbits the planet.
            with canvas.transform():
                canvas.rotate(moon_angle)
                canvas.translate(Vector(45, 0))
                canvas.fill(MOON)
                canvas.circle((0, 0), 8)

        # Spinning rectangles: the same nesting, with another shape.
        # Below and left of centre, so both coordinates are negative.
        with canvas.transform(Transform(translation=Vector(-232, -165))):
            canvas.stroke_enabled(False)
            canvas.fill(HUB)
            canvas.circle((0, 0), 8)

            for i in range(6):
                var arm_angle = elapsed * 0.9 + Float64(i) * TAU / 6

                # The arm turns, then the rectangle turns back, so it stays
                # level on the screen.
                with canvas.transform():
                    canvas.rotate(arm_angle)
                    canvas.translate(Vector(70, 0))
                    canvas.rotate(-arm_angle)

                    var t = (sin(elapsed * 2 + Float64(i)) + 1) / 2
                    canvas.fill(COOL.lerp(WARM, t))
                    canvas.rectangle((0, 0), 36, 18)

        # A turning fan of triangles.
        with canvas.transform(Transform(translation=Vector(232, -165))):
            for i in range(5):
                var a = elapsed * 0.6 + Float64(i) * TAU / 5
                with canvas.transform():
                    canvas.rotate(a)
                    canvas.stroke_enabled(False)
                    canvas.fill(COOL.lerp(WARM, Float64(i) / 4))
                    canvas.triangle((0, 0), (60, 15), (60, -15))


def main() raises:
    run[Transforms]("Transforms", width=800, height=600)
