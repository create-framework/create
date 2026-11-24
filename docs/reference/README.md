# API reference

This is the complete API reference for Create, one page per subpackage. How importing works is described in the [Imports](../guide/basics/mojo.md#imports) page in the user guide.

## [`create.core`](core/README.md)

The run: the `Program` trait, `run` and `run_headless`, the run's state (`Context`) and its settings (`WindowMode`, `Cursor`), and `source_path`.

- **Types:** [`Context`](core/context.md), [`WindowMode`](core/windowmode.md), [`Cursor`](core/cursor.md)
- **Traits:** [`Program`](core/program.md)
- **Functions:** [`source_path`](core/source_path.md), [`run`](core/run.md), [`run_headless`](core/run_headless.md)

## [`create.input`](input/README.md)

The input devices `Context` holds: `Keyboard`, `Mouse` and `Gamepad`, and the `Key`, `MouseButton` and `GamepadButton` they are read with.

- **Types:** [`Keyboard`](input/keyboard.md), [`Key`](input/key.md), [`Mouse`](input/mouse.md), [`MouseButton`](input/mousebutton.md), [`Gamepad`](input/gamepad.md), [`GamepadButton`](input/gamepadbutton.md)

## [`create.math`](math/README.md)

Maths: `Point`, `Vector`, `Transform` and `Matrix`, `Random` and `Noise`, the easing curves, scalar helpers, `PI` and `TAU`, and the common `std.math` functions.

- **Types:** [`Easing`](math/easing.md), [`Point`](math/point.md), [`Vector`](math/vector.md), [`Transform`](math/transform.md), [`Matrix`](math/matrix.md), [`Random`](math/random.md), [`Noise`](math/noise.md)
- **Functions:** [`lerp`](math/lerp.md), [`map`](math/map.md), [`inverse_lerp`](math/inverse_lerp.md), [`smoothstep`](math/smoothstep.md), [`sign`](math/sign.md), [`fractional_part`](math/fractional_part.md), [`wrap`](math/wrap.md), [`degrees`](math/degrees.md), [`radians`](math/radians.md), [`ease`](math/ease.md), [`identity`](math/identity.md), [`inverse`](math/inverse.md)
- **Constants:** [`PI`](math/README.md#pi), [`TAU`](math/README.md#tau)

## [`create.time`](time/README.md)

Time: the run's frame clock (`Time`), the `Clock` a playhead keeps time by, and the wall clock (`DateTime`).

- **Types:** [`Time`](time/time.md), [`Clock`](time/clock.md), [`DateTime`](time/datetime.md)

## [`create.geometry`](geometry/README.md)

Shapes and curves, the traits that make a type drawable, and the collision tests: each shape's `overlaps` and `contains`, and each curve's `intersects`.

- **Types:** [`Rectangle`](geometry/rectangle.md), [`Circle`](geometry/circle.md), [`Ellipse`](geometry/ellipse.md), [`Capsule`](geometry/capsule.md), [`Line`](geometry/line.md), [`Triangle`](geometry/triangle.md), [`Arc`](geometry/arc.md), [`Sector`](geometry/sector.md), [`Polygon`](geometry/polygon.md), [`Bezier`](geometry/bezier.md), [`Spline`](geometry/spline.md)
- **Traits:** [`Curve`](geometry/curve.md), [`Drawable`](geometry/drawable.md), [`DrawTarget`](geometry/drawtarget.md), [`Geometry`](geometry/geometry.md), [`Shape`](geometry/shape.md)

## [`create.color`](color/README.md)

Colours: `Color`, `Gradient` and `BlendMode`.

- **Types:** [`Color`](color/color.md), [`Gradient`](color/gradient.md), [`BlendMode`](color/blendmode.md)

## [`create.render`](render/README.md)

Drawing: `Canvas` and its `with`-block guards, `Style`, `Camera`, and the settings that shape a frame (`Antialiasing`, `Autoscale`, `Align`, `StrokeCap`, `StrokeDash`, `StrokeAlign`, `RenderBackend`).

- **Types:** [`RenderBackend`](render/renderbackend.md), [`Antialiasing`](render/antialiasing.md), [`Align`](render/align.md), [`StrokeAlign`](render/strokealign.md), [`StrokeCap`](render/strokecap.md), [`StrokeDash`](render/strokedash.md), [`Autoscale`](render/autoscale.md), [`Style`](render/style.md), [`Camera`](render/camera.md), [`Canvas`](render/canvas.md), [`StyleGuard`](render/styleguard.md), [`TransformGuard`](render/transformguard.md), [`OverlayGuard`](render/overlayguard.md), [`ClipGuard`](render/clipguard.md)

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

The user interface: `UI`, which keeps the widgets' state from frame to frame, `UILayer`, the handle a `with` block gets to draw widgets with, and `ColorScheme`, the colours they are drawn in.

- **Types:** [`UI`](ui/ui.md), [`UILayer`](ui/uilayer.md), [`IDGuard`](ui/idguard.md), [`DisabledGuard`](ui/disabledguard.md), [`ColorsGuard`](ui/colorsguard.md), [`WidgetStyleGuard`](ui/widgetstyleguard.md), [`PanelGuard`](ui/panelguard.md), [`LayoutGuard`](ui/layoutguard.md), [`ColorScheme`](ui/colorscheme.md), [`StateLayers`](ui/statelayers.md), [`FocusRing`](ui/focusring.md), [`ButtonVariant`](ui/buttonvariant.md), [`TextEditor`](ui/texteditor.md)
