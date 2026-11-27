# map

```mojo
def map(
    value: Float64,
    in_low: Float64,
    in_high: Float64,
    out_low: Float64,
    out_high: Float64,
) -> Float64
```

Re-scale `value` from one range onto another: a slider position to a world coordinate, say. Linear and unclamped.
