# wrap

```mojo
def wrap(value: Float64, period: Float64) -> Float64
```

`value` wrapped into `[0, period)`. Floored, so a negative `value` wraps forward instead of staying negative: what an angle or a scrolling offset wants.
