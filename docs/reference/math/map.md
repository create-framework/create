# map

```mojo
def map(
    value: Number,
    in_low: Number,
    in_high: Number,
    out_low: Number,
    out_high: Number,
) -> Float64
```

Re-scale `value` from one range onto another: a slider position to a world coordinate, say. Linear and unclamped.
