# create.geometry

Shapes and curves, the traits that make a type drawable, and the collision tests: each shape's `overlaps` and `contains`, and each curve's `intersects`.

## Types

| Type | Description |
|---|---|
| [`Rectangle`](rectangle.md) | A rectangle, upright unless turned by `rotation`: `center`, `area`, `bounds`, `left`/`right`/`bottom`/`top`, `closest_point`, `contains`, `move_to`, `translate`. |
| [`Circle`](circle.md) | A circle: `center`, `area`, `diameter`, `closest_point`, `contains`, `move_to`, `translate`. |
| [`Ellipse`](ellipse.md) | An axis-aligned ellipse: `center`, `area`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`. |
| [`Capsule`](capsule.md) | A capsule: every point within `radius` of the segment from `start` to `end` -- a rectangle along the segment, capped by a half disc at each end. `center`, `area`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`. |
| [`Line`](line.md) | A line segment from `start` to `end`: `length`, `at`, `tangent`, `at_distance`, `split`, `midpoint`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `move_to`, `translate`. |
| [`Triangle`](triangle.md) | A triangle defined by its three vertices `a`, `b`, `c`: `center`, `area`, `closest_point`, `contains`, `move_to`, `translate`. |
| [`Arc`](arc.md) | A circular arc: part of the circle around `position` with `radius`, from `start_angle` round by `sweep_angle`. `end_angle`, `at`, `tangent`, `length`, `at_distance`, `split`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `move_to`, `translate`. |
| [`Sector`](sector.md) | A sector -- a slice of pie: the region between two radii of the circle around `position` with radius `radius`, from `start_angle` round by `sweep_angle`. `end_angle`, `center`, `area`, `arc`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`. |
| [`Polygon`](polygon.md) | A polygon through `vertices`, in order, closed back to the first: `regular`, `star`, `center`, `area`, `bounds`, `closest_point`, `contains`, `move_to`, `translate`. |
| [`Bezier`](bezier.md) | A cubic Bézier curve from `start` to `end`, shaped by `control1` and `control2`: `at`, `tangent`, `split`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `translate`. |
| [`Spline`](spline.md) | A smooth curve through every one of `points`, in order: `at`, `tangent`, `length`, `at_distance`, `bounds`, `flatten`, `beziers`, `closest_point`, `intersects`, `translate`. |

## Traits

| Trait | Description |
|---|---|
| [`Curve`](curve.md) | Geometry with no inside, traced from one end to the other: `Line`, `Arc`, `Bezier` and `Spline`. A straight line is a curve too, as in mathematics. |
| [`Drawable`](drawable.md) | Something a `DrawTarget` can draw: a shape, a curve, or a program's own type made of them. |
| [`DrawTarget`](drawtarget.md) | Somewhere shapes are drawn: `Canvas`. Its primitives, one per kind of shape, are the library's own; a program draws through `draw`. |
| [`Geometry`](geometry.md) | A piece of geometry: a `Shape` or a `Curve`. What every one of them answers, whichever it is, and a plain value generic code can keep, copy and drop. Tests between two of them (`contains`, `intersects`, `overlaps`) are methods overloaded per type they take, not part of this. |
| [`Shape`](shape.md) | Geometry with an inside: `Rectangle`, `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector` and `Polygon`, the types of `overlaps` and `contains`, and what `canvas.clip` takes. A curve has no inside, so it is not one. |
