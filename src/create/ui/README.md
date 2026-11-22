# `create.ui` internals

`create.ui` draws widgets and keeps the state they need from frame to frame. A widget is a call made
every frame inside a layer's `with` block; the `UI` the program keeps holds everything that outlives
the call. This page is for working on the package: the [user
guide](../../../docs/guide/ui/README.md) covers using it, and
[ARCHITECTURE.md](../../../ARCHITECTURE.md) where it sits and the layering rules.

## Files

| File | Role |
|---|---|
| `ui.mojo` | `UI`: the state kept between frames (the widgets seen, focus, the held widget, text buffers, scope stacks, the device claims), the per-frame reset in `_begin_layer`, Tab and gamepad navigation, `ui.screen` and `ui.world`; `_Hit`, a widget's place for hit-testing; `_Styles`, the merged `ui.style` blocks |
| `layer.mojo` | `UILayer`, the handle a layer's block gets: every widget, `_interact` (what the pointer and keys did to a widget), the focus ring, `ui.draw`, the scopes and panels, and the guards their `with` blocks return |
| `_id.mojo` | Widget IDs: a call site's file, line and column, mixed into the keys of the open `ui.id` blocks |
| `_layout.mojo` | `_Layout`, an open panel, column or row, and how it hands out the slots of the widgets called inside it |
| `_key.mojo` | `_WidgetKey`, the `id=` keyword, which takes a string, an integer or `None` in one implicit conversion |
| `_recorder.mojo` | `_Recorder`, a `DrawTarget` a layer draws on: shapes, text, images and clips, replayed in call order when the block ends |
| `_text_buffer.mojo` | `_TextBuffer`, the editing behind a text field: the text, the caret, the selection, and what each key does to them |
| `theme.mojo` | `Theme` and its tokens, `ColorScheme`, `Theme.from_seed` and its `_Palette`; `_contrast` and `_readable_on` |
| `button.mojo` | `ButtonVariant`; a button, a label and a panel take a `Style`, and the other widgets a `Style` for each of their parts |
| `text_field.mojo` | `TextEditor`, the caret, selection and editing `ui.text_editor()` hands a program |

## How a frame goes

**The first layer of a frame resets the per-frame state.** `ui.screen` and `ui.world` both call
`_begin_layer`, which recognises a new frame by `context.frame_count()`. Several layers in one frame
share the call-site counts, the hit list and focus, so the reset happens once, at the first. It:

1. swaps this frame's hits into `_last_hits`, and works out `_hot`, the topmost widget under the
   pointer, from them;
2. lets go of the held widget once the button is up, and of focus when its widget wasn't called last
   frame, Escape or a gamepad's east button was pressed, or a click landed on nothing focusable;
3. moves focus for Tab and for a d-pad or stick push;
4. drops the text buffers of fields not called last frame, switches `context.text_input` when focus
   moved onto or off a text field, and renews or releases the device claims.

**Hit-testing uses the previous frame's widgets.** A widget learns whether it is hovered when it is
called, before the widgets called after it have said where they are, so this frame's hits can't
decide it. Last frame's hits, in drawing order across every layer, can: the last one containing the
pointer is on top. A widget is therefore hoverable from its second frame. Each `_Hit` keeps the
transform that takes a screen point into its layer's space, so world layers are hit-tested through
their camera.

**A layer draws when its block ends.** Widgets draw into the `UI`'s `_Recorder`, never onto the
canvas. `UILayer.__exit__` adds the focus ring last, so nothing covers it, then replays everything
in call order: inside `canvas.overlay()` for a screen layer, or through the `_View` (camera and
transform) recorded when a world layer opened. Clips nest: `_ClipBegin` and `_ClipEnd` commands
replay through a recursive `_replay_from`, each inside the canvas's own clip guard.

## Layout

**A widget called without a rect is placed by the innermost open column or row.** `UI._layouts` is a
stack of `_Layout`s: `ui.panel`, `ui.column` and `ui.row` each push one, and their guards pop it. A
widget's public method resolves its rect through `UILayer._place` before it calls its body, so the
body, the hit-testing and the ID never see the difference. A column hands out strips from its `top`
edge down, each as tall as the widget asks: the theme's `control_height`, or one and a half times a
label's text size. A row is cut into its slots when it opens, with `Rectangle.columns`.

**Layout is one pass.** Every slot is known when it is asked for, so a widget knows where it is when
it is called, and answers in the same frame. The cost is that nothing can be sized from what is
inside it, such as a panel fitted round its widgets: that would need the sizes of widgets not yet
called. A panel hands out no slots, only its inside, inset, to a column or row opened directly in
it.

## IDs

A widget's ID is its call site, mixed into the key of the innermost open `ui.id` block, then mixed
with how many times that site has run this frame. Every public widget is `@always_inline` and calls
`call_location()` in its own body, so the site is the program's line, not the library's. A helper
the library calls would see its own line instead, so every widget method keeps that call in the
public method and hands the ID to a non-inline `_`-named body. A widget's state is kept under its ID
in the `UI`; text buffers are dropped when their ID isn't seen for a frame.

## The widget called last

A value widget returns nothing; what it did is read afterwards. Each reacting widget's body ends by
calling `UI._called`, which records whether it changed its value, whether Enter was pressed in it
and, for a text field, its ID. `ui.changed()`, `ui.submitted()` and `ui.text_editor()` read those
back, and the first layer of a frame clears them. A `TextEditor` edits the field's buffer and marks
it `edited`; the field's next call then hands the buffer's text to the program, rather than taking
the program's text in, and reports the change.

## Focus and the devices

The `UI` keeps one focused ID, and how it got there: `_focus_visible` (from the keyboard, a gamepad
or `take_focus`, so a ring shows), `_focused_takes_typing` (a text field) and `_focus_from_gamepad`.
Keys act on the focused widget only when focus is visible and not from a gamepad, so a game's own
keys keep working after a click, and a split-screen pad doesn't take the keyboard.

**Several `UI`s take turns at the keyboard and mouse** through an opaque claim on each device
(`input`'s `_Claim`). A `UI` gets a claimant number from `Context._new_claimant()` when it first
opens a layer, claims the keyboard while `_holds_keys()` and the mouse while a widget is held, and
renews the claims every frame. A claim not renewed for a frame lapses, so a `UI` that stops drawing
can't hold a device. A `UI` that sees a device claimed by another ignores it.

## Styling

A widget's look is resolved when it is drawn, in this order: the call's style, then the innermost
`ui.style` block (each block is stored already merged over the ones outside it), then the theme (the
innermost `ui.theme` block's, or the `UI`'s own). Merging is field by field, through each style's
`_over`. Panels push a content colour, which labels and checkbox labels use when their style doesn't
set one.

**State colours step OKLCH lightness.** A hovered, pressed or dragged widget's fill is `_stepped`:
its OKLCH lightness moved by the theme's `StateLayers` step towards its text colour, its chroma and
hue kept. A widget with no fill of its own draws a translucent layer whose opacity `_layer_opacity`
chooses to move the surface's lightness by the same step. Disabled widgets fade their colours by
`_faded`, which scales the colour's own alpha, so a transparent colour stays transparent.

## Testing

Tests in `tests/ui/` build a `UI`, a `Context` and an offscreen `Canvas` directly, and feed input
through the devices' `_` methods between frames, with the helpers in `tests/ui/_input.mojo`
(`next_frame`, `point_at`, `press`, `release`, `press_key`, `connect_pad`, `press_pad`). A widget is
hoverable from its second frame, so a test of the pointer draws a frame first, then acts. Tests
reach internals such as `ui._focused` and `ui._hits` by path; the pixel tests read colours with
`canvas.color_at`.
