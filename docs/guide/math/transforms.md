# Transforms

A transform describes a change of position that can be applied to every point of a drawing at once:
moving it, turning it, making it bigger or smaller, mirroring it or any combination of those. This
page explains what a transform does, the two ways to use one (the canvas's `translate`, `rotate` and
`scale`, and the `Transform` value), how transforms combine, and how to move a single point by hand.
It assumes no prior knowledge of transforms or matrices.

## What a transform does

Imagine drawing a house on a sheet of tracing paper, then sliding the paper, turning it and holding
it up to a magnifying glass. The house is drawn exactly as before, but it appears somewhere else, at
an angle, and larger. A transform is that movement of the tracing paper. It takes any point and says
where it ends up.

Three movements make up nearly every transform:

- **Moving**, or *translating*: sliding the paper without turning it. Every point moves the same
  distance in the same direction.
- **Turning**, or *rotating*: spinning the paper round a pin stuck through the origin. Positive
  angles turn counter-clockwise, in radians (see [Angles](angles.md)).
- **Scaling**: making the drawing bigger or smaller, from the origin. Scaling by 2 doubles every
  distance from the origin; scaling by a negative number also mirrors the drawing.

## Transforming what you draw

The canvas has one call for each movement. Each one applies to everything drawn after it:

| Call | What it does to what is drawn next |
|---|---|
| `canvas.translate(delta)` | Moves it by the vector `delta` |
| `canvas.rotate(angle)` | Turns it counter-clockwise by `angle` radians, round the origin |
| `canvas.scale(s)` | Makes it `s` times as big, from the origin |
| `canvas.scale(sx, sy)` | Stretches it by `sx` across and `sy` up and down; a negative value mirrors |

Like the style, a transform set this way lasts until the end of the frame. Usually you want it to
last only while you draw one thing, so wrap the drawing in `with canvas.transform():`. The block
keeps the transform as it was, and puts it back when the block ends, whatever was changed inside:

```mojo
# In `update`: a square turned an eighth of a turn, then one that isn't.
with canvas.transform():
    canvas.translate(Vector(100, 0))
    canvas.rotate(PI / 4)
    canvas.rectangle((0, 0), 50, 50)  # turned, at (100, 0)
canvas.rectangle((0, 0), 50, 50)  # upright, at the origin
```

**Each call applies inside the ones before it.** Above, `translate` moves the origin to `(100, 0)`,
and `rotate` then turns the drawing round that new origin, so the square turns in place at `(100,
0)`. Swap the two calls and the order changes the result: turning first, then moving along the
turned x axis, swings the square round the old origin, like a stone on a string:

```mojo
# In `update`:
var angle = context.time.elapsed
with canvas.transform():
    canvas.translate(Vector(100, 0))
    canvas.rotate(angle)
    canvas.rectangle((0, 0), 40, 40)  # spins in place at (100, 0)
with canvas.transform():
    canvas.rotate(angle)
    canvas.translate(Vector(100, 0))
    canvas.rectangle((0, 0), 40, 40)  # circles the origin at a distance of 100
```

So the usual order for placing something is: move to where it goes, turn it, then scale it.

**Blocks nest**, and a block inside another starts from the transform around it. That is the way to
draw a thing made of parts that move together, such as a car whose wheels turn as it drives:

```mojo
# In `update`, with `car_position: Point` and `wheel_angle: Float64` fields:
with canvas.transform():
    canvas.translate(Vector(self.car_position))
    canvas.rectangle((0, 20), 120, 40)  # the body
    for x in [-40.0, 40.0]:
        with canvas.transform():
            canvas.translate(Vector(x, 0))
            canvas.rotate(self.wheel_angle)
            canvas.rectangle((0, 0), 24, 24)  # a wheel, spinning round its own centre
```

If you know Processing, these are its `translate`, `rotate` and `scale`, in the same order, and
`with canvas.transform():` is its `pushMatrix()` and `popMatrix()`.

## Transforms as values

A `Transform` is a transform kept as a value, to store in a field, pass to a function or use more
than once. Build one from its parts:

```mojo
# In `update`:
var placed = Transform(translation=Vector(100, 0), rotation=PI / 4, scale=2)
var stretched = Transform(scale_x=2, scale_y=0.5)
```

The parts apply in a fixed order, the usual one for placing something: **scaled first, then turned,
then moved**. So `placed` doubles a drawing's size, turns it an eighth of a turn, then moves it to
`(100, 0)`. Every part can be left out: `Transform()` changes nothing at all.

`with canvas.transform(t):` draws the block through the transform `t`, applied inside the current
one, and puts the current one back when the block ends:

```mojo
# In `update`, with a `placed: Transform` field:
with canvas.transform(self.placed):
    canvas.rectangle((0, 0), 50, 50)
```

## Combining transforms

`a @ b` combines two transforms into one that does both. **The one on the right happens first.** So
`a @ b` moves a point by `b`, then moves the result by `a`. Combining is how to build a transform
the constructor can't, such as turning round a point other than the origin:

```mojo
# In `update`: turn by `angle` round the point `pivot`.
var to_origin = Transform(translation=Vector(-pivot.x, -pivot.y))
var back = Transform(translation=Vector(pivot))
var turn_round_pivot = back @ Transform(rotation=angle) @ to_origin
```

Read from right to left, it moves the pivot to the origin, turns round it, and moves it back.
Combining with `@` and calling the canvas methods give the same results: `canvas.rotate(a)` changes
the canvas's current transform `t` to `t @ Transform(rotation=a)`.

## Moving points by hand

A transform on the canvas changes what is drawn, but sometimes you need to know where a point ends
up, such as the tip of a turning cannon, to fire a shot from it. `t.apply(point)` gives the point
moved by `t`, and `t.apply(vector)` gives a vector changed by its turning and scaling only. A vector
is a movement rather than a place, so the translation doesn't move it (see [Points and
vectors](points-and-vectors.md)):

```mojo
# In `update`, with `base: Vector` and `aim: Float64` fields:
var cannon = Transform(translation=self.base, rotation=self.aim)
var tip = cannon.apply(Point(60, 0))  # the end of a barrel 60 long, pointing along +x
var direction = cannon.apply(Vector.RIGHT)  # the way the barrel points
```

`t.inverse()` is the transform that undoes `t`: it moves every point back to where it started. It
answers the opposite question, such as where on the turning cannon the mouse is pointing. A
transform that squashes everything flat, such as `scale=0`, can't be undone, and its inverse holds
meaningless numbers. `canvas.to_local(context.mouse.position)` does this for you inside a transform,
using the inverse of the current transform and the camera (see
[Coordinates](../basics/coordinates.md#screen-world-and-local-space)).

## Inside a transform

You don't need this part to use transforms, but it explains the numbers inside one. A transform is
six numbers, `a` to `f`. A point `(x, y)` is moved to:

```text
x' = a·x + b·y + c
y' = d·x + e·y + f
```

The numbers `a`, `b`, `d` and `e` turn, scale, mirror and shear the point, and `c` and `f` move it.
Written as a grid, with the point as a column, the six numbers are the top two rows of a 3 by 3
**matrix**:

```text
| a  b  c |   | x |   | a·x + b·y + c |
| d  e  f | × | y | = | d·x + e·y + f |
| 0  0  1 |   | 1 |   |       1       |
```

The extra 1 below the point, and the bottom row of `0 0 1`, are what let one grid both turn and move
a point. A transform's bottom row is always `0 0 1`, which is what makes it *affine*: straight lines
stay straight, and parallel lines stay parallel. `a @ b` multiplies the two grids, which is how
combining works.

## Matrices

A `Matrix` is a grid of numbers of any size, for maths beyond moving a drawing, such as solving
equations or working in more than two dimensions. `Matrix[2, 2](1, 2, 3, 4)` builds one from its
numbers, row by row; `m[row, column]` reads one, counting from 0. `a @ b` multiplies two matrices,
`m.transpose()` swaps the rows and the columns, `identity[N]()` is the N by N matrix that changes
nothing, and `inverse(m)` the one that undoes `m`.

A transform and a 3 by 3 matrix hold the same kind of numbers, so each converts to the other, but
only when you ask, as a `Point` and a `Vector` do:

- `Matrix[3, 3](t)` is the transform `t`'s full grid, with its bottom row `0 0 1`.
- `Transform(m)` is the transform the 3 by 3 matrix `m` describes. It raises an error if `m`'s
  bottom row isn't `0 0 1`: such a matrix is a perspective transform, which a `Transform` can't
  hold.

A matrix gives you every number to set, so it can build a transform the constructor can't, such as a
shear, which slants a drawing sideways:

```mojo
# In `update`: lean everything to the right, half a unit across for each unit up.
var shear = Transform(Matrix[3, 3](1, 0.5, 0, 0, 1, 0, 0, 0, 1))
with canvas.transform(shear):
    canvas.rectangle((0, 0), 60, 60)
```
