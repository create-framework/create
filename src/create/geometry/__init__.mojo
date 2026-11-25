"""Shapes and curves, the traits they share, and the collision tests: each
shape's `overlaps` and `contains`, and each curve's `intersects`. How they
are drawn is `render`'s.
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
from .bezier import Bezier
from .spline import Spline
from .traits import Curve, Geometry, Shape
