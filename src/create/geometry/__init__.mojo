"""Shapes and curves, the traits that make a type drawable, and the collision
tests: `overlaps`, and each shape's `contains` and `intersects`.
"""
from .rectangle import Rectangle
from .circle import Circle
from .ellipse import Ellipse
from .capsule import Capsule
from .line import Line
from .triangle import Triangle
from .arc import Arc
from .sector import Sector
from .polygon import Polygon
from .overlaps import overlaps
from .bezier import Bezier
from .spline import Spline
from .drawable import Curve, Drawable, DrawTarget, Region, Shape
