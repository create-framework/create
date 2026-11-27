"""Stroke caps, alignment and dashes side by side: each cap on a thick
translucent line and arc, each alignment on a rectangle, a rounded triangle
and a polygon, with a thin guide marking the true geometry, and three dash
patterns, the last marching round.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime TEXT = COLORS.on_surface
comptime GUIDE = COLORS.on_surface
comptime FILL = COLORS.surface_container_highest
comptime STROKE = Color.CYAN.with_alpha(150)

comptime COLUMN = 400.0
"""How far apart the three columns stand."""
comptime ROW = 250.0
"""How far apart the three rows stand."""
comptime TOP_LABEL = 322.0
"""Where the top row's label sits; each row's shapes sit below its label."""
comptime LABEL_GAP = 110.0
"""How far below its label a row's shapes are centred."""
comptime SHAPE = 90.0
"""How big each shape in the alignment row is."""
comptime SHAPE_SPACING = 120.0
"""How far apart the shapes in the alignment row stand."""


def cap_name(cap: StrokeCap) -> String:
    if cap == StrokeCap.ROUND:
        return "ROUND"
    if cap == StrokeCap.SQUARE:
        return "SQUARE"
    return "BUTT"


def alignment_name(alignment: StrokeAlign) -> String:
    if alignment == StrokeAlign.CENTER:
        return "CENTER"
    if alignment == StrokeAlign.OUTSIDE:
        return "OUTSIDE"
    return "INSIDE"


@fieldwise_init
struct App(Program):
    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App()

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(BACKGROUND)
        canvas.text_color(TEXT)
        canvas.font_size(18)

        # Caps: the same line and arc ended three ways. The guide runs
        # between the true end points; BUTT stops there, ROUND and SQUARE
        # reach half the thickness past them.
        var caps: List[StrokeCap] = [
            StrokeCap.BUTT,
            StrokeCap.ROUND,
            StrokeCap.SQUARE,
        ]
        var label = TOP_LABEL
        var y = label - LABEL_GAP
        for i in range(3):
            var x = (Float64(i) - 1) * COLUMN
            var start = Point(x - 110, y + 45)
            var end = Point(x + 110, y + 45)
            var arc_center = Point(x, y + 75)

            with canvas.style(
                stroke=STROKE, stroke_thickness=28, stroke_cap=caps[i]
            ):
                canvas.line(start, end)
                canvas.arc(arc_center, 110, 1.25 * PI, 0.5 * PI)

            with canvas.style(stroke=GUIDE, stroke_thickness=1):
                canvas.line(start, end)
                canvas.arc(arc_center, 110, 1.25 * PI, 0.5 * PI)

            canvas.text("stroke_cap " + cap_name(caps[i]), (x, label))

        # Alignment: the stroke inside the edge, centred on it, or around
        # it. The guide is the shape's true edge.
        var alignments: List[StrokeAlign] = [
            StrokeAlign.INSIDE,
            StrokeAlign.CENTER,
            StrokeAlign.OUTSIDE,
        ]
        label -= ROW
        y = label - LABEL_GAP
        var half = SHAPE / 2
        for i in range(3):
            var x = (Float64(i) - 1) * COLUMN
            var rectangle = Rectangle((x - SHAPE_SPACING, y), SHAPE, SHAPE)
            var triangle = Triangle(
                (x - half, y - half),
                (x + half, y - half),
                (x, y + half),
                corner_radius=10,
            )
            var polygon = Polygon.star((x + SHAPE_SPACING, y), half + 5, 22, 5)

            with canvas.style(
                fill=FILL,
                stroke=STROKE,
                stroke_thickness=12,
                stroke_alignment=alignments[i],
            ):
                canvas.draw(rectangle)
                canvas.draw(triangle)
                canvas.draw(polygon)

            with canvas.style(
                stroke=GUIDE, stroke_thickness=1, fill_enabled=False
            ):
                canvas.draw(rectangle)
                canvas.draw(triangle)
                canvas.draw(polygon)

            canvas.text(
                "stroke_alignment " + alignment_name(alignments[i]),
                (x, label),
            )

        # Dashes: a preset sized by the thickness, round dots, and exact
        # lengths marching round as their offset grows.
        var dashes: List[StrokeDash] = [
            StrokeDash.DASHED,
            StrokeDash.DOTTED,
            StrokeDash(24, 10, 4, 10).with_offset(context.time.elapsed * 40),
        ]
        var dash_names: List[String] = [
            "StrokeDash.DASHED",
            "StrokeDash.DOTTED",
            "StrokeDash(24, 10, 4, 10)",
        ]
        label -= ROW
        y = label - LABEL_GAP
        for i in range(3):
            var x = (Float64(i) - 1) * COLUMN
            with canvas.style(
                fill=FILL,
                stroke=STROKE,
                stroke_thickness=8,
                stroke_dash=dashes[i],
                stroke_cap=StrokeCap.ROUND if i == 2 else StrokeCap.BUTT,
            ):
                canvas.rectangle((x - 55, y), 120, 80, corner_radius=14)
                canvas.circle((x + 75, y), 40)

            canvas.text("stroke_dash " + dash_names[i], (x, label))


def main() raises:
    run[App]("Strokes", width=1280, height=800)
