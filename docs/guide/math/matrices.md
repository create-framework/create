# Matrices

A matrix describes a change of position that can be applied to every point of a drawing at once:
moving it, turning it, making it bigger or smaller, mirroring it, or any combination of those.
`canvas.transform` takes one, and draws everything inside its block changed by it. This page
explains what a matrix does, how to build one, and how to combine them, without assuming prior
knowledge of matrices.

## What a matrix does

Imagine drawing a house on a sheet of tracing paper, then sliding the paper, turning it and holding
it up to a magnifying glass. The house is drawn exactly as before, but it appears somewhere else, at
an angle, and larger. A matrix is that movement of the tracing paper, written as numbers. It takes
any point and says where it ends up.

You rarely need to look at the numbers inside a matrix. Create builds them for you:

| Function | What the matrix does |
|---|---|
| `translate(dx, dy)`, `translate(vector)` | Moves everything by `(dx, dy)`, or by the vector |
| `rotate(angle)` | Turns everything counter-clockwise by `angle` radians, round the origin (see [Angles](angles.md)) |
| `scale(s)` | Makes everything `s` times as big, from the origin |
| `scale(sx, sy)` | Stretches everything by `sx` across and `sy` up and down; a negative value mirrors |
| `identity[3]()` | Changes nothing at all |

```mojo
# In `update`: a square drawn twice as big and turned an eighth of a turn.
with canvas.transform(rotate(PI / 4) @ scale(2)):
    canvas.rectangle((0, 0), 50, 50)
```

## Combining matrices

`a @ b` combines two matrices into one that does both. **The one on the right happens first.** So
`translate(100, 0) @ rotate(angle)` first turns the drawing, then moves it, while `rotate(angle) @
translate(100, 0)` first moves it, then turns it:

```mojo
# In `update`:
var angle = context.time.elapsed
with canvas.transform(translate(100, 0) @ rotate(angle)):
    canvas.rectangle((0, 0), 40, 40)  # spins in place at (100, 0)
with canvas.transform(rotate(angle) @ translate(100, 0)):
    canvas.rectangle((0, 0), 40, 40)  # circles the origin at a distance of 100
```

The order matters because turning and scaling always happen round the origin. Turning first spins
the square round its own centre, which is still at the origin, and then moves it out to `(100, 0)`.
Moving first takes the square out to `(100, 0)`, and turning then swings it round the origin, like a
stone on a string.

So the usual order for placing something is to read it from right to left: scale it, then turn it,
then move it into place, `translate(position) @ rotate(angle) @ scale(size)`.

**Nesting** `canvas.transform` blocks combines them too: a block inside another is changed by both,
the inner one applying first, as if the two matrices were combined with `@`. That makes it easy to
draw a thing made of parts that move together, such as a car whose wheels turn as it drives:

```mojo
# In `update`, with a `car_position: Point2D` field: the car moves, and each
# wheel turns within it.
with canvas.transform(translate(Vector2D(self.car_position))):
    canvas.rectangle((0, 20), 120, 40)  # the body
    for x in [-40.0, 40.0]:
        with canvas.transform(translate(x, 0) @ rotate(self.wheel_angle)):
            canvas.rectangle((0, 0), 24, 24)  # a wheel, spinning round its own centre
```

## Moving points by hand

`canvas.transform` changes what is drawn, but sometimes you need to know where a point ends up, such
as the tip of a turning cannon, to fire a shot from it. `apply(m, point)` gives the point moved by
the matrix, and `apply(m, vector)` gives a vector changed by its turning and scaling only. A vector
is a movement rather than a place, so a translation doesn't move it:

```mojo
var cannon = translate(self.base) @ rotate(self.aim)
var tip = apply(cannon, Point2D(60, 0))  # the end of a barrel 60 long, pointing along +x
var direction = apply(cannon, Vector2D.RIGHT)  # the way the barrel points
```

`inverse(m)` is the matrix that undoes `m`: it moves every point back to where it started. It
answers the opposite question, such as where on the turning cannon the mouse is pointing.
`canvas.to_local(context.mouse.position)` does this for you inside a `canvas.transform` block, using
the inverse of the current transform and the camera (see
[Coordinates](../basics/coordinates.md#screen-world-and-local-space)).

## Inside a matrix

You don't need this part to use matrices, but it explains what the numbers are. A `Matrix[3, 3]` is
a grid of nine numbers, three rows of three. A point `(x, y)` is moved by multiplying the grid by
the column `(x, y, 1)`:

```text
| a  b  c |   | x |   | a·x + b·y + c |
| d  e  f | × | y | = | d·x + e·y + f |
| 0  0  1 |   | 1 |   |       1       |
```

The new x is `a·x + b·y + c`, and the new y is `d·x + e·y + f`. The numbers `a`, `b`, `d` and `e`
turn, scale and shear the point, and `c` and `f` move it. The extra 1, and the bottom row of `0 0
1`, are what let a single grid both turn and move a point; that is why a 2D transform is a 3 by 3
matrix rather than 2 by 2. `@` multiplies two grids, which is how combining two matrices works.

`m[row, column]` reads one number, counting from 0. `Matrix[3, 3](...)` builds a matrix from nine
numbers, row by row, for a transform the functions above don't build, such as a shear.