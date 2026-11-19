# Points and vectors

A position on the screen, and a movement across it, are both written as two numbers, an x and a y,
measured in Create's [coordinates](../basics/coordinates.md). But they are different things: a
position says *where*, and a movement says *which way and how far*. Create gives each its own type,
`Point` for positions and `Vector` for movements. This page explains what points and vectors are,
why the two types are kept apart and how to calculate with them. It assumes no prior knowledge of
vectors.

## Locations, displacements and extents

Positions, movements and sizes each have their own kind of value:

- A **location** is a `Point`: where something is. `canvas.circle(position, radius)` takes one, and
  `context.mouse.position` is one.
- A **displacement** is a `Vector`: a movement, with a direction and a length, but no particular
  starting place. "Three units right and four up" is a vector; so is a velocity, such as "100 units
  a second towards the top-right".
- An **extent** is a plain number: a `width`, a `height` or a `radius`.

Think of a treasure map. "The old oak tree" is a point: a place. "Ten paces north" is a vector: an
instruction that can be followed from anywhere. Following it from the oak tree takes you to a new
place, another point.

## Calculating with them

The sums that make sense between points and vectors are the ones that make sense on the map:

| Sum | Result | Meaning |
|---|---|---|
| point + vector | point | Moving from a place: the oak tree, then ten paces north |
| point − vector | point | Moving back the other way |
| point − point | vector | How to get from the second place to the first |
| vector + vector | vector | Two movements, one after the other |
| vector × number | vector | A movement made longer or shorter: ten paces is twice five paces |

```mojo
# In `create`, building the `position` and `velocity` fields:
var position = Point(0, 0)
var velocity = Vector.from_angle(PI / 4, 100)  # 100 units a second, up and to the right

# In `update`:
self.position = self.position + self.velocity * context.time.delta  # a point moved by a vector
var to_mouse = context.mouse.position - self.position  # point minus point is a vector
```

Adding two points, on the other hand, means nothing: "the oak tree plus the old well" isn't a place.
So `Point` doesn't allow it, and the mistake is caught when the program is compiled rather than
showing up as a shape in the wrong place. For the same reason, a `Point` has none of the vector
operations below, such as `magnitude` or `normalize`: a place has no length or direction.

When you really do need to cross between the two, say so with a constructor: `Vector(p)` is the
movement from the origin to the point `p`, and `Point(v)` is where the movement `v` takes you from
the origin.

## Writing them

A point can be written as a bare pair of numbers wherever a `Point` is expected, so
`canvas.circle((0, 0), 20)` works without naming the type. A vector always names its type:
`Vector(1, 2)`. Only points are written as bare pairs, so a pair is never ambiguous.

Mind one consequence: `p + Vector(1, 2)` moves `p`, but `p - (1, 2)` subtracts a *point*, since a
pair can only be a point. So it gives the vector from `(1, 2)` to `p`. To move `p` back, write `p -
Vector(1, 2)`.

Common vectors have names: `Vector.ZERO` (no movement), `ONE` (`(1, 1)`), and the four directions
`UP`, `DOWN`, `LEFT` and `RIGHT`, each 1 long. Since y increases upwards, `UP` is `(0, 1)` and
`DOWN` is `(0, -1)`.

## Length and direction

Every vector has a **length**, how far it moves, and a **direction**, which way:

- `v.magnitude()` is the vector's length. The vector `(3, 4)` is 5 long, by Pythagoras' theorem.
- `v.normalize()` is the vector with the same direction, but 1 long. It is the way to keep only the
  direction, such as "towards the mouse", and then give it a length of your own.
- `v.with_length(l)` is the vector with the same direction and length `l`.
- `v.limit(max)` is the vector made shorter if it is longer than `max`, and left as it is otherwise:
  the usual way to cap a speed.

```mojo
# In `update`: move towards the mouse at 200 units a second.
var to_mouse = context.mouse.position - self.position
if to_mouse.magnitude() > 1:
    self.position = self.position + to_mouse.with_length(200) * context.time.delta
```

Distances between points have their own method: `a.distance(b)` is how far apart two points are, the
same as `(b - a).magnitude()`.

The `_squared` versions, `magnitude_squared()` and `distance_squared(b)`, skip a square root, so
they are a little faster. They are handy for comparing distances, since a distance is smaller than
another exactly when its square is: `a.distance_squared(b) < 100 * 100` asks whether `a` and `b` are
less than 100 apart.

## Angles

A vector's direction can also be given as an angle, in radians, counter-clockwise from the positive
x axis (see [Angles](angles.md)):

- `Vector.from_angle(angle, length)` builds a vector pointing at `angle`, `length` long (1 if you
  leave it out). `from_angle(0)` is `RIGHT`, and `from_angle(PI / 2)` is `UP`.
- `v.angle()` is the angle a vector points at.
- `v.rotate(angle)` is the vector turned by `angle`, counter-clockwise.

```mojo
# In `update`: a spaceship that turns with the arrow keys and thrusts forward with Up.
if context.keyboard.down(Key.LEFT):
    self.heading += 3 * context.time.delta
if context.keyboard.down(Key.RIGHT):
    self.heading -= 3 * context.time.delta
if context.keyboard.down(Key.UP):
    self.velocity += Vector.from_angle(self.heading, 400 * context.time.delta)
self.position = self.position + self.velocity * context.time.delta
```

## The dot product

`a.dot(b)`, the **dot product**, measures how much two vectors point the same way. For two vectors
of length 1, it is 1 when they point the same way, 0 when they are at right angles, and -1 when they
point in opposite directions. So it answers questions such as whether an enemy is in front of the
player or behind:

```mojo
# In `update`, with `heading` and `position` fields and an `enemy`:
var facing = Vector.from_angle(self.heading)
var to_enemy = (enemy.position - self.position).normalize()
if facing.dot(to_enemy) > 0.7:  # within about 45° either side of straight ahead
    self.spot(enemy)
```

## Between two values

`a.lerp(b, t)` is the point, or the vector, a fraction `t` of the way from `a` to `b`: 0 is `a`, 1
is `b` and 0.5 halfway between them. It is the way to move something smoothly from one place to
another, and is explained in [Interpolation](interpolation.md).

## Every method returns a new value

None of these methods changes the point or vector it is called on: each returns a new one. So
`v.normalize()` on its own does nothing useful; write `v = v.normalize()` to keep the result. The
same holds for every value in Create, shapes and colours included.

`p.xy()` and `v.xy()` give the two numbers as a pair, to unpack: `var (x, y) = p.xy()`.
