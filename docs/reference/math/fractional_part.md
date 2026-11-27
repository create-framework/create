# fractional_part

```mojo
def fractional_part(x: Number) -> Float64
```

The part after the decimal point, always positive: `fractional_part(-0.25)` is 0.75, since it floors rather than truncating.
