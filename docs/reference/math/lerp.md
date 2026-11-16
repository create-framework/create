# lerp

```mojo
def lerp(a: Float64, b: Float64, t: Float64) -> Float64
```

Blend from `a` to `b`, `t` running 0 to 1. Not clamped: `t` outside that range extrapolates past either end.
