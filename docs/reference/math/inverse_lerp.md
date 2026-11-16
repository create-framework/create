# inverse_lerp

```mojo
def inverse_lerp(value: Float64, low: Float64, high: Float64) -> Float64
```

Where `value` sits in `[low, high]` as a 0-to-1 fraction. The inverse of `lerp`, and `map` with a 0..1 output range.
