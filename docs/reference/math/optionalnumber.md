# OptionalNumber

```mojo
struct OptionalNumber
```

A number that may be left out: any integer or `Float64`, or `None`.

It is the type of Create's number keywords, such as `stroke_thickness=`,
`font_size=`, `blur=` and `corner_radius=`, so each of `blur=12`,
`blur=1.5`, `blur=n` with an `Int` or `Float64` variable, and
`blur=None` works. A program passes a number and never names the type.

`Optional[Float64]` can't take the place of it: an integer literal such
as `12` doesn't become an `Optional[Float64]`, since that would take two
conversions, to `Float64` and then to `Optional`, and Mojo makes only one.
`OptionalNumber` takes each kind of number in one step.

Use it for a number keyword of your own that is left out by default:

```mojo
# A helper that draws a ring, 2 thick unless told otherwise:
def ring(mut canvas: Canvas, at: Point, thickness: OptionalNumber = None):
    var width = thickness.or_else(2)
    with canvas.style(stroke=Color.BLACK, stroke_thickness=width):
        canvas.circle(at, 40)
```

Read it as you would an `Optional`: it is true when a number was given,
`value()` is the number, and `or_else(default)` is the number, or
`default` when none was given.

Implements `Boolable`, `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Float64)
@staticmethod
def __init__(out self, value: Int)
@staticmethod
def __init__(out self, value: IntLiteral)
@staticmethod
def __init__(out self, value: Number)
@staticmethod
def __init__(out self, value: Optional[Float64])
@staticmethod
def __init__(out self, none: None)
```

## Methods

### `value`

```mojo
def value(self) -> Float64
```

The number. Only call it when one was given.

### `or_else`

```mojo
def or_else(self, default: Number) -> Float64
```

The number, or `default` when none was given.

## Special methods

### `__bool__`

```mojo
def __bool__(self) -> Bool
```

Whether a number was given.
