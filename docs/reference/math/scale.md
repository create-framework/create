# scale

```mojo
def scale(sx: Float64, sy: Float64) -> Matrix[Int(3), Int(3)]
```

Scale each axis about the origin. Negative values mirror.

```mojo
def scale(s: Float64) -> Matrix[Int(3), Int(3)]
```

Scale both axes by the same factor.
