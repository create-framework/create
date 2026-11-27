# ease

```mojo
def ease(curve: Easing, t: Number) -> Float64
```

Reshape the fraction `t` by `curve`.

`t` is clamped to 0..1 first, unlike `lerp`, easing does not extrapolate.
The curves are not linear, so an out-of-range input does not continue the
motion sensibly: `IN_EXPO` at `t = 2.0` would return 1024.

The `BACK` and `ELASTIC` curves deliberately leave 0..1 in the *middle* of
their run, overshooting the target before settling. Anything consuming the
result as a colour channel or an index has to clamp it.
