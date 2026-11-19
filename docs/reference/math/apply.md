# apply

```mojo
def apply(m: Matrix[Int(3), Int(3)], point: Point) -> Point
```

`point` mapped through `m`, translation included.

```mojo
def apply(m: Matrix[Int(3), Int(3)], vector: Vector) -> Vector
```

`vector` mapped through `m`'s rotation, scale and shear, but not its translation: a displacement, unlike a position, is the same wherever it starts. So a velocity turns with a `rotate` and stretches with a `scale`, and a `translate` leaves it as it is. Meant for the affine matrices `translate`, `rotate` and `scale` build; a projective bottom row is ignored.
