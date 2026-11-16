# translate

```mojo
def translate(dx: Float64, dy: Float64) -> Matrix[Int(3), Int(3)]
```

Move by `(dx, dy)` in world units. `dy` is up, since y grows upward.

```mojo
def translate(delta: Vector2D) -> Matrix[Int(3), Int(3)]
```

Move by `delta` in world units, as `shape.translate(delta)` does.
