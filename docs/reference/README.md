# API reference

This is the complete API reference for Create, one page per subpackage. How importing works is described in the [Imports](../guide/basics/mojo.md#imports) page in the user guide.

## [`create.app`](app/README.md)

The run: the `Program` trait, `run` and `run_headless`, the run's state (`Context`) and its settings (`WindowMode`, `Cursor`), and `source_path`.

- **Types:** [`Context`](app/context.md), [`WindowMode`](app/windowmode.md), [`Cursor`](app/cursor.md)
- **Traits:** [`Program`](app/program.md)
- **Functions:** [`source_path`](app/source_path.md), [`run`](app/run.md), [`run_headless`](app/run_headless.md)

## [`create.input`](input/README.md)

The input devices `Context` holds: `Keyboard`, `Mouse` and `Gamepad`, and the `Key`, `MouseButton` and `GamepadButton` they are read with.

- **Types:** [`Keyboard`](input/keyboard.md), [`Key`](input/key.md), [`Mouse`](input/mouse.md), [`MouseButton`](input/mousebutton.md), [`Gamepad`](input/gamepad.md), [`GamepadButton`](input/gamepadbutton.md)

## [`create.math`](math/README.md)

Maths: `Point`, `Vector`, `Transform` and `Matrix`, `Random` and `Noise`, `OptionalNumber`, the easing curves, scalar helpers, `PI` and `TAU`, and the common `std.math` functions.

- **Types:** [`Easing`](math/easing.md), [`Point`](math/point.md), [`OptionalNumber`](math/optionalnumber.md), [`Vector`](math/vector.md), [`Transform`](math/transform.md), [`Matrix`](math/matrix.md), [`Random`](math/random.md), [`Noise`](math/noise.md)
- **Functions:** [`lerp`](math/lerp.md), [`map`](math/map.md), [`inverse_lerp`](math/inverse_lerp.md), [`smoothstep`](math/smoothstep.md), [`sign`](math/sign.md), [`fractional_part`](math/fractional_part.md), [`wrap`](math/wrap.md), [`degrees`](math/degrees.md), [`radians`](math/radians.md), [`ease`](math/ease.md), [`identity`](math/identity.md), [`inverse`](math/inverse.md)
- **Constants:** [`PI`](math/README.md#pi), [`TAU`](math/README.md#tau)

## [`create.time`](time/README.md)

Time: the run's frame clock (`Time`), the `Clock` a playhead keeps time by, and the wall clock (`DateTime`).

- **Types:** [`Time`](time/time.md), [`Clock`](time/clock.md), [`DateTime`](time/datetime.md)

## [`create.geometry`](geometry/README.md)

Shapes and curves, the traits they share, and the collision tests: each shape's `overlaps` and `contains`, and each curve's `intersects`. How they are drawn is `render`'s.

- **Types:** [`Rectangle`](geometry/rectangle.md), [`Circle`](geometry/circle.md), [`Ellipse`](geometry/ellipse.md), [`Capsule`](geometry/capsule.md), [`Line`](geometry/line.md), [`Triangle`](geometry/triangle.md), [`Arc`](geometry/arc.md), [`Sector`](geometry/sector.md), [`Polygon`](geometry/polygon.md), [`Bezier`](geometry/bezier.md), [`Spline`](geometry/spline.md)
- **Traits:** [`Curve`](geometry/curve.md), [`Geometry`](geometry/geometry.md), [`Shape`](geometry/shape.md)

## [`create.color`](color/README.md)

Colours: `Color` and `BlendMode`.

- **Types:** [`Color`](color/color.md), [`BlendMode`](color/blendmode.md)

## [`create.render`](render/README.md)

Drawing: `Canvas`, `Drawable`, `Text`, `Picture`, `Style`, `Gradient`, `Camera`, and the settings that shape a frame (`Antialiasing`, `Autoscale`, `Align`, `StrokeCap`, `StrokeDash`, `StrokeAlign`, `RenderBackend`).

- **Types:** [`RenderBackend`](render/renderbackend.md), [`Antialiasing`](render/antialiasing.md), [`Align`](render/align.md), [`StrokeAlign`](render/strokealign.md), [`StrokeCap`](render/strokecap.md), [`StrokeDash`](render/strokedash.md), [`Autoscale`](render/autoscale.md), [`Gradient`](render/gradient.md), [`Style`](render/style.md), [`Camera`](render/camera.md), [`Canvas`](render/canvas.md), [`Text`](render/text.md), [`Picture`](render/picture.md)
- **Traits:** [`Drawable`](render/drawable.md)

## [`create.image`](image/README.md)

Images: `Image` and `PixelBuffer`.

- **Types:** [`Image`](image/image.md), [`PixelBuffer`](image/pixelbuffer.md)

## [`create.animation`](animation/README.md)

Animation: values and sprites that move over time. `Tween` eases a number between two values; `Animation` is a sequence of frames, and `Animator` is one entity's playhead in it. Each keeps time on its own, off the run's clock. The curves themselves, `Easing` and `ease`, are `math`'s.

- **Types:** [`Tween`](animation/tween.md), [`Animation`](animation/animation.md), [`Animator`](animation/animator.md)

## [`create.text`](text/README.md)

Fonts: `Font` and `FontWeight`, with Noto Sans built in.

- **Types:** [`Font`](text/font.md), [`FontWeight`](text/fontweight.md)

## [`create.audio`](audio/README.md)

Sound: `Sound` (the asset), `Audio` (the playback device) and `Playback` (one playback).

- **Types:** [`Sound`](audio/sound.md), [`Audio`](audio/audio.md), [`Playback`](audio/playback.md)

## [`create.data`](data/README.md)

Data files: `Table` and `TableRow` for CSV and TSV, and `JSON`.

- **Types:** [`Table`](data/table.md), [`TableRow`](data/tablerow.md), [`JSON`](data/json.md), [`JSONKind`](data/jsonkind.md)

## [`create.ui`](ui/README.md)

The user interface: widgets, such as `Button`, `Checkbox`, `Switch`, `ChoiceGroup`, `Tabs`, `Label`, `Panel`, `Slider`, `ProgressBar`, `TextField` and `NumberField`, which are values a program keeps, updates and draws with `canvas.draw`, and the traits they share (`Widget`, `Hoverable`, `Clickable`); `UI`, which keeps widgets together, lays them out with `Column`, `Row` and `Space` and scrolls them with `ScrollArea`, reached through `WidgetHandle`s; and `ColorScheme`, the colours they are drawn in.

- **Types:** [`UI`](ui/ui.md), [`WidgetHandle`](ui/widgethandle.md), [`ColorScheme`](ui/colorscheme.md), [`StateLayers`](ui/statelayers.md), [`FocusRing`](ui/focusring.md), [`Button`](ui/button.md), [`ButtonVariant`](ui/buttonvariant.md), [`Checkbox`](ui/checkbox.md), [`Switch`](ui/switch.md), [`ChoiceGroup`](ui/choicegroup.md), [`Tabs`](ui/tabs.md), [`Label`](ui/label.md), [`Column`](ui/column.md), [`Row`](ui/row.md), [`Space`](ui/space.md), [`ScrollArea`](ui/scrollarea.md), [`Panel`](ui/panel.md), [`Slider`](ui/slider.md), [`ProgressBar`](ui/progressbar.md), [`TextField`](ui/textfield.md), [`NumberField`](ui/numberfield.md)
- **Traits:** [`Widget`](ui/widget.md), [`Hoverable`](ui/hoverable.md), [`Clickable`](ui/clickable.md)
