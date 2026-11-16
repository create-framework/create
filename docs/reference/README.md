# API reference

Create — a creative coding library for rapid prototyping and interactive graphics.

`from create import *` is the import a program needs. It brings in the whole
public surface: the `Program` trait and the run loops, `Context`, keyboard,
mouse and gamepad input, `Canvas` and the rendering types, the vector and
matrix maths, the clocks, the shapes and curves, images, animation, fonts,
audio, CSV tables and JSON, the circle constants `PI` and `TAU`, and a
re-export of `std.math` so `sin` and `cos` are there without a second import.

```mojo
from create import *


@fieldwise_init
struct Sketch(Program):
    var angle: Float64

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        return Self(0.0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.angle += context.time.delta
        canvas.background(Color.BLACK)
        canvas.circle((100 * cos(self.angle), 100 * sin(self.angle)), 20)


def main() raises:
    run[Sketch]("Sketch", width=1280, height=720)
```

The subpackages stay importable on their own — `from create.render import *`
gives the rendering stack with no run loop, which is what `run_headless` is built
on — so this module is a convenience, not a layer.

**What this module re-exports is the union of the subpackages.** Each of them
exports the names it owns and nothing from a layer below — `create.core` names
`Canvas` and `Rectangle` in its signatures but exports neither — so a single
subpackage star is never a preamble; this module is. It re-exports everything
public by star-importing all twelve, so a name added to `math/__init__.mojo`
appears here with no second edit and the two cannot drift apart.

Code that wants less than the whole surface imports by name from the package
that defines it (`from create.geometry import Circle`), rather than starring one
subpackage.

The stars widen nothing on their own. A star import skips `_`-prefixed
declarations and reaches only what a package's `__init__.mojo` lists, so
`_raster`'s `blend`, `_bytes`'s `le_uint` and `text/font.mojo`'s `_GlyphInfo` stay
internal here exactly as they are one level down.

## [`create.core`](core/README.md)

The run: the `Program` trait, `run` and `run_headless`, the run's state (`Context`) and its settings (`WindowMode`, `Cursor`), text entry (`EditableText`) and `source_path`.

- **Types:** [`Context`](core/context.md), [`WindowMode`](core/windowmode.md), [`Cursor`](core/cursor.md), [`EditableText`](core/editabletext.md)
- **Traits:** [`Program`](core/program.md)
- **Functions:** [`source_path`](core/source_path.md), [`run`](core/run.md), [`run_headless`](core/run_headless.md)

## [`create.input`](input/README.md)

The input devices `Context` holds: `Keyboard`, `Mouse` and `Gamepad`, and the `Key`, `MouseButton` and `GamepadButton` they are read with.

- **Types:** [`Keyboard`](input/keyboard.md), [`Key`](input/key.md), [`Mouse`](input/mouse.md), [`MouseButton`](input/mousebutton.md), [`Gamepad`](input/gamepad.md), [`GamepadButton`](input/gamepadbutton.md)

## [`create.math`](math/README.md)

Maths: `Point2D`, `Vector2D` and `Matrix`, `Random` and `Noise`, the easing curves, scalar helpers, `PI` and `TAU`, and the common `std.math` functions.

- **Types:** [`Easing`](math/easing.md), [`Point2D`](math/point2d.md), [`Vector2D`](math/vector2d.md), [`Matrix`](math/matrix.md), [`Random`](math/random.md), [`Noise`](math/noise.md)
- **Functions:** [`lerp`](math/lerp.md), [`map`](math/map.md), [`inverse_lerp`](math/inverse_lerp.md), [`smoothstep`](math/smoothstep.md), [`sign`](math/sign.md), [`fractional_part`](math/fractional_part.md), [`wrap`](math/wrap.md), [`degrees`](math/degrees.md), [`radians`](math/radians.md), [`ease`](math/ease.md), [`identity`](math/identity.md), [`inverse`](math/inverse.md), [`apply`](math/apply.md), [`translate`](math/translate.md), [`rotate`](math/rotate.md), [`scale`](math/scale.md)
- **Constants:** [`PI`](math/README.md#pi), [`TAU`](math/README.md#tau)

## [`create.time`](time/README.md)

Time: the run's frame clock (`Time`), the `Clock` a playhead keeps time by, and the wall clock (`DateTime`).

- **Types:** [`Time`](time/time.md), [`Clock`](time/clock.md), [`DateTime`](time/datetime.md)

## [`create.geometry`](geometry/README.md)

Shapes and curves, the traits that make a type drawable, and the collision tests: each region's `overlaps` and `contains`, and each curve's `intersects`.

- **Types:** [`Rectangle`](geometry/rectangle.md), [`Circle`](geometry/circle.md), [`Ellipse`](geometry/ellipse.md), [`Capsule`](geometry/capsule.md), [`Line`](geometry/line.md), [`Triangle`](geometry/triangle.md), [`Arc`](geometry/arc.md), [`Sector`](geometry/sector.md), [`Polygon`](geometry/polygon.md), [`Bezier`](geometry/bezier.md), [`Spline`](geometry/spline.md)
- **Traits:** [`Curve`](geometry/curve.md), [`Drawable`](geometry/drawable.md), [`DrawTarget`](geometry/drawtarget.md), [`Region`](geometry/region.md), [`Shape`](geometry/shape.md)

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
