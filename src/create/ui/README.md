# `create.ui` internals

`create.ui` is the widgets and the `UI` that keeps them together. A widget is a value: the program
keeps it, calls its `update` with the frame's input, draws it with `canvas.draw`, and asks it what
happened. A `UI` holds built-in widgets in a tree, and updates, lays out and draws them in one call
each. This page is for working on the package: the [user guide](../../../docs/guide/ui/README.md)
covers using it, and [ARCHITECTURE.md](../../../ARCHITECTURE.md) where it sits and the layering
rules.

## Files

| File | Role |
|---|---|
| `_theme.mojo` | `_Theme`: the colours, the `ui.style` styles (`_Styles`), the settings and the surface, and one method per widget that resolves its parts' styles for its state; the state colours (`_stepped`, `_layer_opacity`, `_faded`) and `_content_on` |
| `_text_buffer.mojo` | `_TextBuffer`, the editing behind a text field: the text, the caret, the selection, and what each key does to them |
| `color_scheme.mojo` | `ColorScheme`, its `light`, `dark` and `from_seed` constructors and the seed's `_Palette`; `_contrast` and `_readable_on` |
| `state_layers.mojo` | `StateLayers`, how strongly a widget shows its state |
| `focus_ring.mojo` | `FocusRing`, the ring around a focused widget |
| `ui.mojo` | `UI`, the widget tree: its nodes, each a `_Widget` variant of the built-in widgets and layout nodes, a parent, children, whether the tree enables and shows it, and its generation; `remove` and `visible`; `update` (layout, then the topmost widget under the pointer unless another tree holds the mouse, then focus moved for this frame's clicks, Tab, Escape and gamepad, then every widget in drawing order with its `_Focus` and whether its part of the tree is disabled, each panel passing its surface down, then the device claims) and `draw_to`, the focus ring last; `wants_mouse` and `wants_keyboard`; layout in two passes, sizes from the inside out, then places from the top level in; `_describe`, `_draw` and `_dispatch_mut`, the only code that knows which kinds of node it holds |
| `_navigation.mojo` | `_Focus`, what the tree's focus means for a widget this frame (focused, keys act, activated, a gamepad's step); the arrows' and the gamepad's push, with `_PadRepeat` repeating a held direction, and the nearest-in-a-direction choice |
| `widget_handle.mojo` | `WidgetHandle`, where a widget is in a `UI`: its index, its generation and which `UI` made it |
| `_layout.mojo` | `_UNSIZED`, the size a widget leaves for the tree to choose, `_sized`, and `_Placement`, how a node fits in its column or row |
| `column.mojo`, `row.mojo`, `space.mojo` | `Column`, `Row` and `Space`, the tree's layout nodes |
| `widget.mojo` | `Widget`, the trait every widget value shares: `update`, then drawn with `canvas.draw` |
| `hoverable.mojo`, `clickable.mojo` | `Hoverable` and `Clickable`, what can be asked of a widget after its `update` |
| `_pointer.mojo` | `_Pointer`, what the mouse did to a widget value: hovered, held, dragged this frame, and this frame's press and click, kept between its `update`s |
| `checkbox.mojo` | `Checkbox`, a widget value that owns whether it is ticked; its box, tick and text placement |
| `label.mojo` | `Label`, a widget value: text placed in a rectangle; `_anchor`, the point of a rectangle text is anchored to |
| `panel.mojo` | `Panel`, a widget value: a surface for widgets, with the colour for text on it |
| `slider.mojo` | `Slider`, a widget value that owns its value; the track's ends, the handle's place, and the value a drag or a key gives |
| `button.mojo` | `Button`, a widget value. A button, a label and a panel take a `Style`, and the other widgets a `Style` for each of their parts |
| `button_variant.mojo` | `ButtonVariant`, which of the colours a button is drawn in |
| `text_field.mojo` | `TextField`, a widget value that owns a `_TextBuffer` and its own focus; `_measure` and `_offset_at`, how it measures text to place its caret |

## A widget on its own

**`update` reads the input; `draw_to` only draws.** A widget's `update(context, canvas)` finds the
pointer with `canvas.to_local`, so a widget under a camera or a transform is hit where it is drawn,
and feeds it to the widget's `_Pointer`, which keeps whether it is hovered and held and this frame's
press and click. It then resolves the widget's look for that state from a `_Theme` and keeps it, so
`draw_to` only places the parts and draws each in its resolved style through `canvas._with_style`.
Hover shows in the frame it happens. Anything that can fail, such as measuring text, happens in
`update`, since `draw_to` can't raise.

**Each widget's public `update` calls a private `_update`** with `_Theme.default(colors)`, in the
light colours unless `update` is given others, and no tree. A `UI` calls `_update` itself, with its
own theme, whether the widget is the topmost under the pointer (`free`), what its focus means for it
(`_Focus`) and whether its part of the tree is disabled. A widget's own `enabled` field is left as
the program set it: the tree's `disabled` is a separate argument, so enabling a part of the tree
again restores each widget as it was.

## The tree

`UI` (`ui.mojo`) keeps its widgets as `_Node`s: a `_Widget`, a `Variant` of every built-in kind and
the layout nodes, with a parent and children. The `Variant` is storage only. Three methods are the
only code that knows which kinds it holds, each matching a node's kind and handing it to that kind's
own fields and methods: `_describe` (what layout, hit-testing and focus need to know about a node:
its kind, rect, whether it takes the pointer or focus, its ring), `_draw`, and `_dispatch_mut`
(update, measure, place). A new kind needs a branch in each and nothing else. Reading and changing
are separate methods because each needs the tree and the canvas differently. The public API never
shows the `Variant`: `ui.add` returns a typed `WidgetHandle[W]`, and `ui[handle]` is a reference to
the `W` inside it.

**A hidden node is skipped, and a removed one frees its place.** `ui.visible` sets a node's
`visible`, and every walk of the tree leaves a hidden node out along with what is inside it:
`_drawing_order`, which hit-testing, focus and drawing go by, and layout, where a hidden node takes
no slot. `update` still updates a hidden node, as a disabled one, so it lets go of the mouse and
reports no click while hidden. `ui.remove` takes a node and what is inside it off their parent,
swaps each widget for a `Space` so it lets go of what it held, and frees its place in `_nodes` for
the next node added. Each node counts its `generation`, how many nodes had its place before it, and
a `WidgetHandle` carries the one it was made for, so `_index_of`, which every handle goes through,
stops the program when a handle outlives its widget rather than reaching the node that took its
place. A handle also carries its `UI`'s identity, the address of the heap cell `_identity`, which
stays put when the `UI` is moved, so a handle used on another `UI` stops the program too. What
`ui.add` takes is checked when the program is compiled: the widget must be a kind `_Widget` holds,
and a parent a kind `_Container` holds.

**`update` runs in a fixed order:**

1. lay out every node (below);
2. find the topmost node under the pointer, walking the drawing order backwards, unless another `UI`
   holds the mouse;
3. move focus for this frame's clicks, Tab, Escape and gamepad (below);
4. update every node in drawing order, a parent before what is inside it, each with its theme: a
   panel passes its surface and content colours down to what is inside it;
5. renew or release the device claims.

`draw_to` draws every node in the same order, then the focus ring, so nothing covers it.

## Layout

**Layout is two passes, every frame, before hit-testing.** First every node is measured, from what
is inside it outwards: walking the drawing order backwards reaches every child before its parent. A
widget's `_measure` gives the size it prefers in the theme (a control `control_height` tall, a label
one and a half times its text size); a column sums its children's heights with its gaps, a row their
widths, and a panel with no size fits round the column or row inside it. Then every node is placed,
from the top level in. A column and a row follow one rule along their length (`_shares`): each child
starts from its measured size, and the room left over goes to the children with a `grow`, in
proportion to it; a column then hands strips down its width from the top, and a row slots across its
height from the left. Across, each child is stretched, or, with an `align` of its own or its
column's or row's, set at its measured size against the side it names (`_across`); a child given a
cross size and no `align` is centred. A panel hands its inside, inset by its `padding` (twice the
`spacing` unless set), to a column or row inside it. A node's `_Placement` is what `ui.add` was told
about how it fits in its column or row: a `width` or `height` given there replaces the measured one,
so a column or row places it from that. A node added with no size (`_UNSIZED`) is marked
`sized_by_ui` and given its preferred size every frame, unless its parent places it. A column or row
places only such children, and a panel only such a column or row: a node added with a size of its
own keeps its place and takes no room.

## Focus and the devices

The `UI` keeps one focused node and how focus got there: `_focus_visible` (from the keyboard, a
gamepad or `ui.focus`, so a ring shows) and `_focus_from_gamepad`. `_navigate` moves it before any
widget acts, along for Tab and towards an arrow or a gamepad's push. An arrow moves focus only while
keys act on it, and not when the focused widget takes the arrow itself (`_takes_arrow`: a text
field's caret, a slider's left and right); `_arrow_moved` keeps an arrow that moved focus from also
stepping the slider it lands on. `_focus_for` tells each node what focus means for it as a `_Focus`:
whether keys act on it (focus visible, not from a gamepad, and the keyboard not held by another
`UI`), whether Enter, Space or the south button activated it, and which way a gamepad stepped a
slider. A `TextField` on its own keeps its own focus; in a tree, it takes the tree's. What its
`focus` method asked for is kept as `_focus_request` until its next update, and `_navigate` first
acts on it (`_take_focus_requests`), so `ui[field].focus()` works as `ui.focus(field)` does.

**Several `UI`s take turns at the keyboard and mouse** through an opaque claim on each device
(`input`'s `_Claim`). A `UI` gets a claimant number from `Context._new_claimant()` on its first
`update`, claims the keyboard while `_holds_keys()` and the mouse while a widget is held, and renews
the claims every frame. A claim not renewed for a frame lapses, so a `UI` that stops updating can't
hold a device. A `UI` that sees a device claimed by another ignores it.

## Styling

**Every part of a widget is a shape drawn in a `Style`,** `render`'s own. A button, a label and a
panel have one part; a slider, a checkbox and a text field have several, each a field of the widget
(`handle`) and a keyword of `ui.style` (`slider_handle=`). What a part's style means follows from
the shape it is drawn as: a slider's track is a `Line`, so its stroke is the track; its handle is a
point, a zero-length round-capped `Line` as `canvas.point` draws it, so its stroke thickness is the
handle's diameter.

**A widget's look is resolved from a `_Theme` and its state.** `_Theme` (`_theme.mojo`) holds the
colours, the `ui.style` styles (`_Styles`), the settings and the surface the widget sits on, and one
method per widget (`button`, `slider`, …) resolves every part for the widget's state: hovered,
pressed, dragged, focused or disabled. A part's look is `own.over(kind).over(defaults)`: the
widget's own style for the part, over the `UI`'s style for that kind, over the defaults built from
the colours and settings. `Style.over` means applying the base and then the style, so a part named
on top switches on what the defaults switched off. One part can take what it leaves unset from
another: a slider's active track from its track, a checkbox's ticked box from its box, a text
field's placeholder from its text and its focused look from its container. A widget's text keeps
only the text parts of its style (`_text_look`), so a shadow or outline given to a button belongs to
its shape, not its letters.

**State colours step OKLCH lightness.** A hovered, pressed or dragged part's paint, its fill for a
region and its stroke for a line or a point, is `_stepped`: its OKLCH lightness moved by the
`StateLayers` step towards its text colour, its chroma and hue kept. A widget with no fill of its
own draws a translucent layer whose opacity `_layer_opacity` chooses to move the surface's lightness
by the same step. The surface is what the widget sits on: the innermost panel's fill, or the
colours' `surface` outside any panel; disabled parts drawn solid, such as a slider's handle, are
mixed from it too. Disabled widgets fade their colours by `_faded`, which scales the colour's own
alpha, so a transparent colour stays transparent.

## Testing

Tests in `tests/ui/` build widgets or a `UI`, a `Context` and an offscreen `Canvas` directly, and
feed input through the devices' `_` methods between frames, with the helpers in
`tests/ui/_input.mojo` (`next_frame`, `point_at`, `press`, `release`, `press_key`, `connect_pad`,
`press_pad`). A widget answers in the frame it is updated, so a test sets the input, updates, then
asks. A fresh `Context` has the mouse at the origin, so a test that wants nothing hovered points
away first. Tests reach internals such as `ui._focused` by path; the pixel tests read colours with
`canvas.color_at`.
