# wrap

```mojo
def wrap(value: Number, period: Number) -> Float64
```

`value` wrapped into `[0, period)`. Floored, so a negative `value` wraps forward instead of staying negative: what an angle or a scrolling offset wants.
