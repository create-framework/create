# Text

```mojo
struct Text
```

A piece of text placed in the world, to draw with `canvas.draw`.

`canvas.draw(Text("Score", (0, 200)))` draws what
`canvas.text("Score", (0, 200))` draws: the text at `position`, anchored
by the style's `text_alignment`, in its font, size and text colour. As a
value it can be kept in a field and be one part of a `Drawable` of your
own, beside the shapes it is drawn with:

```mojo
@fieldwise_init
struct Badge(Drawable):
    var plate: Rectangle
    var text: Text

    def draw_to(self, mut canvas: Canvas):
        canvas.draw(self.plate)
        with canvas.style(text_color=Color.WHITE):
            canvas.draw(self.text)
```

Given a `width`, the text wraps onto as many lines as keep each at most
that wide, as `canvas.text(text, position, width)` does.

Its size depends on the font it is drawn in, which belongs to the
style, so it has no `bounds` of its own: `canvas.bounds(text)` measures
it in the style it is drawn in.

Implements `Copyable`, `Deinitable`, `Drawable`, `Equatable`, `Movable`, `Writable`.

## Fields

- `value: String`: The text drawn.
- `position: Point`: Where it is anchored, by the style's `text_alignment`.
- `width: Optional[Float64]`: The width it wraps at, or `None` to break only at newlines.

## Constructors

```mojo
@staticmethod
def __init__(out self, value: String, position: Point, width: OptionalNumber = None)
```

## Methods

### `move_to`

```mojo
def move_to(self, position: Point) -> Self
```

The text anchored at `position` instead; this one is unchanged.

### `translate`

```mojo
def translate(self, delta: Vector) -> Self
```

The text moved by `delta`; this one is unchanged.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```
