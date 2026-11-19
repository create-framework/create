"""Nested transforms: a planet orbits the sun and a moon the planet, each a
rotation inside the one before, beside two spinning clusters.

Hover the sun: `canvas.to_local` tests the mouse in the frame the sun is
drawn in.
"""

from create import *

comptime _BACKGROUND = Color(40, 40, 44)
comptime _SUN = Color(230, 180, 20)
comptime _HOVERED_SUN = Color(226, 46, 56)
comptime _ORBIT = Color(62, 62, 68)
comptime _PLANET = Color(98, 104, 168)
comptime _MOON = Color(176, 172, 162)
comptime _HUB = Color(62, 62, 68)
comptime _COOL = Color(98, 104, 168)
comptime _WARM = Color(201, 140, 150)


@fieldwise_init
struct Transforms(Program):
    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Transforms:
        return Transforms()

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var elapsed = context.time.elapsed

        canvas.background(_BACKGROUND)

        var planet_angle = elapsed * TAU / 10.0
        var moon_angle = elapsed * TAU / 3.5

        # Solar system: the sun sits at the origin, so it needs no transform of
        # its own; the nesting below is what the demo is about.
        # Hit-test the sun in the frame it is rendered in. `to_local` maps a
        # screen position, which is what `context.mouse.position` is, into it.
        var sun = Circle((0.0, 0.0), 40.0)
        var sun_hovered = sun.contains(canvas.to_local(context.mouse.position))

        canvas.stroke_enabled(False)
        canvas.fill(_HOVERED_SUN if sun_hovered else _SUN)
        canvas.draw(sun)

        # Planet: rotate then translate so it orbits the sun
        with canvas.transform(rotate(planet_angle) @ translate(160.0, 0.0)):
            # Thin orbit guide rendered in planet's frame before further nesting
            canvas.stroke(_ORBIT, thickness=1)
            canvas.fill_enabled(False)
            canvas.circle((0.0, 0.0), 45.0)

            canvas.stroke_enabled(False)
            canvas.fill(_PLANET)
            canvas.circle((0.0, 0.0), 18.0)

            # Moon: orbits the planet
            with canvas.transform(rotate(moon_angle) @ translate(45.0, 0.0)):
                canvas.fill(_MOON)
                canvas.circle((0.0, 0.0), 8.0)

        # Spinning rect cluster: same transform pattern, different shape.
        # Below and left of centre, so both coordinates are negative.
        with canvas.transform(translate(-232.0, -165.0)):
            canvas.stroke_enabled(False)
            canvas.fill(_HUB)
            canvas.circle((0.0, 0.0), 8.0)

            for i in range(6):
                var arm_angle = elapsed * 0.9 + Float64(i) * TAU / 6.0
                # Arm rotates; rect counter-rotates so it stays axis-aligned in world space
                with canvas.transform(
                    rotate(arm_angle)
                    @ translate(70.0, 0.0)
                    @ rotate(-arm_angle)
                ):
                    var t = (sin(elapsed * 2.0 + Float64(i)) + 1.0) / 2.0
                    canvas.fill(_COOL.lerp(_WARM, t))
                    canvas.rectangle((0.0, 0.0), 36.0, 18.0)

        # Rotating triangle fan
        with canvas.transform(translate(232.0, -165.0)):
            for i in range(5):
                var a = elapsed * 0.6 + Float64(i) * TAU / 5.0
                with canvas.transform(rotate(a)):
                    canvas.stroke_enabled(False)
                    canvas.fill(_COOL.lerp(_WARM, Float64(i) / 4.0))
                    canvas.triangle((0.0, 0.0), (60.0, 15.0), (60.0, -15.0))


def main() raises:
    run[Transforms]("Transforms", width=800, height=600)
