# Curves

A curve is a path with no inside: a straight line, part of a circle's edge or a smooth bend through
several points. Curves are drawn with the stroke, so they show only while the stroke is on, and they
are useful well beyond drawing: a curve can be a path for something to follow, a laser to test for
hits or the outline of a road. This page explains what the four curves are and how to find points
along one.

## The curves

| Curve | What it is | Built from |
|---|---|---|
| `Line` | A straight line between two points | `Line(start, end)` |
| `Arc` | Part of a circle's edge | `Arc(position, radius, start_angle, sweep_angle)` |
| `Bezier` | A smooth bend shaped by two control points | `Bezier(start, control1, control2, end)` |
| `Spline` | A smooth curve through any number of points | `Spline(points, alpha=, closed=)` |

A straight line counts as a curve, as in mathematics: it is a path with no inside, like the others.
Like the shapes, a curve is a plain value, never changed by its own methods.

## Points along a curve

Every curve can be followed from its start to its end. There are two ways to say how far along:

- **`at(t)`** is the point a fraction `t` of the way along, with `t` from 0 (the start) to 1 (the
  end). For a `Line` and an `Arc`, `t = 0.5` is exactly halfway. For a `Bezier` or a `Spline` it
  isn't: `t` moves faster along some stretches than others, so equal steps of `t` give unevenly
  spaced points.
- **`at_distance(d)`** is the point `d` units along the curve, measured along its path. Equal steps
  of `d` always give evenly spaced points, which is what something moving along the curve at a
  steady speed needs. `length()` is the curve's whole length.

```mojo
# In `update`, with a `path: Spline` field: a marker travelling along the path
# at 100 units a second, starting over each time it reaches the end.
var travelled = wrap(context.time.elapsed * 100, self.path.length())
canvas.circle(self.path.at_distance(travelled), 8)
```

`tangent(t)` is the direction the curve is heading at `t`, as a `Vector`, so something moving along
a curve can be turned to face the way it is going, with `tangent(t).angle()`. Its length is the
curve's speed at that point rather than 1; use `.normalize()` for a direction of length 1.

Curves also convert to simpler forms:

- **`flatten(tolerance)`** turns the curve into a list of points, close enough together that the
  straight lines between them never stray more than `tolerance` units from the curve.
- **`beziers()`** turns it into a list of `Bezier`s that trace it exactly, or for an `Arc`, very
  closely.
- **`split(t)`** cuts a `Line`, `Arc` or `Bezier` in two at `t`, returning the two pieces as a
  tuple. A `Spline` can't be split this way, since a piece of a spline isn't itself a spline.

## `Line`

A line is the straight path from `start` to `end`. `canvas.line(start, end)` draws one. Every test
against a line is exact. `move_to` moves a line so that its midpoint lands on a given point.

## `Arc`

An arc is part of the edge of a circle, whose centre is `position` and whose radius is `radius`.
Which part is set by two angles, in radians (see [Angles](../math/angles.md)):

- `start_angle` is where the arc begins, measured counter-clockwise from the positive x axis.
- `sweep_angle` is how far round it reaches from there. It is **signed**: a positive sweep goes
  counter-clockwise, and a negative one clockwise. A sweep of `TAU` (a full turn) or more is the
  whole circle.

`end_angle()` is where the arc ends, `start_angle + sweep_angle`. `canvas.arc` draws one.

An arc is a curve, like `Line`: it has no inside, so it is never tested with `overlaps`. A pie-slice
shape with an inside is a [`Sector`](shapes.md#sector) instead. Equal steps of `t` move equal
distances along an arc, so `at(t)` and `at_distance(d)` are both exact. `beziers()` approximates it
with Bézier curves, each covering at most an eighth of a turn, and `canvas.arc` draws those as one
unbroken stroke.

## `Bezier`

A Bézier curve is the smooth curve that drawing programs use for their pen tool. It runs from
`start` to `end`, and two **control points**, `control1` and `control2`, bend it: the curve leaves
`start` heading towards `control1`, and arrives at `end` coming from the direction of `control2`.
The further away a control point is, the more strongly it pulls the curve. The curve passes through
`start` and `end`, but not through the control points.

- `canvas.bezier(start, control1, control2, end)` draws one with the stroke, and draws nothing while
  the stroke is off.
- Equal steps of `t` give unevenly spaced points along a Bézier curve (see [Points along a
  curve](#points-along-a-curve)), so use `at_distance(d)` to move along it at a steady speed.
- `closest_point` is exact, apart from the tiny rounding errors of any calculation.

## `Spline`

A spline is a smooth curve through every one of a list of `points`, in order, such as a path for an
enemy to patrol or a road through a landscape. Unlike a Bézier curve, it passes through every point
you give it, so it is the easier one to shape by hand. (Mathematicians call this kind a Catmull-Rom
spline.) `closed=True` carries it on from the last point back to the first, for a loop.

- `alpha` sets how the curve bends between its points: 0 (uniform) can overshoot into small loops
  where points bunch together, 0.5 (centripetal, the default) never loops, and 1 (chordal) swings
  wider round the points.
- It has the same methods for points along it as `Bezier`. `t` is shared out evenly between the
  stretches from one point to the next, so with five stretches, `t = 0.2` is at the second point,
  however long the stretches are.
- `beziers()` converts it exactly into Bézier curves, one per stretch, and `canvas.spline` draws
  those as one unbroken stroke.

## The `Curve` trait

The four curves conform to **`Curve`**, as well as to `Shape` (see
[Shapes](shapes.md#the-shape-and-region-traits)), so a function can take any of them (`def f[C:
Curve](curve: C)`). `Curve` gives `at`, `tangent`, `length`, `at_distance`, `flatten` and `beziers`.
`move_to` exists only on `Line` (moving its midpoint) and `Arc` (moving its centre), and `split`
only on `Line`, `Arc` and `Bezier`.
