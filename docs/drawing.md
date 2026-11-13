# Drawing

## Drawing shapes

`canvas.draw(shape)` draws any shape or curve — `Rectangle`, `Circle`, `Ellipse`, `Capsule`,
`Triangle`, `Sector`, `Polygon`, `Line`, `Arc`, `Bezier`, `Spline` — in the current style and transform. The named
methods build a shape from numbers and draw it: `canvas.rectangle(p, w, h)` is
`canvas.draw(Rectangle(p, w, h))`. A shape value is drawn with `draw`; there is no
`canvas.rectangle(r)`.
- **A program's own type** is drawn the same way by conforming to `Drawable` and drawing its
  parts: `def draw_to[T: DrawTarget](self, mut target: T): target.draw(self.body)`. Style comes
  from the canvas, not the parts. See [examples/drawables/main.mojo](../examples/drawables/main.mojo).
- `Drawable`, `DrawTarget` and the shape traits live in `geometry`, so a shape never imports `render`:
  `Canvas` is the `DrawTarget`, its `_`-named primitives are the library's own. Dispatch is
  static (one instantiation per type); a mixed list still needs `Variant`.

## Style and clear

`Style()` defaults are not blank: **stroke `BLACK`, on, 1 unit**; fill `WHITE`, off; `BLACK`
text. Every frame opens with a clear to gray 200 so those defaults are visible;
`canvas.background()` is the only way to choose the colour. `corner_radius` is style only for
shapes the canvas builds from numbers; a shape value keeps its own (see [`corner_radius`](geometry.md)), so
`with canvas.style(corner_radius=8): canvas.draw(rect)` does not round `rect`.
- An opaque `canvas.background()` replaces that clear rather than painting a second time; a
  translucent one blends over it.
- `canvas.autoclear(enabled)` switches that clear off or back on for the whole current frame —
  off takes the frame's opening clear back out, on puts it back; an opaque `background()` already
  drawn stays — and lasts until changed, so set it once in `create`. Off lets ink accumulate (CPU
  backend only — GPU swaps buffers).

**Canvas settings that outlive the frame**, unlike style, transform, camera and clip, are carried
from frame to frame (on the internal `_PersistentCanvasState`) and last until changed — set them once in `create`: the frame-wide
`autoclear`, `letterbox_color` (the bars outside the design under `FIT`, black by
default) and `antialiasing`. A frame-wide setting applies to the whole frame it is set in, since
nothing is rasterised until present, and reads back with no arguments.

`fill`, `stroke` and `text_color` set three independent colours; `fill_enabled(False)` does not
hide text. Text is hidden by a zero-alpha `text_color`. `fill_enabled`/`stroke_enabled` switch
off without losing the colour; `fill(...)`/`stroke(...)`/`shadow(...)` switch back on, and with
no arguments keep every part, so `fill()` alone paints the default white.

**Three ways to style**, all additive:

| Form | Effect |
|---|---|
| `canvas.fill(Color.RED)` (any setter) | Rest of the frame |
| `with canvas.style(fill=Color.RED):` | Only the named fields, for the block (each goes through its setter) |
| `with canvas.style(heading):` | A whole `Style` value, for the block — unset fields are `Style()` defaults, not the previous style |

`Style(...)` takes the setters' names as keywords and, like them, naming any part of the fill,
stroke or shadow switches it on unless its `*_enabled` keyword says otherwise. A reusable style is
a field built in `create`.

**Fonts** are part of the style: `canvas.font(f)`, `Style(font=f)` or `with canvas.style(font=f):`,
beside `font_size`, `font_weight` and `font_italic`. `f` is a `Font.load(source_path("..."))` kept as a field — a
shared asset like an `Image`, cheap to copy, closed when its last copy goes. With none set, text is
packaged Noto Sans, and a codepoint the face lacks falls back to Noto Sans Symbols. Each `text`
call keeps its face, so several share a frame; like every style setter, `canvas.font` resets
next frame. Switching faces costs nothing: cached glyphs are keyed by face.

**Italic** is `canvas.font_italic(True)` (or the `font_italic=` keyword), and always slants, from
the best source the font has: the `italic_path` file of `Font.load(path, italic_path=...)` (the
packaged Noto Sans ships its italic this way), else the file's own `ital` or `slnt` axis, else its
upright glyphs sheared 12°. Fallback glyphs follow, so Noto Sans Symbols comes out sheared. Weight
reaches a variable italic like an upright. A shear's overhang is not measured: `text_width` is the
advance, as in CSS.

**Gradients** fill regions and backgrounds: `canvas.fill(gradient)` and `canvas.background(gradient)`
are overloads beside the colour ones, and the `Style`/`canvas.style` keyword is `fill_gradient=`,
not `fill=` — one keyword can't take both types, and an `Optional[Paint]` wrapper would need two
implicit conversions from a bare `Color`, which Mojo won't chain.
- While set, the gradient fills and `fill_color` is kept: `fill(color)` clears the gradient,
  `fill()`/`fill_enabled(...)` keep it. Given `fill=` and `fill_gradient=` together, the gradient
  wins.
- Fills only: strokes, lines, curves and text ignore it, and a shadow stays the silhouette in
  `shadow_color` (a fill fading to transparent still casts a full shadow).
- `background(gradient)` spans the screen (`left()`…`top()`), ignoring the camera; it replaces the
  autoclear only if every stop is opaque.
- Build one in `create` and keep it as a field (or in a `Style`): construction samples its ramp, and
  the GPU uploads one ramp per distinct set of stops.

**Strokes** are style like the rest: `canvas.stroke(color, thickness)`, `stroke_enabled`, and two
settings that place the paint.
- **`stroke_alignment(StrokeAlign.INSIDE/CENTER/OUTSIDE)`** puts a region's stroke inside its edge
  (the default), centred on it or around it; the fill meets the stroke's inner edge, so `OUTSIDE`
  leaves the whole shape to the fill. Regions only (rectangle, circle, triangle, sector, polygon):
  lines and curves have no inside and are always centred. A self-crossing polygon's seams (edges
  through its inside) stay centred under every alignment. `INSIDE` keeps drawn pixels within what
  `contains`, `overlaps` and `clip` see. Shadows and a gradient fill follow the shape, not the
  stroke: the gradient spans the true shape whatever the alignment.
- **`stroke_cap(StrokeCap.BUTT/ROUND/SQUARE)`** ends an open stroke — `Line`, `Arc`, `Bezier`, an
  open `Spline` — flush (the default), with a half disc, or half the thickness further square. A
  closed curve and a shape's stroke have no ends. A zero-length line draws nothing butt, a dot
  round and an axis-aligned square square. Caps composite with the stroke once, translucent or
  not, and are part of its shadow, so segments drawn end to end with `ROUND` meet without notches.

**Shadows** are part of `Style`, **off by default**: `canvas.shadow(color=, offset=, blur=, spread=,
inset=)` switches one on (unset parts keep their values, so `shadow()` alone switches the current
one on; an unset part is `None`, like every optional keyword; a `Float64` one — `blur`, `spread`, `thickness`, `font_size`, `opacity` — is the internal `_OptionalFloat64`, which takes `12`, `1.5`, `None` or an `Optional[Float64]` in one step, since an integer literal won't convert through `Optional[Float64]`),
`shadow_enabled(False)` switches it off, and `canvas.style(...)` takes the same parts as `shadow*`
keywords.
- **One silhouette, like CSS `drop-shadow`:** fill plus stroke cast together (stroke only casts
  a ring); lines and arcs cast their stroke, text its glyphs, images their alpha. A translucent fill shows
  its own shadow through it. Clear, background and letterbox never cast.
- **`blur` is the CSS radius** (σ = blur / 2); `blur` and `spread` are world units, scaled like
  coordinates. Blur 0 is hard.
- **`shadow_inset`** paints inside the shape instead, after it, clipped to the interior within the
  stroke. Rectangles, circles and triangles only — sectors, polygons, lines, arcs, text and
  images cast nothing while it is set.
- **The offset is screen-fixed** by default (`(4, -4)`, down-right): rotation doesn't turn it, but
  camera zoom and autoscale scale it. `shadow_follows_transform(True)` turns it with the shape.
- Shadows use the command's own tint, opacity and blend mode.

**Tint, opacity and blend modes reach every render call** (images included, `background()` never), and
every shape composites once: fill and stroke never overlap, so a translucent shape is evenly
translucent. `canvas.tint(color)` multiplies every colour of the call — fill, gradient stops,
stroke, text, shadow, each image texel — channel by channel; white (the default) is no tint, and
its alpha stacks with `opacity`. It recolours a whole look at once, where `fill`/`stroke`/
`text_color` set one part each; scope it with `with canvas.style(tint=...)`. Multiplying only
darkens, so it can't flash a sprite white.

**Scope with the guards.** `canvas.transform(m)`, `canvas.style(...)`, `canvas.overlay()` and
`canvas.clip(...)` return `with`-block guards that unwind on exit. Bare style mutators straight from `update` are fine (style,
transform and camera reset every frame); a *helper* that sets style wraps it in `canvas.style()` so it
can't leak into the caller's next render.

## Antialiasing

`run(..., antialiasing=Antialiasing.MEDIUM)` is the starting level; `OFF`, `LOW` and `HIGH` are the
others, and `canvas.antialiasing(level)` changes it for the whole frame it is called in (both
backends rasterise at present) and every later one. One setting for both backends, each reaching
it its own way: the GPU draws into an offscreen multisampled framebuffer and resolves it into the
window or headless target (capped at the driver's maximum), the CPU samples each shape on a finer
grid (`LOW` 2x2, `MEDIUM` 4x4, `HIGH` 8x8 per pixel). Shapes, and the edge of a rotated or
sheared image — text and an image's own pixels are smooth already; a clip's edge is antialiased
like a shape's (see [Clipping](#clipping)). A shape's fill and
stroke composite together, so no seam shows between them; two separate shapes meeting inside a pixel can
show a faint one. `run_headless` defaults to `MEDIUM` too, so a test asserting an edge pixel's exact
colour passes `antialiasing=Antialiasing.OFF`.

## Clipping

`with canvas.clip(region):` renders only inside `region` for the block; `invert=True` keeps only
what is outside it (fog, a spotlight). `region` is any `Region` — a `Rectangle`, `Circle`,
`Ellipse`, `Capsule`, `Triangle`, `Sector` or `Polygon`, the region types of `contains`/`overlaps` — rounded by its own
`corner_radius` as when drawn; a curve is rejected at compile time. Guard-only: there is no bare clip to forget to undo. See [examples/clipping/main.mojo](../examples/clipping/main.mojo).
- **Frozen at the call**, like a render call: placed by the transform and camera current then. A
  `transform` or `overlay` inside the block moves what is drawn, not the clip.
- **Nested clips intersect.** On exit the enclosing clip is current again.
- **Everything is clipped** — shapes, images, text, shadows, and `background()`, which then paints
  only the clipped area (and never replaces the autoclear). The letterbox is not.
- **Edges** are antialiased at the frame's level, like a shape's: on the CPU a clip keeps exactly
  the coverage a fill of the same shape paints, on the GPU its stencil is multisampled. So the two
  backends agree inside a clip and may differ slightly along its rim. With `Antialiasing.OFF` a
  clip is hard-edged. Nested clips multiply their edges' coverage.
  Soft masks (a gradient or an image's alpha) are not implemented yet.

## Terms

| Term | Meaning |
|---|---|
| `Gradient` | Stops (0..1 positions, each a `Color`) across a fill or the background. **Placed by the shape's local bounding box**, before the transform, so it moves and turns with the shape and one `Style` suits every entity. `linear` runs along `direction` (a `Vector2D`, default `DOWN`, any length; its extreme corners land on 0 and 1, as in CSS); `radial` runs from `center` in the box's unit space (-1..1, y up) out to its edges, an ellipse on a long box. A sector's box is its whole circle. A zero `direction` or a zero-size box paints the first stop. Blends premultiplied (a fade to `TRANSPARENT` stays clean) and is dithered on both backends |
| `Drawable` / `DrawTarget` | `Drawable` is what `canvas.draw` takes: every shape, or a program's own type that draws its parts (`draw_to[T: DrawTarget](self, mut target: T)`). `DrawTarget` is where it draws: `Canvas`, through one `_`-named primitive per kind and the provided `draw` |
