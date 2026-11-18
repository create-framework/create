# Collisions

A game needs to know when things touch: when the player reaches a coin, when a ball hits a wall,
when a laser crosses an enemy. Create's shapes answer this with tests that say yes or no. This page
explains the three tests, how exact they are, and a few ways to use them.

## The three tests

Three tests answer whether shapes touch. A circle following the mouse turns red against the wall and
orange on the laser:

```mojo
from create import *


@fieldwise_init
struct Collisions(Program):
    var wall: Rectangle
    var laser: Line

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Collisions:
        return Collisions(
            Rectangle((200, 0), 40, 300), Line((-400, 100), (400, 100))
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.fill(Color.GRAY)
        canvas.draw(self.wall)
        canvas.stroke(Color.BLUE, 4)
        canvas.draw(self.laser)

        var player = Circle(context.mouse.position, 30)
        canvas.stroke(Color.BLACK, 1)
        if player.overlaps(self.wall):  # two regions touch
            canvas.fill(Color.RED)
        elif self.laser.intersects(player):  # a curve crosses a shape
            canvas.fill(Color.ORANGE)
        else:
            canvas.fill(Color.GREEN)
        canvas.draw(player)

        if self.wall.contains(context.mouse.position):  # a point is inside a region
            context.cursor(Cursor.HAND)
        else:
            context.cursor(Cursor.ARROW)


def main() raises:
    run[Collisions]("Collisions")
```

- **`region.overlaps(other)`** asks whether two regions (`Rectangle`, `Circle`, `Ellipse`,
  `Capsule`, `Triangle`, `Sector`, `Polygon`) share any point. It works both ways round:
  `a.overlaps(b)` and `b.overlaps(a)` always agree.
- **`curve.intersects(x)`** asks whether a curve (`Line`, `Arc`, `Bezier`, `Spline`) crosses or
  touches `x`, which can be any shape or a `Point2D`. It is a method of curves only, since crossing
  is all a curve can do: write `line.intersects(circle)`, not the other way round.
- **`region.contains(x)`** asks whether `x`, which can be a point, region or curve, lies wholly
  inside the region. It works one way only: a big circle can contain a small one, but not the other
  way round.

A curve has no inside, so `overlaps` never takes a `Line`; use `intersects` instead. All three tests
take a shape's rounded corners into account.

**How exact are they?** Tests involving a `Line` or an `Arc` are exact. A `Bezier` or `Spline` is
tested as a chain of very short straight lines that follow it to within a ten-thousandth of its
size. So a crossing is always found. Whether a curve just grazes a shape or just misses it is
decided only to within that distance, which is far finer than anything visible. A region's
`contains` treats an `Arc`, `Bezier` or `Spline` inside it the same way.

## Moving shapes

The shapes are plain values, so a moving thing's collider is usually built fresh each frame, at the
thing's current position, as the player's circle is in the example above. To move a shape you keep
in a field, use `translate(delta)`, which moves it by a vector, or `move_to(point)`, which puts its
centre on a point; both return the moved shape.

**Fast objects can skip through thin walls.** A ball moving 30 units a frame can be on one side of a
10-unit wall in one frame and past it in the next, without its circle ever overlapping the wall. A
[`Capsule`](shapes.md#capsule) from where the ball was last frame to where it is now, with the
ball's radius, covers every point the ball passed through. Testing the capsule instead of the circle
catches the hit:

```mojo
# In `update`, with `position`, `velocity` and `radius` fields:
var previous = self.position
self.position = self.position + self.velocity * context.time.delta
if Capsule(previous, self.position, self.radius).overlaps(self.wall):
    self.position = previous  # stop where it was, before the wall
    self.velocity = Vector2D.ZERO
```

## Distances

The tests only say whether shapes touch. To know how far apart a point and a shape are, use
`closest_point`, which every shape has: `shape.closest_point(p)` is the point of the shape nearest
`p`, and `p` itself when `p` is inside a region. So the distance is:

```mojo
var distance = point.distance(shape.closest_point(point))  # 0 inside the shape
```

That is useful for things that should react before they touch, such as a door that opens once the
player is within 200 units of it, or a magnet pulling coins towards the player.