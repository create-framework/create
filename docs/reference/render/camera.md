# Camera

```mojo
struct Camera
```

What part of world space maps onto the screen.

`position` is the world point centred on screen; `zoom` scales around it
(1.0 = no scaling). A field the program owns and moves on its own
schedule — like `Image` or `Tween` — not something the run loop writes.
`canvas.camera(camera)` applies it to every render call from that point on;
the default identity camera behaves exactly like no camera at all.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `position: Point`
- `zoom: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self, position: Point = Point(SIMD(0), SIMD(0)), zoom: Float64 = 1)
```

## Methods

### `matrix`

```mojo
def matrix(self) -> Matrix[Int(3), Int(3)]
```

World-to-screen mapping: scale around `position`, then recentre.

### `to_world`

```mojo
def to_world(self, screen: Point) -> Point
```

A screen-space point — `context.mouse.position`, say — into world space.

The inverse of `matrix()`, done in arithmetic rather than through a
general matrix inverse.

### `to_screen`

```mojo
def to_screen(self, world: Point) -> Point
```

A world-space point into screen space.
