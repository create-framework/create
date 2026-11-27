# smoothstep

```mojo
def smoothstep(edge0: Number, edge1: Number, x: Number) -> Float64
```

Like `inverse_lerp`, but clamped to 0..1 and eased at both ends: the usual choice for a transition that should not start or stop abruptly.
