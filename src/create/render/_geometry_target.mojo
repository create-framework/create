"""Internal: how a piece of geometry is drawn, decided in `render`.

A shape knows nothing of drawing. `_GeometryTarget` is what can take one
primitive per kind of shape, and `draw_geometry` is the one place a generic
`Geometry` is matched to its kind and handed to the target's primitive for
it. `Canvas` records it, `RegionCapture` keeps it as a clip, and the `ui`
recorder keeps it for later.
"""

from create.geometry import (
    Arc,
    Bezier,
    Capsule,
    Circle,
    Ellipse,
    Geometry,
    Line,
    Polygon,
    Rectangle,
    Sector,
    Spline,
    Triangle,
)


trait _GeometryTarget:
    """Something that takes a shape as the primitive for its kind."""

    def _rectangle(mut self, r: Rectangle):
        ...

    def _circle(mut self, c: Circle):
        ...

    def _ellipse(mut self, e: Ellipse):
        ...

    def _capsule(mut self, c: Capsule):
        ...

    def _triangle(mut self, t: Triangle):
        ...

    def _sector(mut self, s: Sector):
        ...

    def _polygon(mut self, p: Polygon):
        ...

    def _line(mut self, l: Line):
        ...

    def _curves(mut self, curves: List[Bezier]):
        """A chain of Béziers, each starting where the last ends, stroked
        as one: a `Bezier`, an `Arc` or a `Spline`."""
        ...


def draw_geometry[G: Geometry, T: _GeometryTarget](shape: G, mut target: T):
    """Hand `shape` to `target`'s primitive for its kind.

    The kinds are the library's own, so the match is made when the program
    is compiled; a `Geometry` type of a program's own fails to compile here.
    A program draws the library's shapes it is made of instead.
    """
    comptime if G == Rectangle:
        target._rectangle(rebind[Rectangle](shape))
    elif G == Circle:
        target._circle(rebind[Circle](shape))
    elif G == Ellipse:
        target._ellipse(rebind[Ellipse](shape))
    elif G == Capsule:
        target._capsule(rebind[Capsule](shape))
    elif G == Triangle:
        target._triangle(rebind[Triangle](shape))
    elif G == Sector:
        target._sector(rebind[Sector](shape))
    elif G == Polygon:
        target._polygon(rebind[Polygon](shape))
    elif G == Line:
        target._line(rebind[Line](shape))
    elif G == Bezier:
        target._curves([rebind[Bezier](shape)])
    elif G == Arc:
        # Converted here, in local space: the transform maps Béziers
        # exactly, so a non-uniform scale draws the arc of an ellipse.
        target._curves(rebind[Arc](shape).beziers())
    elif G == Spline:
        # Converted here, in local space: the knot spacing is measured where
        # the points were given, so a non-uniform scale can't reshape it.
        target._curves(rebind[Spline](shape).beziers())
    else:
        comptime assert False, (
            "canvas.draw draws the library's shapes and curves; draw the"
            " library's shapes your type is made of instead"
        )
