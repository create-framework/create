"""Internal: the list a layer draws on, replayed onto the canvas in call order
when the layer's block ends."""

from std.utils import Variant

from create.geometry import (
    Bezier,
    Capsule,
    Circle,
    DrawTarget,
    Drawable,
    Ellipse,
    Line,
    Polygon,
    Rectangle,
    Sector,
    Triangle,
)
from create.render import Canvas, Style

comptime _Shape = Variant[
    Rectangle,
    Circle,
    Ellipse,
    Capsule,
    Triangle,
    Sector,
    Polygon,
    Line,
    List[Bezier],
]


@fieldwise_init
struct _DrawCommand(Copyable, Movable):
    var shape: _Shape
    var style: Style


struct _Recorder(DrawTarget, Movable):
    """A `DrawTarget` that keeps each primitive with the style it was drawn
    in. A shape draws itself into it through `draw_to`, so a program's own
    `Drawable` types are recorded as the shapes they are made of, and no
    dynamic dispatch is needed to replay them."""

    var commands: List[_DrawCommand]
    var style: Style

    def __init__(out self):
        self.commands = []
        self.style = Style()

    def _rectangle(mut self, r: Rectangle):
        self.commands.append(_DrawCommand(_Shape(r), self.style))

    def _circle(mut self, c: Circle):
        self.commands.append(_DrawCommand(_Shape(c), self.style))

    def _ellipse(mut self, e: Ellipse):
        self.commands.append(_DrawCommand(_Shape(e), self.style))

    def _capsule(mut self, c: Capsule):
        self.commands.append(_DrawCommand(_Shape(c), self.style))

    def _triangle(mut self, t: Triangle):
        self.commands.append(_DrawCommand(_Shape(t), self.style))

    def _sector(mut self, s: Sector):
        self.commands.append(_DrawCommand(_Shape(s), self.style))

    def _polygon(mut self, p: Polygon):
        self.commands.append(_DrawCommand(_Shape(p.copy()), self.style))

    def _line(mut self, l: Line):
        self.commands.append(_DrawCommand(_Shape(l), self.style))

    def _curves(mut self, curves: List[Bezier]):
        self.commands.append(_DrawCommand(_Shape(curves.copy()), self.style))

    def replay(mut self, mut canvas: Canvas):
        """Draw every recorded command onto `canvas`, in order, and empty the
        list, keeping its memory for the next layer."""
        for ref command in self.commands:
            with canvas.style(command.style):
                ref shape = command.shape
                if shape.isa[Rectangle]():
                    canvas._rectangle(shape[Rectangle])
                elif shape.isa[Circle]():
                    canvas._circle(shape[Circle])
                elif shape.isa[Ellipse]():
                    canvas._ellipse(shape[Ellipse])
                elif shape.isa[Capsule]():
                    canvas._capsule(shape[Capsule])
                elif shape.isa[Triangle]():
                    canvas._triangle(shape[Triangle])
                elif shape.isa[Sector]():
                    canvas._sector(shape[Sector])
                elif shape.isa[Polygon]():
                    canvas._polygon(shape[Polygon])
                elif shape.isa[Line]():
                    canvas._line(shape[Line])
                else:
                    canvas._curves(shape[List[Bezier]])
        self.commands.clear()
