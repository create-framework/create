# Number

```mojo
struct Number
```

A number given to Create: any integer or `Float64`.

It is the type of Create's number parameters, such as a circle's
`radius` or `lerp`'s `t`, so each of `12`, `1.5`, an `Int` variable and a
`Float64` variable can be passed where a number is asked for. A
`Float64` parameter takes a literal such as `12`, but not an `Int`
variable: `canvas.circle((x, 0), i * 5)` in a loop over `range` needs
`Number`. A program passes a number and never names the type.

Create takes numbers as `Number` and gives them back as `Float64`, so
what comes out of the library, such as `canvas.width()` or a shape's
`radius`, is a plain number to calculate with.

Use it for a number parameter of your own, and `Float64(n)` to read it:

```mojo
# A helper that draws a square of the given size:
def square(mut canvas: Canvas, at: Point, size: Number):
    canvas.rectangle(at, size, size)
    print(Float64(size) * 2)
```

A number that may be left out is an `OptionalNumber`.

Implements `Copyable`, `Deinitable`, `Floatable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `TrivialRegisterPassable`, `Writable`.

## Constructors

```mojo
@staticmethod
def __init__(value: Float64) -> Self
@staticmethod
def __init__(value: Int) -> Self
@staticmethod
def __init__(value: IntLiteral) -> Self
```

## Special methods

### `__float__`

```mojo
def __float__(self) -> Float64
```

The number, read with `Float64(n)`.
