"""`Noise`: a 2D field moving through time shades a grid from water to grass,
and a 1D field read with the clock steers the circle.
"""

from create import *

comptime COLUMNS = 80
comptime ROWS = 60

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime WATER = Color.BLUE
comptime GRASS = Color.GREEN


@fieldwise_init
struct App(Program):
    var terrain: Noise
    """The animated field behind everything, one sample per grid cell.

    Its feature size is in world units, so hills stay about 150 across however
    finely the grid samples them; the time passed to `at` is scaled at the
    call instead, which sets how fast the field evolves.
    """

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(Noise(7, feature_size=150))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)
        var t = context.time.elapsed

        # A grid of cells shaded from deep water to pale grass. Anchored to the
        # edge methods, so the field fills whatever the canvas reports.
        var cell_w = (canvas.right() - canvas.left()) / Float64(COLUMNS)
        var cell_h = (canvas.top() - canvas.bottom()) / Float64(ROWS)
        canvas.stroke_enabled(False)
        for column in range(COLUMNS):
            for row in range(ROWS):
                var center = Point(
                    canvas.left() + (Float64(column) + 0.5) * cell_w,
                    canvas.bottom() + (Float64(row) + 0.5) * cell_h,
                )
                var height = self.terrain.at(center, time=t * 0.3)
                # Layered octaves average towards 0.5, so stretch the middle
                # of the range across the whole gradient.
                canvas.fill(WATER.lerp(GRASS, smoothstep(0.3, 0.7, height)))
                canvas.rectangle(center, cell_w, cell_h)


def main() raises:
    run[App]("Noise", width=800, height=600)
