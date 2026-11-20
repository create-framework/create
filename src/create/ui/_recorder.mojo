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
from create.image import Image
from create.math import Point
from create.render import Canvas, Style


@fieldwise_init
struct _Text(Copyable, Movable):
    var text: String
    var position: Point


@fieldwise_init
struct _Picture(Copyable, Movable):
    var image: Image
    var position: Point
    var width: Float64
    var height: Float64


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
    _Text,
    _Picture,
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

    def text(mut self, text: String, position: Point, style: Style):
        """Record `text`, drawn at `position` in `style`'s text settings."""
        self.commands.append(_DrawCommand(_Shape(_Text(text, position)), style))

    def image(
        mut self,
        image: Image,
        position: Point,
        width: Float64,
        height: Float64,
        style: Style,
    ):
        """Record `image`, centred at `position` and stretched to `width` by
        `height`."""
        self.commands.append(
            _DrawCommand(
                _Shape(_Picture(image, position, width, height)), style
            )
        )

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
                elif shape.isa[_Text]():
                    ref text = shape[_Text]
                    canvas.text(text.text, text.position)
                elif shape.isa[_Picture]():
                    ref picture = shape[_Picture]
                    canvas.image(
                        picture.image,
                        picture.position,
                        picture.width,
                        picture.height,
                    )
                else:
                    canvas._curves(shape[List[Bezier]])
        self.commands.clear()
