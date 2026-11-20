# TypeStyle

```mojo
struct TypeStyle
```

How one kind of text looks: its size, its weight and its font, or the canvas's default font when `font` is `None`.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `size: Float64`
- `weight: FontWeight`
- `font: Optional[Font]`
