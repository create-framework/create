# Shapes

Create's shapes are plain values: a `Circle` is a position and a radius, which you can keep in a
field, move, draw with `canvas.draw` (see [The canvas](../drawing/canvas.md#shapes)) and test
against other shapes (see [Collisions](collisions.md)). This page describes the **regions**, the
shapes with an inside: what each one is, how it is built, and what is particular about it. Lines and
curves, which have no inside, are described in [Curves](curves.md).

## The regions

There are seven:

| Shape | What it is | Built from |
|---|---|---|
| `Rectangle` | A rectangle, which can be turned | `Rectangle(position, width, height, corner_radius=, rotation=)` |
| `Circle` | A circle | `Circle(position, radius)` |
| `Ellipse` | A circle stretched to a width and height | `Ellipse(position, width, height)` |
| `Capsule` | A pill: a bar with round ends | `Capsule(start, end, radius)` |
| `Triangle` | A triangle through three points | `Triangle(a, b, c, corner_radius=)` |
| `Sector` | A slice of a circle, like a slice of pie | `Sector(position, radius, start_angle, sweep_angle, corner_radius=)` |
| `Polygon` | Any outline of straight edges | `Polygon(vertex, vertex, …, corner_radius=)`, `Polygon.regular(…)`, `Polygon.star(…)` |

Every shape is positioned by its centre (see [Coordinates](../basics/coordinates.md)), and angles
are in radians, counter-clockwise from the positive x axis (see [Angles](../math/angles.md)). Like
every value in Create, a shape is never changed by its own methods: they return a new shape and
leave the one they were called on as it was, so moving a rectangle is `rect =
rect.translate(delta)`.

## Corner radius

A rectangle, triangle, polygon or sector can have rounded corners. `corner_radius` is the radius of
the rounding: the corners become arcs of a circle that size. It is a keyword-only field of
`Rectangle`, `Triangle`, `Polygon` and `Sector`, such as `Rectangle(position, width, height,
corner_radius=8)`. A shape value is always drawn and clipped with its own radius, whatever the style
says.

- **The canvas calls** that build a shape from numbers (`rectangle`, `triangle`, `polygon` and
  `sector`) take a `corner_radius=` keyword too. Without one, they use the style's corner radius,
  set with `canvas.corner_radius(radius)`, `Style(corner_radius=)` or
  `canvas.style(corner_radius=)`. A keyword given to the call wins over the style, even
  `corner_radius=0`.
- **A radius too large for the shape is reduced** to the largest that fits: for a rectangle, half
  its shorter side; for a triangle, the largest radius with which no corner's rounding runs past the
  middle of an edge. A polygon's and a sector's corners are each reduced on their own, and a corner
  that points inwards is rounded by filling in its notch.
- **The collision tests take the rounding into account**, as do `closest_point` and `area`: exactly
  for rectangles and triangles, and to within about 0.1% of the radius for polygons and sectors.
- A rounded polygon or sector is drawn as a polygon with many more corners, so its stroke costs more
  to draw (see [Polygon](#polygon)).

## `Rectangle`

A rectangle is positioned by its centre, and is `width` wide and `height` high. It is upright unless
turned by `rotation=`, a keyword-only argument of both `Rectangle` and `canvas.rectangle`: an angle
in radians, counter-clockwise round its centre, 0 by default.

Every test sees the turned rectangle exactly. `bounds()`, and `left()`, `right()`, `bottom()` and
`top()`, describe its bounding box instead: the smallest upright rectangle round it. A turned
rectangle is drawn as an upright one turned by a transform, so its rounding, stroke and gradient
turn with it, while its shadow's offset stays fixed to the screen, as it does under
`canvas.transform`.

## `Circle`

A circle is `radius` round its centre, `position`. `canvas.circle(position, radius)` draws one.
Every test against a circle is exact.

## `Ellipse`

An ellipse is a circle stretched to `width` by `height`. As with a `Rectangle`, `position` is its
centre and `width` and `height` are its full width and height, so it exactly fills the rectangle its
`bounds()` returns. `canvas.ellipse(position, width, height)` draws one, like Processing's
`ellipse`. Its axes are always horizontal and vertical: unlike `Rectangle`, it has no `rotation=`,
so to turn one, draw it inside a `canvas.transform`.

- Its tests against a point, a `Line`, a `Circle`, another `Ellipse`, and a `Rectangle`, `Triangle`
  or `Polygon` without rounded corners are exact. Against a `Sector` or an `Arc` they are accurate
  to within a ten-thousandth of the ellipse's size.
- An ellipse with a `width` or `height` of zero is flat: a line segment, in every test and when
  drawn.
- It is drawn as a polygon with enough corners to look perfectly smooth, as a circle is, so its
  stroke is equally thick all the way round and is placed by `stroke_alignment`. Filled, it costs
  about as much to draw as a circle; stroked, about three times as much. Inset shadows don't apply
  to it.

## `Capsule`

A capsule is shaped like a pill, a bar with round ends: every point within `radius` of the line
segment from `start` to `end`. `canvas.capsule(start, end, radius)` draws one. As a collider it fits
a long, rounded body, such as a standing character or a limb, more closely than a rectangle, whose
corners would report hits where nothing is drawn. Unlike an `Ellipse`, it can also lie at any angle.
It can also cover a moving circle's whole path: a capsule from where a ball was last frame to where
it is now, with the ball's radius, overlaps a wall whenever the ball passed through it, so a fast
ball can't skip through a thin wall between two frames (see
[Collisions](collisions.md#moving-shapes)).

- It is placed by its two ends, like a `Line`, so `center()` and `move_to` use the point midway
  between them. When `start` and `end` are the same point, the capsule is a circle. For a capsule
  shape with square-cut sides, a rectangle with fully rounded ends is `Rectangle(position, width,
  height, corner_radius=height / 2, rotation=angle)`.
- Every test against a capsule is exact, except whether it contains a `Sector`'s curved edge or an
  `Ellipse`, which is accurate to within a ten-thousandth of their size.
- A capsule with a `radius` of zero is a line segment, and draws nothing.
- It is drawn as a polygon, with its round ends as smooth as a circle of the same radius, and a
  gradient spans its bounding box. Filled, it costs about as much to draw as a circle; stroked,
  about 2.3 times as much. Inset shadows don't apply to it.

## `Triangle`

A triangle is the shape with its corners at three points, `a`, `b` and `c`, given in any order.
`canvas.triangle(a, b, c)` draws one, and `corner_radius=` rounds all three corners by the same
radius.

## `Polygon`

A polygon is any shape with straight edges. It is built from its corners, its **vertices**, in
order, and its outline runs from each vertex to the next and from the last back to the first. Its
edges may point inwards, as a star's do, and may even cross each other.

Two constructors build the common shapes:

- `Polygon.regular(position, radius, sides)` is a regular polygon, with all its sides the same
  length, such as a hexagon with `sides=6`. Its vertices lie on a circle of `radius` round
  `position`.
- `Polygon.star(position, radius, inner_radius, tips)` is a star with `tips` points. Its tips lie
  `radius` from `position`, and the corners between them `inner_radius` from it.

Both put their first vertex at `start_angle`, which is straight up unless you give another.

- What is inside follows the **nonzero rule**: a point is inside when the outline goes round it more
  times in one direction than the other. So a pentagram drawn through five crossing vertices is
  solid through its middle rather than hollow. It doesn't matter whether the vertices run clockwise
  or counter-clockwise, and a point on the outline counts as inside.
- `center()` is the polygon's centroid, the balance point of its area, and `area()` its area. Both
  are meaningful only for a simple polygon, one whose edges don't cross.
- `canvas.polygon` places its stroke by `stroke_alignment` along the outline, but centres it on an
  edge that runs through the inside, such as the edges of a pentagram's inner pentagon, so that
  every edge is stroked equally thick. Inset shadows don't apply to it.
- `corner_radius` rounds every vertex, but not the points where crossing edges meet.
- The stroke is the costly part to draw, more so the more corners a polygon has, and rounding them
  multiplies the cost again: on the CPU at `MEDIUM`, a stroked 40-tip star takes about 2 ms a frame,
  and about 20 ms rounded. Filled only, a polygon costs a fraction of that.

## `Sector`

A sector is a slice of a circle, like a slice of pie: its tip is at the circle's centre, `position`,
and it fans out to the circle's edge, `radius` away. Which slice is set by two angles, in radians
(see [Angles](../math/angles.md)):

- `start_angle` is where the slice begins, measured counter-clockwise from the positive x axis.
- `sweep_angle` is how far round it reaches from there. It is **signed**: a positive sweep goes
  counter-clockwise, and a negative one clockwise. A sweep of `TAU` (a full turn) or more is the
  whole circle.

`end_angle()` is where the slice ends, `start_angle + sweep_angle`. An [`Arc`](curves.md#arc) is
described by the same angles: it is the curved edge of a sector, without the inside.

- A sector wider than a half turn looks like a pie with a slice missing, and the missing slice is
  outside it, for `contains` and `overlaps` alike.
- `center()` is `position`, the circle's centre, as for a `Circle`, rather than the balance point of
  the slice.
- `canvas.sector` places its stroke by `stroke_alignment`, as for a circle. Inset shadows don't
  apply to it.
- `corner_radius` rounds the tip and the two corners where the straight edges meet the curved one.
  Past a half turn, the tip points inwards, and its rounding fills in the notch. At exactly a half
  turn the tip is a straight line, so there is nothing there to round, and a whole circle has no
  corners at all.

## The `Shape` and `Region` traits

The shapes share traits, so every shape answers the same methods, and a function can take any of
them (`def f[R: Region](region: R)`):

- **`Shape`**, which every shape and curve conforms to: `bounds` (the smallest upright rectangle
  round it), `closest_point` (the point of the shape nearest a given point) and `translate`.
- **`Region`**, which the seven regions conform to, and which `canvas.clip` takes: `center`, `area`,
  `contains(point)` and `move_to`.

The tests between two shapes (`overlaps`, `contains(shape)` and `intersects`) are not trait methods,
but methods written separately for each pair of shapes (see [Collisions](collisions.md)).
