# lerp

```mojo
def lerp(a: Number, b: Number, t: Number) -> Float64
```

Blend from `a` to `b`, `t` running 0 to 1. Not clamped: `t` outside that range extrapolates past either end.
