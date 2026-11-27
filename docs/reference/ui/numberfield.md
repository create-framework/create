# NumberField

```mojo
struct NumberField
```

A number between `minimum` and `maximum`, typed into a field or stepped with the − and + buttons beside it, such as a count of players or a volume in whole percent.

```mojo
# In `create`, building the `players` field:
var players = NumberField(2, 1, 8, Rectangle((0, 0), 220, 40))

# In `update`:
self.players.update(context, canvas)
canvas.draw(self.players)
if self.players.changed():
    self.seats = Int(self.players.value)
```

Typing works as in a `TextField`. What was typed becomes the value on
Enter, or when the field loses focus: kept within the range and rounded
to `decimals` places. Text that isn't a number puts the value back as
it was. The − and + buttons step the value by `step`, and so do the up
and down arrows while the field has focus, and a gamepad's push in a
`UI`.

Its parts: `container` and `text_style` are the field's, as a text
field's are, and `buttons` is the style of both buttons, as a button's
`style` is.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Fields

- `value: Float64`: The number. Set it to change it from the program; the field shows it while it doesn't have focus.
- `minimum: Float64`: The smallest value it takes.
- `maximum: Float64`: The largest value it takes.
- `rect: Rectangle`: Where it is: the field, then the − and + buttons at its right end.
- `step: Float64`: How far the buttons, the arrows and a gamepad step the value.
- `decimals: Int`: How many places after the point the value is rounded to and shown with: whole numbers at 0.
- `container: Style`
- `text_style: Style`
- `buttons: Style`
- `enabled: Bool`: Whether it reacts to the mouse and keyboard. A disabled field is faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    value: Float64,
    minimum: Float64,
    maximum: Float64,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    step: OptionalNumber = None,
    decimals: Int = Int(0),
    container: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    text_style: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    buttons: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse and keyboard did to it this frame, and work out its look: call it before drawing it.

It is drawn in the canvas's colours,
`canvas.colors()`.

### `focused`

```mojo
def focused(self) -> Bool
```

Whether it has focus, so typing goes into it.

### `changed`

```mojo
def changed(self) -> Bool
```

Whether its last `update` changed `value`, by typing, a button, an arrow or a gamepad.

### `hovered`

```mojo
def hovered(self) -> Bool
```

### `pressed`

```mojo
def pressed(self) -> Bool
```

### `down`

```mojo
def down(self) -> Bool
```

### `released`

```mojo
def released(self) -> Bool
```

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
