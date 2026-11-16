# Gradient

```mojo
struct Gradient
```

A smooth run of colours across a shape's fill, or across the background.

```mojo
var sky = Gradient.linear(Color.hex(0x0B1D3A), Color.hex(0xF4A261))
canvas.background(sky)
canvas.fill(Gradient.radial(Color.WHITE, Color.WHITE.with_alpha(0)))
canvas.circle((0, 0), 80)
```

**Placed by the shape, not the world.** A gradient spans the bounding box
of the shape it fills, in the shape's own coordinates, so it moves and
turns with the shape and one `Style` looks the same on every entity.

- `linear` runs along `direction`, top to bottom by default. The line is
  just long enough for the box's two farthest corners to land exactly on
  the first and last stop, as in CSS.
- `radial` runs out from `center`, given in the box's own unit space
  (`(0, 0)` its middle, `(1, 1)` its top-right corner), to the box's
  edges: a circle on a square box, an ellipse on a long one. Its size
  stays put when `center` moves.

**Stops** are positions from 0 to 1, each with a colour. Given only
colours, they are spaced evenly; given `(position, colour)` pairs, each
position is clamped to 0..1 and to no less than the stop before it.
Before the first stop and after the last, the end colours carry on.
Colours blend premultiplied, so a fade to `Color.TRANSPARENT` doesn't
pass through grey.

A zero `direction` has no line to run along, and a box with no width (or
height) has nothing to span, so the gradient paints its first stop.
`direction` is kept as given, so `==` and printing round-trip.

Copying one is cheap: the stops are shared, never changed after
construction.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `direction: Vector2D`: `linear` only: which way the colours run, first stop to last.
- `center: Point2D`: `radial` only: where the first stop sits, in the box's unit space.

## Constructors

### `linear`

```mojo
@staticmethod
def linear(first: Color, *rest: Color, *, direction: Vector2D = Vector2D.DOWN) -> Self
```

Evenly spaced colours along `direction`; one colour is a solid.

```mojo
@staticmethod
def linear(
    stops: List[Tuple[Float64, Color]],
    *,
    direction: Vector2D = Vector2D.DOWN,
) -> Self
```

Colours at the given positions along `direction`: `Gradient.linear([(0.0, Color.BLUE), (0.7, Color.PURPLE), (1.0, Color.ORANGE)])`.

### `radial`

```mojo
@staticmethod
def radial(
    first: Color,
    *rest: Color,
    *,
    center: Point2D = Point2D(SIMD(0), SIMD(0)),
) -> Self
```

Evenly spaced colours out from `center` to the box's edges.

```mojo
@staticmethod
def radial(
    stops: List[Tuple[Float64, Color]],
    *,
    center: Point2D = Point2D(SIMD(0), SIMD(0)),
) -> Self
```

Colours at the given positions out from `center` to the box's edges.

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
