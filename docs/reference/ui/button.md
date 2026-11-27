# Button

```mojo
struct Button
```

A button with a line of text on it, which the mouse clicks.

Keep it in a field, so it remembers being pressed from one frame to the
next. Each frame, `update` it and then draw it, and ask it what
happened:

```mojo
# In `create`, building the `play` field:
var play = Button("Play", Rectangle((0, 0), 160, 48))

# In `update`:
self.play.update(context, canvas)
canvas.draw(self.play)
if self.play.released():
    self.start()
```

`released()` is the click: the button let go over it, after being
pressed on it. `pressed()` is the press, `down()` whether it is held,
and `hovered()` whether the pointer is over it.

It is filled in the colours' `primary` unless its `style` says
otherwise, and its style changes only what it sets:
`Style(corner_radius=4)` squares its corners. Four ready-made styles
give it a weight, from the main action to the quietest: `Button.FILLED`
(the look it has unless styled), `Button.TONAL`, `Button.OUTLINED` and
`Button.TEXT`. Each names its colours by `ColorRole`, so it follows the
colours it is drawn in, and layers under a style of your own with
`over`: `Style(corner_radius=0).over(Button.OUTLINED)`. It
steps lighter or darker while hovered and pressed, and fades while not
`enabled`, when it reacts to nothing.

Implements `Clickable`, `Copyable`, `Deinitable`, `Drawable`, `Hoverable`, `Movable`, `Widget`.

## Constants

- `FILLED = Style(fill=OptionalColor(ColorRole.PRIMARY), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(ColorRole.OUTLINE), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(False), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(ColorRole.ON_PRIMARY), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None))`: Filled in `primary`, with its text in `on_primary`: for the main action. A button looks like this unless styled.
- `TONAL = Style(fill=OptionalColor(ColorRole.PRIMARY_CONTAINER), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(ColorRole.OUTLINE), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(False), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(ColorRole.ON_PRIMARY_CONTAINER), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None))`: Filled in `primary_container`, a paler tint of `primary`: for a secondary action.
- `OUTLINED = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(False), stroke=OptionalColor(ColorRole.OUTLINE), stroke_thickness=OptionalNumber(1), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(ColorRole.PRIMARY), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None))`: Outlined, unfilled, with its text in `primary`: for a less important action.
- `TEXT = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(False), stroke=OptionalColor(ColorRole.OUTLINE), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(False), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(ColorRole.PRIMARY), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None))`: Only its text, in `primary`: for the quietest actions, such as a list of choices.

## Fields

- `text: String`: The text on it.
- `rect: Rectangle`: Where it is, and how big. A rotated rectangle turns it.
- `style: Style`: Its own style, over its default look.
- `enabled: Bool`: Whether it reacts to the mouse. A disabled button is faded.

## Constructors

```mojo
@staticmethod
def __init__(
    out self,
    text: String,
    rect: Rectangle = Rectangle(Point(SIMD(0), SIMD(0)), SIMD(0), SIMD(0), corner_radius=OptionalNumber(SIMD(0)), rotation=OptionalNumber(SIMD(0))),
    *,
    style: Style = Style(fill=OptionalColor(None), fill_gradient=Optional(None), fill_enabled=Optional(None), stroke=OptionalColor(None), stroke_thickness=OptionalNumber(None), stroke_enabled=Optional(None), stroke_alignment=Optional(None), stroke_cap=Optional(None), stroke_dash=Optional(None), corner_radius=OptionalNumber(None), text_color=OptionalColor(None), font=Optional(None), font_size=OptionalNumber(None), font_weight=Optional(None), font_italic=Optional(None), text_alignment=Optional(None), tint=OptionalColor(None), opacity=OptionalNumber(None), blend_mode=Optional(None), shadow=OptionalColor(None), shadow_offset=Optional(None), shadow_blur=OptionalNumber(None), shadow_spread=OptionalNumber(None), shadow_inset=Optional(None), shadow_follows_transform=Optional(None), shadow_enabled=Optional(None)),
    enabled: Bool = True,
)
```

## Methods

### `update`

```mojo
def update(mut self, mut context: Context, mut canvas: Canvas) raises
```

Read what the mouse did to it this frame, and work out its look: call it before drawing it.

It is drawn in the canvas's colours,
`canvas.colors()`.

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

Whether it was clicked this frame: let go over it after being pressed on it, or, in a `UI`, pressed with Enter, Space or a gamepad's south button while it has focus.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
