# Geometry

Create's shapes and curves are plain values: a `Circle` is a position and a radius, drawn with
`canvas.draw` (see [Drawing](drawing.md#shapes)) and tested against other shapes for collisions.

## Shapes and curves

There are eleven, in two kinds. A **region** has an inside; a **curve** is a path with no inside:

| Shape | Kind | Built from |
|---|---|---|
| `Rectangle` | Region | `Rectangle(position, w, h, corner_radius=, rotation=)` |
| `Circle` | Region | `Circle(position, r)` |
| `Ellipse` | Region | `Ellipse(position, w, h)` |
| `Capsule` | Region | `Capsule(start, end, r)` |
| `Triangle` | Region | `Triangle(a, b, c, corner_radius=)` |
| `Sector` | Region | `Sector(position, r, start_angle, sweep_angle, corner_radius=)` |
| `Polygon` | Region | `Polygon(vertex, vertex, …, corner_radius=)`, `Polygon.regular(…)`, `Polygon.star(…)` |
| `Line` | Curve | `Line(start, end)` |
| `Arc` | Curve | `Arc(position, r, start_angle, sweep_angle)` |
| `Bezier` | Curve | `Bezier(start, control1, control2, end)` |
| `Spline` | Curve | `Spline(points, alpha=, closed=)` |

Every shape is positioned by its centre (see [Coordinates](coordinates.md#the-screen)), and angles
are radians counter-clockwise from +x. Like every value type in Create, a shape's methods return a
new shape and leave it as it was: `rect = rect.translate(delta)`.

## The traits

The shapes share traits, so every shape of a kind answers the same methods and generic code takes
any of them (`def f[C: Curve](c: C)`):

- **`Shape(Drawable)`**, every one of the eleven, `Copyable` and `Deinitable`: `bounds`,
  `closest_point`, `translate`.
- **`Region(Shape)`**, the seven with an inside (`Rectangle`, `Circle`, `Ellipse`, `Capsule`,
  `Triangle`, `Sector`, `Polygon`), which `canvas.clip` takes: `center`, `area`,
  `contains(Point2D)`, `move_to`.
- **`Curve(Shape)`**, the four without (`Line`, `Arc`, `Bezier`, `Spline`; a straight line is a
  curve, as in mathematics): `at`, `tangent` (the derivative, not unit), `length`, `at_distance`,
  `flatten`, `beziers`.

Some methods are not trait methods. The tests between two shapes (`overlaps`, `contains(shape)`,
`intersects`) are overloads per pair. A curve's `move_to` exists only on `Line` (its midpoint) and
`Arc` (its centre), and `split(t)` only on `Line`, `Arc` and `Bezier`: a piece of a `Spline` is
not a `Spline`.

## Collisions

Three tests answer whether shapes touch:

```mojo
# A fragment of an `update`.
var player = Circle(self.position, 16)
var wall = Rectangle((200, 0), 40, 300)
var laser = Line((-300, 50), (300, 50))

if overlaps(player, wall):  # two regions touch
    self.position = self.previous_position
if laser.intersects(player):  # a curve crosses a shape
    self.health -= 1
if wall.contains(context.mouse.position):  # a point, region or curve is inside
    context.cursor(Cursor.HAND)
```

- **`overlaps(a, b)`** is a free function, symmetric, for regions only (`Rectangle`, `Circle`,
  `Ellipse`, `Capsule`, `Triangle`, `Sector`, `Polygon`).
- **`curve.intersects(x)`** tests every curve (`Line`, `Arc`, `Bezier`, `Spline`) against every
  shape and `Point2D`, both ways round, since a curve has no interior.
- **`region.contains(x)`** is asymmetric: every region against every region and every curve.

A curve is never a region. All three see a shape's `corner_radius`. `Line` and `Arc` are exact
(to `_RADIUS_EPSILON` with an arc); `Bezier` and `Spline` flatten themselves to within 1e-4 of
their size, so a crossing is always found but a graze or near miss is decided only that closely.
A region's `contains` follows `Arc`, `Bezier` and `Spline` the same way.

## Corner radius

`corner_radius` is a keyword-only field of `Rectangle`, `Triangle`, `Polygon` and `Sector`
(`Rectangle(p, w, h, corner_radius=8)`). A shape value is drawn and clipped by its own radius,
whatever the style says.

- The scalar canvas calls (`rectangle`, `triangle`, `polygon`, `sector`) take a `corner_radius=`
  keyword, and without one use the style's: `canvas.corner_radius(r)`, `Style(corner_radius=)`,
  `canvas.style(corner_radius=)`. A named keyword beats the style, `corner_radius=0` included.
- It is clamped as drawn: a rectangle's to half its shorter side, a triangle's one radius so no
  corner overruns half an edge, and a polygon's and a sector's corners each on their own, a
  concave corner filling its notch.
- Every `contains`, `overlaps`, `intersects`, `closest_point` and `area` sees it: rectangles and
  triangles exactly, polygons and sectors through their stroke with each curve flattened (within
  ~0.1% of the radius).
- A rounded polygon or sector draws as a polygon of more vertices, so it costs more stroked (see
  [`Polygon`](#polygon)).

## Shape by shape

### `Rectangle`

Centre-positioned, `w` by `h`, and upright unless turned: `rotation=` (keyword-only, radians
counter-clockwise about `position`, default 0) on `Rectangle` and `canvas.rectangle`. Every test
sees the turned shape exactly; `bounds()` and `left()`, `right()`, `bottom()`, `top()` are its
upright bounding box's. It is drawn as the upright rectangle under a rotation, so rounding, stroke
and a gradient turn with it and a shadow's offset stays screen-fixed, as under `canvas.transform`.

### `Ellipse`

Axis-aligned, a region: `position` is its centre and `w`/`h` its full width and height, as a
`Rectangle`'s, whose `bounds()` it fills (`canvas.ellipse(p, w, h)`, Processing's `ellipse`). Turn
one with `canvas.transform`.

- Tests against a point, `Line`, `Circle`, another `Ellipse` and a sharp `Rectangle`, `Triangle`
  or `Polygon` are exact: the stretch onto the unit circle keeps those kinds, and a circle or
  ellipse goes through the exact closest point on an ellipse. Against a `Sector` or an `Arc` the
  ellipse stands in as its outline polygon, within 1e-4 of its size.
- A zero `w` or `h` is its zero-size bounds, in every test and when drawn.
- It is drawn as a polygon flattened as finely as a circle of its larger radius, so its stroke is
  as thick all round and placed by `stroke_alignment`. Filled, it costs what a circle does;
  stroked, about three times as much. No inset shadow.

### `Capsule`

Every point within `r` of the segment `start`→`end`, a region: the round collider for a moving
body, at any angle (`canvas.capsule(start, end, r)`).

- Placed by its ends like a `Line`, so `center()` and `move_to` are the midpoint's. `start == end`
  is the `Circle` there, and a stadium is already
  `Rectangle(p, w, h, corner_radius=h / 2, rotation=a)`.
- Every test is a distance from the segment, exact against everything — points, lines, arcs,
  circles, ellipses, capsules, straight-edged shapes and rounded rectangles and triangles — except
  holding a `Sector`'s arc or an `Ellipse`, which it follows within 1e-4.
- A zero `r` is the segment, and draws nothing.
- It is drawn as a polygon, each end flattened as finely as a circle of `r`, its gradient spanning
  its bounds. Filled it costs what a circle does, stroked about 2.3 times as much. No inset shadow.

### `Polygon`

Any `vertices`, in order, closed back to the first: concave or crossing itself, a region.
`Polygon.regular(position, r, sides)` and `Polygon.star(position, r, inner_radius, tips)` start at
`start_angle`, straight up by default.

- Inside by the **nonzero rule**, so a pentagram of five crossing vertices is solid through its
  middle; vertex order is irrelevant, and the boundary is inside.
- `center()` is the area centroid and `area()` the shoelace area, both meaningful only for a
  simple polygon.
- `canvas.polygon` places its stroke along the outside by `stroke_alignment` but centres it on an
  edge running through the inside (a pentagram's inner pentagon), so every edge is stroked as
  thick. No inset shadow.
- `corner_radius` rounds every vertex (not the crossings of a self-crossing one).
- Stroked, on the CPU at `MEDIUM`, a 5-tip star costs ~160 µs a frame, a pentagram ~380 µs and a
  40-tip star ~2 ms; rounded, ~360 µs, ~460 µs and ~20 ms. Filled only, a fraction of that.

### Sweep: `Sector` and `Arc`

`Arc` and `Sector` share `position` (the circle's centre), `r`, `start_angle` and a **signed**
`sweep_angle`, in radians from +x: positive is counter-clockwise (y is up), negative clockwise,
and |sweep| ≥ `TAU` is the whole circle. They are stored as given, so `==` and printing
round-trip; `end_angle()` is `start_angle + sweep_angle`.

A **`Sector`** is a pie slice, a region: its tip at `position`, fanned out to its arc.

- Wider than a half turn it is not convex: the missing wedge is outside it, for `contains` and
  `overlaps` alike.
- `center()` is `position`, like `Circle`'s, not the centroid.
- `canvas.sector` places its stroke by `stroke_alignment`, as a circle's. No inset shadow.
- `corner_radius` rounds the tip and both ends of the arc, the ends tangent to the arc from inside.
  Past a half turn the tip is concave and its rounding fills the notch; at exactly a half turn it
  runs straight and stays; a whole disc has no corners.

An **`Arc`** is a curve, like `Line`: no interior, never in `overlaps`. It has constant speed, so
`at_distance(d)` is exact. `beziers()` splits it into Béziers of at most 45°, and `canvas.arc`
strokes those as one chain, like `canvas.spline`.

### `Bezier`

A cubic Bézier: `start`, `control1`, `control2`, `end`. It passes through the endpoints only.

- A curve, not a region: `canvas.bezier` strokes it in the stroke style and draws nothing with the
  stroke off.
- `at(t)` is uneven in speed; `at_distance(d)` moves along it at constant speed.
- `closest_point` is a search (samples, then Newton), accurate to rounding.

### `Spline`

A smooth curve through every one of `points`, in order (Catmull-Rom); `closed` runs it on back to
the first.

- `alpha` spaces its knots: 0 uniform (can loop where points bunch), 0.5 centripetal (the default,
  never does), 1 chordal.
- The same sampling methods as `Bezier`, with `t` split evenly per stretch between points.
- `beziers()` converts it exactly, and `canvas.spline` draws it as one stroke of those Béziers.
