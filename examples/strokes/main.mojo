"""Stroke caps and alignment side by side: each cap on a thick translucent
line and arc, each alignment on a rectangle, a rounded triangle and a
polygon, with a thin guide marking the true geometry. Drag the mouse to
draw with round caps, which close the notches between segments; press
Space to clear.
"""

from create import *

comptime _BACKGROUND = Color(240, 236, 222)
comptime _INK = Color(40, 40, 44)
comptime _GUIDE = Color(226, 46, 56)
comptime _STROKE = Color(98, 104, 168, 170)
comptime _FILL = Color(201, 140, 150)

comptime _COLUMN = 400.0
"""How far apart the three columns stand."""
comptime _MAX_POINTS = 2000
"""The drawing stops growing past this many points."""


def _cap_name(cap: StrokeCap) -> String:
    if cap == StrokeCap.ROUND:
        return "ROUND"
    if cap == StrokeCap.SQUARE:
        return "SQUARE"
    return "BUTT"


def _alignment_name(alignment: StrokeAlign) -> String:
    if alignment == StrokeAlign.CENTER:
        return "CENTER"
    if alignment == StrokeAlign.OUTSIDE:
        return "OUTSIDE"
    return "INSIDE"


@fieldwise_init
struct App(Program):
    var drawing: List[List[Point2D]]
    """The mouse strokes, one list of points per drag."""

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(drawing=List[List[Point2D]]())

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.keyboard.pressed(Key.SPACE):
            self.drawing.clear()
        if context.mouse.pressed():
            self.drawing.append(List[Point2D]())
        if context.mouse.down() and len(self.drawing) > 0:
            var points = 0
            for stroke in self.drawing:
                points += len(stroke)
            if points < _MAX_POINTS:
                self.drawing[len(self.drawing) - 1].append(
                    context.mouse.position
                )

        canvas.background(_BACKGROUND)
        canvas.text_color(_INK)
        canvas.font_size(18)

        # Caps: the same line and arc ended three ways. The guide runs
        # between the true end points; BUTT stops there, ROUND and SQUARE
        # reach half the thickness past them.
        var caps: List[StrokeCap] = [
            StrokeCap.BUTT,
            StrokeCap.ROUND,
            StrokeCap.SQUARE,
        ]
        for i in range(3):
            var x = (Float64(i) - 1.0) * _COLUMN
            var start = Point2D(x - 120, 300)
            var end = Point2D(x + 120, 300)
            with canvas.style(
                stroke=_STROKE, stroke_thickness=36, stroke_cap=caps[i]
            ):
                canvas.line(start, end)
                canvas.arc((x, 120), 90, 0.4, 2.3)
            with canvas.style(stroke=_GUIDE, stroke_thickness=1):
                canvas.line(start, end)
                canvas.arc((x, 120), 90, 0.4, 2.3)
            canvas.text("stroke_cap " + _cap_name(caps[i]), (x, 360))

        # Alignment: the stroke inside the edge, centred on it, or around
        # it. The guide is the shape's true edge.
        var alignments: List[StrokeAlign] = [
            StrokeAlign.INSIDE,
            StrokeAlign.CENTER,
            StrokeAlign.OUTSIDE,
        ]
        for i in range(3):
            var x = (Float64(i) - 1.0) * _COLUMN
            var rectangle = Rectangle((x - 110, -110), 90, 90)
            var triangle = Triangle(
                (x - 45, -155), (x + 45, -155), (x, -65), corner_radius=10
            )
            var polygon = Polygon.star((x + 115, -110), 55, 25, 5)
            with canvas.style(
                fill=_FILL,
                stroke=_STROKE,
                stroke_thickness=16,
                stroke_alignment=alignments[i],
            ):
                canvas.draw(rectangle)
                canvas.draw(triangle)
                canvas.draw(polygon)
            with canvas.style(
                stroke=_GUIDE, stroke_thickness=1, fill_enabled=False
            ):
                canvas.draw(rectangle)
                canvas.draw(triangle)
                canvas.draw(polygon)
            canvas.text(
                "stroke_alignment " + _alignment_name(alignments[i]), (x, -10)
            )

        # The mouse drawing: each segment its own line, round-capped, so
        # the segments meet without a notch at any turn.
        with canvas.style(
            stroke=_INK, stroke_thickness=14, stroke_cap=StrokeCap.ROUND
        ):
            for stroke in self.drawing:
                for i in range(len(stroke)):
                    canvas.line(stroke[max(i - 1, 0)], stroke[i])
        canvas.text(
            "Drag to draw with round caps, Space to clear",
            (0, canvas.bottom() + 30),
        )


def main() raises:
    run[App]("Strokes", width=1280, height=800)
