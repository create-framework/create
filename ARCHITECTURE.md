# Architecture

How Create's source is organised: which package owns what, how a program imports it, and which
package may import which. Where a package's internals need more explaining, a README beside its
code goes into the detail; see [Package internals](#package-internals).

## Module layout

| Module | Path | Responsibility |
|---|---|---|
| root | `src/create/__init__.mojo` | The preamble: star-imports all ten subpackages below |
| `core` | `src/create/core/` | `Program`, the run state (`Context`, `Time`), the run loops (windowed, GPU, headless), `step`, folding events into the devices, `WindowMode`, `Cursor`, `EditableText`, `source_path`, `DateTime` |
| `input` | `src/create/input/` | The devices `Context` holds: `Keyboard` (keys, typed text), `Mouse`, `Gamepad`; `Key`, `MouseButton`, `GamepadButton` |
| `render` | `src/create/render/` | `Canvas` and its `with`-block guards, `Style`, `Camera`, `Antialiasing`, `Autoscale`, `Align` (text anchoring), `StrokeCap`, `StrokeAlign`, `RenderBackend` (`run`'s CPU/GPU choice; `from_arguments` reads it from a `gpu` argument), text layout, the command buffer, both backends (CPU rasteriser, GL 3.3) |
| `color` | `src/create/color/` | `Color`, `Gradient` (with the ramp and dither both backends share), `BlendMode` |
| `math` | `src/create/math/` | `Point2D`, `Vector2D`, `Matrix` and its functions, `Random`, `Noise`, `Easing`/`ease` and `Tween`, `PI`/`TAU`, util functions, re-exported `std.math` functions |
| `geometry` | `src/create/geometry/` | The shapes (`Rectangle`, `Circle`, `Ellipse`, `Capsule`, `Triangle`, `Sector`, `Polygon`, `Line`, `Arc`), `Bezier`, `Spline`, the `Shape`/`Region`/`Curve` and `Drawable`/`DrawTarget` traits, `overlaps`/`contains`/`intersects`, corner rounding's maths. One file per shape; `_collider.mojo` decides every test between a `Circle`, `Capsule`, `Rectangle`, `Triangle` or `Line` as a convex core grown by a radius |
| `image` | `src/create/image/` | `Image` (BMP/PNG/JPEG), `PixelBuffer`, `Animation`, `Animator` |
| `text` | `src/create/text/` | `Font` (FreeType faces, glyph rasterisation), `FontWeight`, the packaged Noto faces (compiled in: `_noto.mojo`, generated from `fonts/`) |
| `audio` | `src/create/audio/` | `Sound` (WAV/OGG/FLAC/MP3), `Audio` playback, `Voice` |
| `data` | `src/create/data/` | `Table`/`TableRow` (CSV/TSV), `JSON`, `JSONKind` |
| `_bytes` | `src/create/_bytes.mojo` | Internal leaf: little-endian integers, C strings, base64 |
| `_library` | `src/create/_library.mojo` | Internal leaf: `load_library`, every FFI binding's way to open a shared library (by soname, `.so.N`/`.N.dylib`, the pixi environment first) |
| `_window` | `src/create/_window/` | Internal platform layer: `Window`, `GLWindow`, typed `Event`s, SDL3 video bindings |

## Imports and public surface

A program writes `from create import *`. Otherwise import by name from the owning package
(`from create.geometry import overlaps`); a single subpackage star is not a preamble.

- The root has no names of its own — it star-imports the ten subpackages. Never add a name there;
  add it to the owning subpackage.
- A subpackage exports only what it owns, never a lower layer's symbol. The one exception is
  `math`, which also re-exports common `std.math` functions (`sqrt`, `sin`, `cos`, `atan2`, `clamp`,
  `floor`, …) so a sketch has them without a second import, as in Processing. Mojo builtins
  (`abs`, `min`, `max`, `round`, `pow`) are already in scope and are not re-exported.
- Public surface is exactly what an `__init__.mojo` lists. A new declaration is internal unless it is
  added to one in the same change: `_module.mojo` for a wholly internal file, `_name` for an internal
  declaration in a public module. Tests reach internals by explicit path.
- A public type's fields of internal types are `_`-named. Mojo has no private initialiser, so an
  internal constructor takes only `_`-prefixed keyword-only arguments (`JSON(_document=…, _index=…)`):
  the keywords mark it as the library's own, even where an internal type shows in the signature.

## Layering

- **`render` never imports `core`** (it would be a cycle). `render` depends only on `math`, `geometry`,
  `color`, `image`, `text`, `_bytes` and `_library`, so it works without a run loop. So the mapping dials reach `render` as
  plain values: `context._set_viewport(state, …)` in `core` passes the design size and autoscale
  in, and `context._new_canvas(state^)` builds the frame. Frame-wide drawing settings live on
  `_PersistentCanvasState` itself.
- **`geometry`** depends only on `math`, so collision code (`overlaps`, `contains`) never sees
  `render`; `render` imports it.
- **`color`** depends only on `math`; `image` and `render` both import it. It sits below `image` so
  that `Image.pixel` can return a `Color` without a `render`↔`image` cycle.
- **`data`** imports nothing from `create`: files through the stdlib's `open()`, numbers through
  `atof`. Nothing imports it but the root.
- **`text`** depends only on `_bytes` and `_library`. `render`→`text` is nominal, like `render`→`image`: `Style`,
  `canvas.font` and text layout name `Font`, and `_raster.blit_glyph` takes `_GlyphInfo` by its
  internal path.
- **`input`** depends only on `math`; `core` imports it. Its devices are plain state: `core`'s
  `apply_events` folds each window event in through one `_`-prefixed method per kind
  (`keyboard._key_down`, `mouse._button_down`, …), so `input` never sees an `Event` and `_window`
  stays `core`'s alone.
- **`_bytes`** is a leaf imported by `image`, `text`, `audio` and `render`, re-exported by nothing.
- **`_library`** is a leaf imported by every package with FFI bindings, `_window` included. A
  binding opens its library with `load_library("libname", version)`, the soname's version, never
  `_DLHandle("libname.so")`: the platform's file name and search path are decided there. The
  versioned name is the runtime package's, so a system without `-devel` packages has it.
- **`_window`** imports nothing from `create` but `_library`; `core` is its only consumer; nothing
  re-exports it.
- **`render`→`image` is nominal:** only `canvas.image`'s overloads and `canvas.snapshot` name
  `Image`/`Animator`.
  A `render` function that needs pixels takes a pointer plus width/height, not an image type.

## Package internals

Package internals are documented in each package's README: [src/create/render/README.md](src/create/render/README.md),
[src/create/core/README.md](src/create/core/README.md), [tests/README.md](tests/README.md).
