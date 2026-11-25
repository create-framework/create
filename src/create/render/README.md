# `create.render` internals

`create.render` turns drawing into pixels. A `Canvas` render call records a command and touches no
pixels. When the frame is presented, a `Backend` replays the frame's commands, on the CPU rasteriser
or through OpenGL 3.3. Pixel reads and captures replay on the CPU either way. This page is for
working on the package: the [user guide](../../../docs/guide/README.md) covers using it, and
[ARCHITECTURE.md](../../../ARCHITECTURE.md) where it sits and the layering rules.

## Files

| File | Role |
|---|---|
| `canvas.mojo` | `Canvas` (records commands, touches no pixels), `_PersistentCanvasState`, the guards |
| `_command.mojo` | `RenderCommand`, its `RenderPayload` variant (one struct per kind) and their builders; `_fill_box`, the box a fill gradient spans |
| `_paint.mojo` | `Paint`, what a command paints with (fill, stroke, shadow, blend mode), and `TextStyle`, what text is set in |
| `drawable.mojo` | `Drawable`, a program's own type that draws its parts onto a canvas |
| `_geometry_target.mojo` | `_GeometryTarget`, what takes one primitive per kind of shape, and `draw_geometry`, the one place a generic `Geometry` is matched to its kind |
| `_shape_command.mojo` | `shape_command` (one overload per kind) and `curves_command`: a shape as the command that records it, ellipses, capsules and rounded polygons and sectors flattened; `RegionCapture`, the geometry target a clip draws its region into |
| `_backend.mojo` | `Backend` — the command buffer, reads and captures; replays commands via `present` (CPU) or `present_gpu` (through the GL loop's `GLRenderer`) |
| `_backend_handle.mojo` | `BackendHandle` — how `_PersistentCanvasState` holds its `Backend`: on the heap, built and dropped by the compiled library, reached through `handle[]` |
| `_resources.mojo` | `Resources` — the text renderer and the interned images, which every replay draws from |
| `_command_buffer.mojo` | `CommandBuffer` — the frame being recorded: its commands, its `canvas.clip` levels, the record count reads are cached against, and the opening clear `autoclear` switches |
| `_captures.mojo` | `Captures` — the `save_image`, `save_screenshot` and recording requests and the recording's state (GIF writer, slot timing); the backend does their replays |
| `_cpu_replay.mojo` | `CpuReplay` — commands rasterised onto a `Surface`: the CPU backend's presents and every capture and read; shadows, clips and antialiasing around the rasterisers. Handed the images, clips and antialiasing by `Backend.replay`, as `GLRenderer.render` is |
| `_raster.mojo` | CPU rasteriser over a `Surface`; called only from `_cpu_replay.mojo` |
| `_surface.mojo` | `Surface`, the borrowed RGBA view the rasteriser writes, and `MemorySurface`, an owned buffer (headless runs, pixel reads, offscreen canvases); `run_headless` hands its pixels over as an `Image` |
| `_gif.mojo` | The GIF writer behind `canvas.start_recording`: per-frame quantising (exact up to 256 colours, else median cut, optional Floyd-Steinberg, optionally a transparent index for pixels under half alpha), LZW, frames covering a rectangle of the image with a disposal (`DISPOSE_KEEP`, `DISPOSE_BACKGROUND`), and `GifWriter`, which streams frames to the file |
| `_gl.mojo` | GL entry points resolved at runtime; the only file that talks to the driver |
| `_text.mojo` | `TextRenderer` — the glyph cache and layout both backends place text with; faces are `create.text.Font` |
| `_gl_backend.mojo` | `GLRenderer` — shader, vertex buffer, glyph atlas, image textures, batching |
| `_tessellate.mojo` | `RenderCommand` to triangles for the GPU |
| `_stroke.mojo` | Stroke alignment for both replays: `stroke_offset` (how far a command grows) and `aligned_stroke` (the command grown so its inset ring lands where `stroke_alignment` says) |
| `stroke_cap.mojo` / `stroke_align.mojo` | The public `StrokeCap` and `StrokeAlign` enums |
| `stroke_dash.mojo` | The public `StrokeDash`: its presets, patterns and `_resolved`, a preset as lengths |
| `_dash.mojo` | Dashed strokes for both replays: the stroke's middle per kind, the pattern walked along it (`dash_path`), each dash a `stroke_pieces` strip (`dashed_stroke`) |
| `_shadow.mojo` | Shadow geometry shared by both backends: `shadow_command` (the hard silhouette as a command, offset matrix composed in), `BlurredSilhouette` (analytic Gaussian coverage for shapes), `InsetRegion` (a rectangle's or circle's inset interior and cut) |
| `_inset.mojo` | Inset shadows for both backends: `inset_uncovered` (how much of each interior pixel the silhouette leaves uncovered), `interior_pieces`, `inset_layer` (text or an image drawn with its shadow mixed in) |
| `_pieces.mojo` | `Pieces`, a shape as convex device pieces (fill and stroke, quads and polygons); `fill_pieces`, the CPU's one way to fill them; `pieces_mask` and `pieces_shadow_mask`, their mask, sharp and blurred |
| `_lower.mojo` | `shape_pieces`, the one lowering of every kind but rectangles and circles (lines, curves, sectors, polygons, triangles; and any dashed shape) to `Pieces`; `shape_shadow_mask`; `is_lowered`, `is_plain_triangle` |
| `_curve.mojo` | Bézier stroke geometry: flattening in device pixels, the mitred quad strip and its caps (`stroke_pieces`) |
| `_sector.mojo` | Sector fill and stroke tiled into device quads (`sector_quads`, returning `Pieces`) |
| `_polygon.mojo` | Polygon fill and stroke tiled into device quads (`polygon_quads`, returning `Pieces`) |
| `_triangle.mojo` | A rounded or stroked triangle as a convex fill and ring quads (`triangle_pieces`, returning `Pieces`) |
| `_coverage.mojo` | CPU antialiasing: `composite_coverage` turns a shape's runs recorded on a finer grid into per-pixel coverage, composited once |
| `_clip.mojo` | `_Clip` (one `canvas.clip` level: region command, invert, parent) and `_ClipRows`, the CPU replay's per-row runs of a clip, each with its coverage |
| `_blur.mojo` | Three-box-blur approximation of a Gaussian over an alpha mask, for text and image shadows; `PlacedMask`, a mask placed on the device; the blurred-mask cache limit and key |
| `_transform.mojo` | Shared by both replay paths (split out to avoid an import cycle, so both agree on the numbers) |
| `_image_mapping.mojo` | Where an image lands, for both replays: `upright` (the plain blit's device rect, `upright_rect`) or not (`image_mapping`, the device-to-texel inverse; `image_corners`, the GL quad) |
| `_gl_target.mojo` | Offscreen FBO of an exact size, for the parity test and headless GPU |

Corner rounding's maths (the clamps, `corner_fillet`, `rounded_vertices`, `rounded_sector_vertices`)
lives in `create/geometry/_fillet.mojo`, so the geometry's `contains`/`overlaps` and both replays
agree on it.

## Canvas, commands and backends

A `Canvas` render call **records, never paints**: it appends a `RenderCommand` (local geometry,
transform at record time, style resolved now) to the `Backend`. Nothing rasterises until
`present`/`present_gpu` replays the frame, so later style calls can't reach back. Images are
interned into the backend at record time (the command carries an id); text is recorded as an owned
`String` and laid out at replay. Add a shape by adding a payload to `_command.mojo`'s
`RenderPayload` and lowering it in `_lower.mojo`'s `shape_pieces` (below), never by calling
`_raster.mojo` from `Canvas`.

**Every kind but two is lowered to pieces.** A line, a curve, a sector, a polygon or a triangle
reaches both replays through `shape_pieces(c, m, scale)`, which gives convex device pieces for the
fill and the stroke, holding only what the paint shows. The CPU fills them with `fill_pieces`:
`fill_quad` for each quad, and `fill_convex` for each polygon, whose half-open rule composites a
shared edge once. The GPU pushes them with `emit_pieces`. A blurred shadow is the shadow command's
pieces, masked (`shape_shadow_mask`). So both replays draw the same pieces, and a new lowered kind
needs only a branch in `shape_pieces` and a tiler returning `Pieces`; no backend has to learn it.

Rectangles and circles are not lowered: each replay rasterises them from their equations
(`CpuReplay._rect`/`_circle`, `emit_rect`/`emit_circle`), which is where they are fast. Their
shadows blur analytically, unless their stroke is dashed (see Dashes). A plain triangle's fill, with
no rounding and no visible stroke (`is_plain_triangle`), isn't lowered either: it is one
`fill_triangle` pass on the CPU, or one triangle on the GPU.

**`render` decides how every shape is drawn; a shape knows nothing of drawing.**
`canvas.draw(shape)` calls `draw_geometry` (`_geometry_target.mojo`), which matches the shape's type
to its kind when the program is compiled and calls the target's primitive for it (`_rectangle`,
`_circle`, `_ellipse`, `_capsule`, `_triangle`, `_sector`, `_polygon`, `_line`, `_curves`); on
`Canvas`, each records `shape_command(shape, transform, style, scale)`. The targets are `Canvas`,
`RegionCapture` and `ui`'s recorder, each a `_GeometryTarget`. The named methods
(`rectangle(position, width, height)`, …) only build the shape, resolving `corner_radius` against
the style, and call `draw`. A program's own type is a `Drawable` (`drawable.mojo`), whose
`draw_to(canvas)` draws its parts. A new shape kind needs a geometry type, a branch in
`draw_geometry`, a primitive on `_GeometryTarget` and its targets, a `shape_command` overload, and
the payload above.

**A command is a header and a payload.** The header — `transform`, `paint`, `clip`, `stroke_grow` —
is every kind's; `payload` is a `Variant` of one struct per kind (`ClearPayload`, `RectPayload`,
`CirclePayload`, `LinePayload`, `TrianglePayload`, `ImagePayload`, `TextPayload`,
`LetterboxPayload`, `CurvesPayload`, `SectorPayload`, `PolygonPayload`), each naming its own fields.
Test the kind with `c.payload.isa[RectPayload]()` and read or change it through
`c.payload[RectPayload]` (bind it once with `ref rect = c.payload[RectPayload]`); `c.is_region()`
and `c.is_shape()` name the groups the replays dispatch on. Reading the wrong payload aborts rather
than reading another kind's numbers.

**A `Style` is a set of changes; the canvas holds a `_ResolvedStyle`.** The public `Style` has an
`Optional` field per part, and a part left unset changes nothing. The canvas's own style, the one
its setters write and every command reads, is an internal `_ResolvedStyle` with every part decided
(`style.mojo`). `canvas.style(s)` applies `s` to it through `_ResolvedStyle.apply`, which mirrors
the setters' rules, and its guard restores the whole resolved style; the keyword form calls the
setters directly, which measured faster than building a `Style` to apply. `ui` resolves its widgets'
looks the same way and replays them with `canvas._with_style`. Below, "the style" is the resolved
one.

**A command keeps what it paints with, not the `Style`.** `paint` is a `Paint` (`_paint.mojo`): the
style's fill, stroke, shadow and blend mode, field for field, from `style._paint()`, with tint and
opacity folded into its colours by `RenderCommand.__init__`. What only one kind reads rides on its
payload: a text command's face, size, weight, slant, alignment and colour are a `TextStyle`
(`style._text_style()`), an image's tint is `ImagePayload.tint`. The `TextStyle` sits behind an
`ArcPointer`. A `Font` alone is 80 bytes, and a `Variant` is as large as its largest arm, so held
inline it made every command's payload as large as a text command's, and replay measurably slower.
Copies share it, so change it through `TextPayload.recolor`, which copies first. The builders still
take the resolved style. The visibility checks the replays gate on (`_fill_visible`,
`_stroke_visible`, `_shadow_visible`) are `Paint`'s.

**A canvas records in the program and replays in the compiled library** (see [The compiled
library](../../../ARCHITECTURE.md#the-compiled-library)). The recording calls stay source: they
build a command and append it through `self._state._backend[].buffer`, which compiles only the
command buffer. Every method that reaches a replay, the text renderer or a capture (`color_at`,
`snapshot`, `save_image`, `save_screenshot`, the recording calls, `text_width` and `text_height`,
and interning an image) does its work in a `_here` twin, which the program reaches through the
library's entry point and the library calls directly. A new such method follows the same pattern.

`Canvas` holds no `Surface`, and takes its geometry from the `Viewport` alone. Don't add a `Surface`
field or parameter, and don't import `_window` from `canvas.mojo`. Two things survive the frame
boundary:

- `_PersistentCanvasState`: the `Backend` and the `Viewport`, which `_release` moves in and back
  out, and the frame-wide settings a program sets on the canvas: `autoclear`, `letterbox_color`,
  and, through the backend, `antialiasing`.
- `Context`, in `core`, owned by the loop and home to `time` and `input`. Its settings that map the
  design onto the window reach `Canvas` as plain values, through `_set_viewport`.

The transform stack, the style and the camera deliberately don't survive it.

A frame-wide setting applies to the whole frame it is set in, because nothing is rasterised until
present: `_render_letterbox` reads `letterbox_color` at the end of the frame, and both replays read
`antialiasing` when they run. `canvas.antialiasing` bumps `CommandBuffer.recorded` so a cached read
replays at the new level.

The camera is folded into `RenderCommand.transform`; nothing below `Canvas` knows it exists.

**The loop picks the replay, not the backend.** `run` branches on its `backend` argument once, into
the CPU loop or the GL one, and only the GL loops (`_run_gl`, `_headless_gl`) own a `GLRenderer`:
built after their window, since its GL resources need a current context, and dropped before it. They
pass it to `Backend.present_gpu(gl, …)`; the CPU loops call `present(surface, …)`. So a `Backend`
never holds GPU state, and there is no backend kind to get wrong. Everything a canvas needs,
whichever loop presents it, is on the `Backend`: recording, text measurement, images, reads and
captures. Reads and captures replay on the CPU either way.

The autoclear is a recorded `ClearPayload`, so every path handles it: the GPU turns it into
`glClear`, an opaque `canvas.background()` replaces it via `CommandBuffer.record_clear`
(`_clear_is_opaque`), and a transparent `save_image` masks it out. `Canvas`'s constructor records it
through `CommandBuffer.open_with_clear`, which sets `autoclear_head`: the frame's first command is
still that clear. `canvas.autoclear(...)` calls `CommandBuffer.set_autoclear`. Switching the
autoclear off takes the clear back out, but only while `autoclear_head` holds: a `background()` that
replaced the clear stays. Switching it on inserts the clear at index 0. Either way, it bumps
`recorded`.

## Gradients

A fill gradient rides on the command's `Paint` (`fill_gradient`); tint and opacity multiply its
stops at record time. Everything a replay needs comes from three pieces in
`create/color/gradient.mojo`, shared so the backends agree:
- **The ramp:** `_RAMP_SIZE` (256) colours sampled from the stops at construction, behind an
  `ArcPointer` with the stops, so copying a `Gradient` (and the `Style` or `Paint` holding one) is a
  refcount.
- **The device mapping:** `_device_mapping(m.inverse(), center, half)`, with the box from
  `_fill_box(c)`. The parameter (linear) or the position whose length it is (radial) is **affine in
  device pixels** — the whole design rests on that.
- **The sample:** `_sample(t, x, y)` reads linearly between two ramp entries and adds the 4x4 Bayer
  threshold (`_BAYER`) before flooring to bytes. Exact ramp colours come out unchanged.

**CPU:** the fill call sites pass a `FillPaint` (`_raster.mojo`) from `_fill_paint(c, m)`. A `Color`
converts to a `FillPaint` implicitly, so stroke and shadow calls are untouched. `fill_span`'s
`FillPaint` overload is the choke point: a solid goes to the colour loop, a gradient to
`_shade_span`, which steps the mapping along the row and `blend`s each pixel. Decide
solid-or-gradient once per run (or per rect, in `fill_pixels`), never per pixel; a solid `FillPaint`
is a colour and two empty `Optional`s. The other, `inset`, mixes an inset shadow over the paint per
pixel (`_InsetShade`), which goes through `_shade_span` as a gradient does. `shadow_command` clears
the gradient, since a shadow is one colour.

**GPU:** the fill emitters take a `ramp_row`; after emitting a fill, `_shade_fill` rewrites that run
of vertices to `MODE_GRADIENT` with the mapping's value at each vertex — the same post-pass
`emit_inset_shadow` uses. So a fill's vertices must be one contiguous run (`emit_circle` emits its
fan, then its ring). The ramp texture (256x256 RGBA, unit 2) holds one ramp per row, cached by
`_stops_key` + `_same_stops` across frames; full, it flushes and starts over. Linear filtering along
the row is the CPU's read between entries; the shader indexes `BAYER` by device pixel counted from
the top, as the CPU does.

**Background:** `background(gradient)` records a `ClearPayload` sized to the design area, with the
canvas's base matrix, so `_fill_box` and the mapping work as for a rect, and a capture's `pre` maps
it like any command. The CPU shades every row; the GPU draws a framebuffer quad (never `glClear`,
which takes one colour).

Parity is checked per pixel, not just structurally: `test_gradient_fill.mojo` renders each scene on
both backends and compares away from edges within one level.

## Curves

A `CurvesPayload` records a **chain** of cubic Béziers as control points in `points`: 3n+1 for n
curves, each ending where the next starts (`bezier_command` records a chain of one,
`bezier_chain_command` any). Each replay maps them through the command's transform (a Bézier is
affine-invariant), flattens each curve in device pixels (`FLATTEN_TOLERANCE_PX`) so it stays smooth
under any zoom, and joins the pieces into one polyline. `stroke_quads` turns that into a strip of
quads sharing mitred edges, which the CPU fills with `fill_quad` and the GPU pushes as vertices. The
quads leave no gap and don't overlap, so a translucent stroke composites once, across the joints
between curves too. Ends follow `stroke_cap` (below); a polyline whose last point is its first is a
ring instead, its closing joint mitred like any other. Known limitation: at a cusp the miter is
clamped (`MITER_LIMIT`) and the quads either side overlap slightly.

`stroke_pieces(points, width, cap, x_axis)` returns the strip as `quads` plus convex `caps`.
`SQUARE` pushes both end points out by half the width along the end tangent, so it is quads only.
`ROUND` adds a half disc per open end whose first and last vertices are exactly the end quad's
corners, so the shared edge composites once: the CPU fills it with `fill_convex` (edges walked as
`fill_quad` walks them), the GPU fans it. A ring gets no caps. A zero-length path gives one disc
(`ROUND`), one square lined up with the local x axis (`SQUARE`) or nothing. A `LinePayload` strokes
through the same function, a two-point path, so lines and curves cap alike.

`canvas.spline` converts its `Spline` (Catmull-Rom) to Béziers **at record time, in local space**,
and records one chain. The conversion is exact, and doing it before the transform matters: the
centripetal knot spacing depends on distances, which a non-uniform scale would change, so a spline
converted after it would change shape rather than just stretch. Separate commands per curve would
meet on their ends (butt, or overlapping round caps) and double-blend a translucent joint; one chain
doesn't.

## Dashes

A dashed stroke (`paint._stroke_dashed()`: a visible stroke whose `stroke_dash` isn't solid) is
lowered on **every** kind, so `is_lowered` is true for a dashed rectangle or circle too, and both
replays test it before their analytic rect and circle paths. `shape_pieces` hands it to
`_dashed_pieces`: the fill the solid stroke would leave (a lowered kind's own tiler with its stroke
dropped, or a rectangle's or circle's outline eroded by the thickness, one convex polygon) plus
`dashed_stroke`'s dashes as the stroke.

`dashed_stroke` finds the stroke's **middle** in device space: a line's or curve's path, or a
region's outline moved in by half the thickness. `dash_path` then walks the pattern along it,
stroking each dash with `stroke_pieces`, so a dash's ends take `stroke_cap` and a dash round a
corner is one mitred strip. A rectangle's, circle's and triangle's middle comes from their own
numbers, so rounding stays exact. A sector's and a polygon's is their outline with every vertex
mitred in (`_inset`), less their `grow`, so an alignment's or a shadow's spread moves it back out.
Beside a sharp corner, an edge shorter than the inset would fold, so `_inset` drops the smoother
vertex of any edge that runs backwards. Known limitation: a rounded polygon whose fillets are
tighter than half the stroke is only approximately inset.

**A preset becomes lengths at record time** (`StrokeDash._resolved`, from `Style._paint`), scaled by
the style's thickness, and `DOTTED` sets the cap to `ROUND` there. So a shadow, whose ring thickens
the stroke by the spread, keeps the shape's pattern. Lengths reach device pixels by `pixel_scale`,
as the thickness does. A cut that falls on a vertex snaps to it (`_SNAP_PX`): a point a rounding
error away would leave a segment of no direction for the next joint to mitre. A period under a
device pixel, or more than `_MAX_DASHES` dashes, draws the path solid.

**A resolved preset fits the path** (`_fit`, set by `_resolved`; a constructor's lengths never are).
`dash_path` measures the path, and `_fitted` changes only the gap, by at most half a period shared
among the gaps: a whole number of periods round a closed path, with the pattern started half a dash
early so a dash is centred on the start, or a dash at each end of an open one. A fitted gap that
isn't positive draws the path solid. On a closed path, a dash that is on at the start is held back
and joined to the last one when the walk comes round, so a dash across the seam is one strip,
mitred, rather than two capped ends meeting.

**Shadows** decide on the shadow command, not the shape: a stroke-only shadow keeps the dashes and
is lowered and masked (`blurs_analytically` is false for a dashed stroke), while a filled shape's
shadow is its solid silhouette, which still blurs analytically.

## Sectors

A `SectorPayload` (`center`, `r`, `start_angle`, `sweep_angle` and a `grow`) is tiled at replay by
`sector_quads` into convex device quads. Both backends draw the same quads, so they agree the way
curves do: the CPU fills them with `fill_quad`, whose half-open rule composites shared edges once,
and the GPU pushes them as vertices. The tiling walks the sweep in thin wedges about the tip, and
along each ray the sector is one stretch from the tip: fill in the middle, stroke either side. The
stroke is an inset ring, as a circle's is: the fill is the sector eroded by the stroke thickness
(alignment grows the sector first; see Strokes). The quads are built in local space and mapped per
corner, so a non-uniform transform gives an elliptical sector.

`grow` is 0 for a render call. A shadow adds its spread, and the tiling first grows (or shrinks) the
sector by exactly that, round the tip and the arc's ends and into the missing wedge. It doesn't lean
on a corner radius, since a `SectorPayload` has none. A stroke-only sector's shadow ring is the
grown sector's stroke band, thickened by twice the spread.

A **rounded** sector never reaches `sector_quads`: its `shape_command` records it as a
`PolygonPayload` through its outline (`rounded_sector_vertices`, each curve flattened as finely as a
circle of its radius is drawn), via `rounded_sector_command`, which keeps the sector's circle in its
`gradient_box` so `_fill_box` spans the circle as for a sharp sector.

`canvas.arc` needs none of this: it records a `CurvesPayload` chain.

## Polygons

A `PolygonPayload` (`vertices` and a `grow`) is tiled at replay by `polygon_quads` into the same
kind of shared convex device quads as a sector, in local space and mapped per corner. The cut is
into **horizontal slabs**: every y where an edge ends or two edges cross, so within a slab no edges
cross, the edges sort by x, and a walk from the left keeps a winding count per *layer*. The slabs
come from a sweep upwards: each runs to the next edge's start or end, cut down to the lowest
crossing between neighbours in its middle's order until none cross. Only neighbours need searching,
because any crossing inside a slab flips some neighbouring pair. Each stretch between neighbouring
edges is classified fill, stroke or nothing (`_classify`), runs of one class merge, and each run is
one trapezoid, every x taken from the edge's lower end so neighbouring quads share corners exactly.

Layer 0 is the polygon (nonzero). The others are **bands**: points within `d` of some lines,
counter-clockwise pieces wound together, inside where the count is not zero. The seams' band is a
rectangle along each seam and a polygonised disc at each end. `Polygon._pieces()` cuts the edges at
every crossing, each crossing found along the lower-indexed edge so both edges share its point
exactly, into the **rim** (outside along one side) and the **seams** (wound on both sides). The
outer band (radius `grow`) and the inner band (`grow - t`) are the rim's; offsetting by `d` is the
polygon with (outwards) or without (inwards) its band. The seam band has radius `t/2`: fill is the
inner offset off the seams, stroke the rest of the outer offset, so a seam is stroked centred and as
thick as the rim. A seam disc already inside an inner-band disc is left out.

A rim band is only read on one side of the rim: an inward offset inside the polygon, and an outward
one outside. So it is built for that side alone (`_add_rim_band`), and the region it gives there is
unchanged. A point on that side whose nearest rim point is a corner lies in the corner's normal
cone, which opens onto the side only where the corner is reflex from it: so a corner gets nothing
where it is convex from the side, and only a **pie** spanning its turn where it is reflex, and each
piece only the half of its rectangle on the side. `_rim_corners` tells which by probing the polygon
just inside each corner's narrower wedge; a corner that is not two pieces meeting keeps a whole
disc. A half rectangle's base lies on the rim's own line, so the walk across a slab skips the
stretches of no width between them rather than starting a run there.

`grow` is 0 for a render call and the spread for a shadow; a stroke-only shadow's thickness `t +
2·spread` grows the seam band by the spread too, so the ring is the stroke grown. The cost is the
number of slabs times the edges spanning each, bands included: every slab runs the polygon's whole
width, so a crossing in one corner cuts quads everywhere. Stroked, at `MEDIUM` on the CPU: ~160 µs
per 5-tip star, ~380 µs per pentagram, ~2 ms per 40-tip star. Filled only, a 5-tip star is ~30 µs.

A **rounded** polygon (`Polygon.corner_radius`) is flattened by its `shape_command` when recorded,
through `rounded_vertices`, each fillet as finely as a circle of that radius is drawn at the current
transform, so every replay, shadow and clip sees an ordinary polygon. Its fillets add vertices and
so slabs: stroked, ~360 µs per rounded 5-tip star, ~460 µs per rounded pentagram, ~20 ms per rounded
40-tip star. Drawing a simple polygon's stroke from its inset loop instead of bands would be far
cheaper, but the inset folds wherever a fillet is tighter than the stroke or a tip or neck is thin,
which a band never does; that needs a fold check and a band fallback.

An **ellipse** has no command of its own: its `shape_command` records a `PolygonPayload` through
`Ellipse._vertices`, as many as `circle_segments` gives its larger radius at the current transform,
rounded up to a multiple of four so a vertex lands on each end of both axes and `_fill_box` (the
vertices' bounds) is the ellipse's. Its stroke, alignment, shadows and clip are a polygon's, so it
is as thick all round, which a ring between two concentric ellipses is not. A flat one records the
zero-size `RectPayload` it is. Stroked, at `MEDIUM` on the CPU, 2000 small ellipses cost ~3x as much
as the same number of circles (~93 against ~33 ms), and 20 of radius 200 by 100 cost ~5x (~44
against ~9 ms). Filled only, they cost the same as circles. A dedicated kind with its inset ring
tiled like `triangle_pieces` would close that, at the cost of every replay, shadow and clip path
learning it.

A **capsule** is recorded the same way, through `Capsule._vertices`: each half circle in half the
`circle_segments` of `radius`. Its chords fall short of its bounds, so it records through
`framed_polygon_command`, which sets `gradient_box` as a rounded sector does and `_fill_box` spans
the capsule's true bounds. A zero `radius` records a polygon of no vertices, which draws nothing.
Stroked, 2000 small capsules cost ~2.3x as much as the same number of circles (~80 against ~34 ms);
filled only, the same as circles.

## Clips

`canvas.clip(shape, invert)` records no command. It draws the `Shape` into a `RegionCapture`, a
geometry target that keeps the region's `shape_command` in `clip_style()` instead of recording it,
so a clip and a fill of a shape are built by the same code. `ClipGuard` calls
`CommandBuffer.push_clip`, which appends a `_Clip` to `CommandBuffer.clips` and makes it current
(`CommandBuffer.clip`). The clip holds the region as an ordinary `RenderCommand` in `clip_style()`
(an opaque white fill and nothing else), its parent and `invert`.
`CommandBuffer.record`/`record_clear` stamp the current id on every command (`RenderCommand.clip`, 0
for none), so no command builder knows about clips. The guard restores the previous id; `clips`
resets with the command buffer. A clipped clear never replaces the clear before it.

Each replay rasterises the region **with the code that draws that shape**, so a clip and a fill of
the same shape cover the same pixels:
- **CPU:** before any command, `CpuReplay._clip_rows` replays each region through `_one` onto a
  *recording* surface (`Surface._recording_into`) `grid` times finer, as `_shape` antialiases a
  shape. There `fill_span` appends `(row, lo, hi, key)` and writes nothing; `key` names the run's
  paint, which a clip ignores. `_ClipRows` merges those per sub-row, then counts each pixel's
  covered samples into runs of constant `cover` (0–255, floored like `_mixed`, so a clip edge
  matches a fill of the same shape exactly), complements them for `invert` (`255 − cover`), and
  intersects with the parent's (covers multiply). A clipped command's surface carries its rows
  (`Surface._with_clip`). `fill_span`, `blend` and `fill_all` cut to them and scale a partly kept
  run's alpha by its cover (`_kept`), and nothing else writes pixels, so no rasteriser knows about
  clips. With antialiasing off the grid is 1 and every cover is 255.
  - The clipped paths are out of line (`_fill_span_clipped`, `_shade_span_clipped`,
    `_blend_clipped`). Keep them there: a recursive or larger `fill_span` stops inlining and cost
    circles ~40%.
  - `blit_image`/`blit_alpha` check for a clip once and pass `blend[clipped=False]`, because the
    per-pixel test alone cost an image blit ~15%.
  - The rows live in a local `List` that the surfaces point into untracked (`MutUntrackedOrigin`),
    built in full before the first command so it never reallocates under them.
- **GPU:** the stencil buffer. When `c.clip` differs from what the stencil holds,
  `GLRenderer._apply_clip` flushes, clears the stencil, and draws the chain outermost first through
  `_one` with colour writes off. Level `d` increments the pixels at `d − 1` that its region covers.
  An inverted level increments everything at `d − 1`, then decrements its region. Draws then test
  `EQUAL` to the depth. `glClear` ignores the stencil, so a clipped opaque clear is a quad. The
  window requests 8 stencil bits; `_GLTarget` and the multisampled target attach a depth-stencil
  renderbuffer. Under multisampling the stencil is per sample, so a GPU clip's edge is antialiased
  like a shape's, as the CPU's is by coverage. Disabling `GL_MULTISAMPLE` while writing the stencil
  would make it hard by the spec, but Mesa's llvmpipe then leaves part of each interior pixel's
  samples unmarked — don't retry it without checking on that driver.
- Cost: on the GPU, a clip change is a flush plus one draw per level of its chain. On the CPU, each
  clip is one rasterisation of its region per frame (per capture too), plus an index lookup per
  span.

`test_clip.mojo` asserts samples on both backends and compares frames only where the CPU frame is
flat (a pixel and its eight neighbours one colour), with an allowance for shapes' own edges: a
rotated edge differs between the two rasterisers, as it does for a plain rotated rectangle, and a
GPU clip's rim is multisampled.

## Antialiasing

**GPU:** `GLRenderer.render(..., samples)` draws into a `_FrameTarget` (colour and depth-stencil
renderbuffers, multisampled unless the count is below 2) and blits it into the framebuffer that was
bound, the window's or a headless `_GLTarget`, then rebinds that framebuffer. The target outlives
the frame, so with the autoclear off a frame starts from the last one's pixels: a window's back
buffer holds nothing defined after a swap, so the frame is never drawn straight into it. The target
is rebuilt, transparent, when the drawable size or the sample count changes. So on the GPU, changing
the antialiasing level loses the kept pixels, which the CPU keeps: a blit can't write into a
multisampled target. The count is capped at `GL_MAX_SAMPLES`. Windows open single-sampled, so the
level can change without recreating the GL context.

**CPU:** `Backend.antialiasing` (an `Antialiasing`, seeded by the run loops and set by
`canvas.antialiasing`) applies to the CPU replay of the shape kinds (rect, circle, line, Bézier,
sector, polygon, triangle), through `CpuReplay._shape`. Clear, text, images, letterbox and blurred
shadows are untouched; a hard shadow is a shape command, so it is antialiased like one. An inset
shadow is mixed into the shape's paint, so the grid antialiases it with the shape (see Shadows); a
silhouette rasterised from pieces is drawn on the grid by `pieces_mask`. The GPU's multisampling
doesn't reach a texture's contents, so `GLRenderer.render` builds its masks and layers on the CPU's
grid for the same level. An image that isn't upright has its edge antialiased on the same grid
inside `blit_image_mapped` (see Images).

- **Record at `grid`×.** `_shape` replays the command through the kind's own rasteriser
  (`_shape_pixels`) onto a recording surface `grid` times wider and taller, with
  `Transform(scale=grid)` in front of the device transform and `scale × grid` as the fallback pixel
  scale. So every rasteriser samples at sample centres instead of pixel centres, stroke thickness
  and curve flattening refine with it, and no rasteriser knows. Each run is `(row, lo, hi, key)`,
  the key `_color_key(color)` or `GRADIENT_KEY`, so fill and stroke stay apart.
- **Composite once** (`composite_coverage`): runs are bucketed by pixel row; each adds its coverage
  changes (partial samples at either end, `grid` between) to a difference array per paint and notes
  the columns it touches. The sorted touched columns split the row into stretches of constant
  coverage: full ones go to `fill_span` as one run, partial ones mix their paints premultiplied by
  sample share and blend once. So fill and stroke crossing one pixel leave no seam, and a
  translucent shape stays one layer deep. A gradient's partial stretch samples per pixel.
- **Clip regions** take the same grid, recorded by `_clip_rows` itself (see Clips); `_shape` passes
  a recording surface straight to `_shape_pixels`.
- Hot loops index through pointers into `CoverageScratch` buffers kept on the `Backend`: checked
  `List` access cost as much as the compositing did.

Cost (`pixi run benchmark raster`, 1920×1080): 2000 small alpha shapes ~4.8 ms off, ~11 ms `LOW`,
~16 ms `MEDIUM`, ~23 ms `HIGH`; 20 stroked circles of radius 200 ~3.2 / 6 / 8 / 11.5 ms. Small
shapes are nearly all edge, so they pay most. These are the CPU's costs: the GPU's multisampling
costs it little.

## Reads

`canvas.color_at` and `canvas.snapshot` go through `Backend.read(width, height, scale, to_target,
seeded)`, antialiased as the frame is. It replays the commands recorded so far onto a
`MemorySurface`, skipping the letterbox, with `pre = to_target @ screen_inv`. `to_target` maps
screen space to the read's pixels; `screen_inv` is the window-pixel-to-screen mapping that
`Canvas.__init__` hands over through `begin_frame`. Like `present`, it moves the command buffer out
and back. Pixels whose centre is off the screen are made transparent afterwards, since a clear fills
the whole target.
- `read_frame` caches the full-screen read at design size in `frame_read`: `frame_w` x `frame_h`,
  the screen extent (`screen_w`, a `Float64`) rounded to whole units and centred on the screen, so
  `color_at` and `last_frame` share its grid. It stays current while `recorded` (bumped by every
  `record` and `record_clear`) is unchanged, and resets at present. `color_at` and a full-screen
  scale-1 `snapshot` share it.
- `seeded` (autoclear off): the first such read sets `keep_frames`. From then on `present` samples
  each finished CPU frame down to design size into `last_frame` (`_keep_frame`), and later reads
  start from it (`_seed`), nearest pixel. `present_gpu` has no host pixels to sample, so it keeps
  the frame as a seeded `read_frame`: one CPU replay of the frame at design size a frame, paid only
  once a program has made such a read.

**Offscreen canvas.** `Canvas(width, height, …)` builds its own CPU `Backend` with `target`, a
`MemorySurface` of `width*scale` × `height*scale`, set; `_offscreen()` is whether it is. It never
presents: `color_at`, `snapshot`, `save_image` and `save_screenshot` call `bake(scale)`, which
replays the pending commands onto `target` (letterbox skipped), drops them and runs `expire_images`;
baking is its `present`. Reads then come from `target`: `_read_offscreen` copies it for the whole
canvas at its own density and otherwise resamples through `_seed`, which takes the source's
screen-to-pixel mapping (`_base` here, `_design_pixels` for `last_frame`). `bake` and `discard`
(`canvas.clear`) clear `clips` only when no clip is open: a command recorded inside an open
`canvas.clip` names its level by index, which must stay valid. `autoclear` stays off on an offscreen
canvas: `set_autoclear` would insert a grey clear, which the next bake would paint in.

**The image cache** (`Resources.images`, `_resources.mojo`, beside the `TextRenderer`: what every
replay reads besides the commands) holds one entry per image, keyed by a backend id; `interned_ids`
maps `Image._id` to it. An image never changes, so `intern_image(source, pixels, …)` reuses the
entry whenever the identity matches. The entry holds the image's own `ArcPointer[List[UInt8]]`, not
a copy: interning costs no pixel copy, and the share keeps the pixels alive for a command replayed
after the `Image` is gone. `expire_images`, after each present (or offscreen bake), drops entries
unused for `IMAGE_KEEP_FRAMES` frames and returns their ids, which `present_gpu` passes to
`GLRenderer.forget_images` to delete their textures.

## Captures

Captures are requests filed on `Backend.captures` (`Captures`, `_captures.mojo`) and serviced inside
`present`/`present_gpu`, the only place that holds both the finished framebuffer and the unconsumed
command buffer. A failed write raises from there.
- `canvas.save_image(path, scale, transparent)` — what the program drew: design size × `scale`, no
  letterbox, CPU-replayed from the commands under **both** backends (glyph cache and images live on
  `Backend`, not `GLRenderer`). Reproducible across machines.
- `canvas.save_screenshot(path)` — what the user saw: drawable resolution, bars included. On GPU
  this is a `glReadPixels` stall — fine on a keypress, not per frame.
- `canvas.start_recording(path, …)`: a `_Recording` on `Captures` that lasts across frames. Both
  presents service it through `Backend._record_frame`, as they service `_flush_image`, by the CPU
  replay. `Captures.frame_due` says whether this frame's slot is due, the backend replays the frame
  onto the recording's own pixels (`_Recording.canvas`), and `Captures.add_frame` encodes them.
  - **With the autoclear on**, a due frame is replayed onto those pixels cleared. **With it off**
    (`CommandBuffer.autoclear`), every frame is replayed onto them, due or not, so they hold what
    the screen holds. A change of the window's pixel size or of the GPU's sample count starts the
    screen over, and zeroes them too. The first frame with the autoclear off isn't replayed, since
    what earlier frames left has no commands to replay. It is sampled through `_seed` from the
    window's finished frame instead: a copy of the CPU surface, or one `GLRenderer.read_frame`,
    asked for only when `_needs_seed`.
  - **A `transparent` recording** replays with `skip_clear`, as a transparent `save_image` does. It
    is never seeded, since the window has the background in it. It writes each frame with a
    transparent index and `DISPOSE_BACKGROUND`, so each frame replaces the last.
  - **An opaque recording** keeps the last frame it added (`_Recording.previous`). It writes each
    later frame as the rectangle whose colours changed (`_changed_rect`), drawn over the last with
    `DISPOSE_KEEP`, with the unchanged pixels in it transparent (`_delta`). An unchanged frame
    writes nothing, so the delay of the frame waiting to be written runs on. A pixel that didn't
    change keeps the colour an earlier palette gave it.
  - The recording keeps the capture's own base matrix and composes it with each frame's
    `screen_inv`, so a resize mid-recording is undone like any frame's.
  - **Timing:** `first_step` and `step` set `Captures.clock` from `context.time.elapsed`, since
    render never sees `Context`. The clock is cut into `1/fps` slots from the first present, and a
    frame is captured in each slot it enters. A captured frame waits in `pending` until the next one
    says how many slots it covered, since a GIF frame's delay precedes its pixels. Delays are
    differences of rounded slot times (`_centiseconds`), so they never drift.
  - Every loop calls `finish_recording` after its last frame. `GifWriter` (`_gif.mojo`) streams the
    file to `path + ".partial"`, and at `finish` renames it into place through C's `rename`, since
    the standard library has none. `cancel_recording` deletes the partial file instead.

See [examples/capture/main.mojo](../../../examples/capture/main.mojo).

## Text

A `TextPayload` carries its string and its `TextStyle`, which carries the face (`style[].font`,
`None` for the packaged default): the `Font`'s `ArcPointer` keeps the face open until replay, so
nothing is interned. Faces live in `create.text`; `TextRenderer` lays out and caches.
- **One layout, two backends:** `layout` returns `PlacedGlyph`s (cache key and device position); the
  CPU blits each mask, the GPU packs it into the atlas. Neither re-derives a pen position.
- **Turned text:** under a transform that isn't `text_upright` (rotation, shear, mirror, a
  non-uniform scale), `layout` runs around the origin at `text_pixel_scale` (√|det|, so a zoomed,
  turned string is rasterised at the density it lands at) and each glyph's rect is mapped through
  `glyph_transform`. The CPU reads the mask bilinearly (`blit_alpha_mapped`, zero outside, so the
  edge needs no antialiasing of its own); the GPU draws the four mapped corners, grown half a texel
  into the atlas gutter to match the CPU's reach. Every glyph has a blank texel all round it, and
  the first shelf starts at `_FIRST_SHELF_Y` to keep the white texel's row out of reach. A text
  shadow's blur is quantised at `text_pixel_scale` too, on both backends.
- **Quarter-pixel placement:** `layout` rounds its anchor to the nearest `1 / _SUBPIXELS` of a pixel
  (`_subpixel_offset`, floored so negative positions step alike), lays out from the whole pixel, and
  rasterises every glyph moved by the fraction (`FT_Set_Transform`'s delta, set for the one load).
  So text moving less than a pixel a frame glides, and rows of text keep their spacing at a pixel
  scale that makes it fractional. An offset moves no advance, so it changes no line.
- **The glyph cache** (`_glyphs`) is keyed by one `Int`: codepoint 21 bits, size 12, weight 10, blur
  9, font slot 7, subpixel offset 4 (2 bits for x, 2 for y). Size, weight and blur are clamped into
  theirs (`_MAX_SIZE` 4095 px, `_MAX_WEIGHT`, `_MAX_BLUR` 511 px) where they enter. A slot is handed
  to each face on first sight (`_slot`, by `Font._id`); the renderer holds the face while its slot
  is live.
- **Italic is a face, not a key bit:** `_face(style)` swaps in `Font._italic()`, the same font
  drawing its italic `_Face` under an id of its own, so it takes a slot like any other font and the
  key has no italic field. The italic `_Face` is opened on first use and shared by every copy
  (`_FontFaces` in `create.text`).
- **Never stale by switching:** a key names its face, so switching fonts keeps every face's masks
  and the GL atlas. Only running out of `_FONT_SLOTS` (128) starts over: glyphs and slots are
  cleared and `atlas_generation` is bumped, which the atlas watches. `_GLYPH_CACHE_LIMIT` drops the
  masks (not the slots) whole when full. The GL atlas starts over too when a glyph no longer fits
  (`GLRenderer._pack`): it flushes the batch, which still reads the old glyphs, blanks every texel
  (`_reset_atlas`) and packs again from the top. A blurred text shadow fills it fastest, since each
  blur gives each glyph a mask of its own: a blur slider dragged across fills it in a few dozen
  frames.
- **Lines:** `_measure` caches a string's glyphs and breaks it into `_Line`s at each newline (a
  carriage return takes no glyph) and, given a wrap width in pixels, greedily before the last run of
  spaces that fits, or between glyphs in a word wider than the wrap. `layout` aligns each line on
  its own and steps the baseline by the face's line height; `Align`'s top and bottom are the whole
  block's, from the first line's ascent to the last line's descent, which `height` measures. `width`
  is the widest line.
- **Wrapping is decided at replay**, like the rest of the layout: `TextPayload.wrap` is in local
  units (`NO_WRAP` for none), and each replay converts it at the scale it lays the text out at
  (`wrap_pixels`, `text_pixel_scale`). `canvas.text_width`/`text_height` measure at that same scale,
  so a measured string breaks where the drawn one does.
- **Metrics:** the layout reads them through `Font._vertical_metrics(size)` (ascent, descent and
  line height), which scales the face to that size first. With every glyph cached, nothing else
  would have scaled it.
- The fallback face is consulted per glyph, by `has_glyph` on the style's face; its masks are keyed
  under the style's face's slot, since that face decided to fall back. Italic text falls back to the
  fallback's italic.

## Strokes

A rectangle's or triangle's rounding is its shape's `corner_radius`, carried on
`RectPayload.corner_radius`/`TrianglePayload.corner_radius` and clamped at replay; a shadow's spread
grows it.

**Every region draws its stroke as an inset ring** inside its edge, the fill inside that.
`stroke_alignment` is then one grow: `aligned_stroke` (`_stroke.mojo`) grows the command by `o =
fraction × t` (0, ½ or 1 of `local_stroke_thickness`, the stroke as rasterised, in local units)
before anything draws it (a rectangle's `w` and `h` by `2o`, a circle's `r` by `o`, a triangle
through `_grow_triangle`, and a sector's and polygon's `grow`), so the inset ring of the grown shape
lands inside, centred or outside. A rounded corner's radius grows by `o` too; a sharp one stays
sharp. It is applied once per backend, at its choke point (the CPU's `CpuReplay._one`, the GPU's
`GLRenderer._command`), so the shape, its hard, blurred and inset shadows, pixel reads and captures
all see the same geometry, and no rasteriser takes a new parameter. A clip's region has its stroke
off and is never grown. The grow is kept in `RenderCommand.stroke_grow`, and `_fill_box` takes it
back out, so a gradient spans the true shape under every alignment.

**Every kind composites once.** Fill and stroke never overlap, and neither do pieces of either, so a
translucent shape or a non-`NORMAL` blend mode is as translucent everywhere.
`test_translucency.mojo` draws every kind at opacity 0.5, and again white under a half-transparent
red tint, on both backends and fails on any pixel deeper than one layer. A new shape or path must
keep this:
- **Rectangles:** the fill is inset by the stroke. The CPU's axis-aligned paths split each row into
  stroke, fill, stroke: four bands when sharp, `_rounded_box_row` when rounded. Rotated and
  stretched rectangles take the general affine path, which samples pixel **centres**, as every path
  must (it once sampled corners and drew a 40-pixel rectangle 41 wide).
- **Triangles:** a rounded or stroked triangle is `triangle_pieces`, the same pieces on both
  backends.
  - **Sharp:** the ring is one quad per edge between the triangle's own edge and the inner edge,
    which is the triangle scaled about its incentre by `(inradius − t) / inradius`.
  - **Rounded:** one quad per arc segment between concentric arcs of radius `r` and `r − t`, and one
    per edge. Once `t ≥ r` the inner edge is sharp, and each corner is a fan from its inner vertex.
  - **Fill:** the inner edge as one convex polygon. The CPU fills it with `fill_convex`, which walks
    edges exactly as `fill_quad` does (slope precomputed from the lower end), so a shared edge gives
    bit-identical crossings. The GPU fans it.
  - A plain unstroked sharp triangle keeps its single-pass fill.
  - Built in local space, with `t` the device thickness divided by the pixel scale, and mapped per
    point, so a sheared rounded corner stays an ellipse arc.

## Shadows

Both replays handle a command's shadow around the command itself, in the command's blend mode:
- **Outer** (`casts_outer_shadow`), *before* the command. Blur is quantised to whole device pixels
  (`Int(shadow_blur * pixel_scale + 0.5)`) by both backends identically; 0 replays
  `shadow_command(c, scale)` through the normal dispatch. Otherwise shapes and lines evaluate
  `BlurredSilhouette` coverage analytically (CPU per pixel over the reach; GPU one quad in
  `MODE_SHADOW_BOX`/`MODE_SHADOW_EDGES`), and text and images blur a mask (`_blur.mojo`): glyph
  masks are keyed by blur in the glyph cache and packed into the atlas; image masks are cached per
  `shadow_mask_key` in `CpuReplay.shadow_masks` (CPU) and `GLRenderer.shadow_textures` (GPU), both
  dropped whole at `SHADOW_MASK_LIMIT`. That caching holds while the image is upright. Under a
  rotation, shear or mirror the mask depends on the whole transform, so `image_shadow_mask` builds
  it each frame, uncached like a Bézier's (below). A line's silhouette is its box, lengthened by
  half the thickness at each end for `SQUARE`, and a capsule (radius half the thickness) for
  `ROUND`, blurred by `capsule_coverage`: the core's box exactly, each cap a 16-node integral across
  it (`MODE_SHADOW_CAPSULE` on the GPU). A line doesn't use the rounded-box coverage, which is a
  single step across the outline that ignores the far edge. That step is fine for a shape that is
  wide compared with sigma, but a thin stroke's whole width is within a sigma or two of both edges,
  so its shadow came out several times too dark. Circles and rounded rectangles keep that step:
  their shadows are large, and the integral costs a dozen-odd `exp` a pixel. A Bézier's, sector's or
  polygon's pieces are rasterised into a mask and blurred too (`shape_shadow_mask`, through
  `pieces_shadow_mask`), but **uncached**: they have no stable id to key by, so each blurred Bézier,
  sector or polygon shadow costs one blur per frame, and on the GPU one texture upload plus one draw
  call; the textures are deleted after the frame's final flush.
- **Inset** (`casts_inset_shadow`), *with* the command: the shadow colour wherever the silhouette
  (the interior moved by the shadow transform, shrunk by the spread and blurred) leaves the interior
  uncovered. It is composited in the same pass as the command, never over the finished pixels: over
  an antialiased edge pixel, the interior's share would then show the command's own colour through
  the shadow. `_inset.mojo` describes the scheme.
  - **CPU, regions and curves:** `CpuReplay._with_inset_shadow` draws the command with the shadow
    mixed into the paint of its interior, a region's fill or a curve's stroke (`FillPaint.inset`),
    from `inset_uncovered`, a mask of how much of each pixel the silhouette leaves uncovered. A
    hidden fill is drawn transparent so its interior still takes the shadow. A rectangle's or
    circle's silhouette (`insets_analytically`) is its `InsetRegion` shrunk, evaluated at pixel
    centres; every other one is its interior's pieces (`interior_pieces`) under the shadow
    transform, rasterised and blurred.
  - **GPU, regions and curves:** a rectangle or a circle tessellates its interior with the fill
    emitters and sets each vertex's silhouette parameters from its device position
    (`MODE_INSET_BOX`); a hard one uses a steep sigma (1/64 px), not a step. Every other region or
    curve draws its interior pieces again over itself, sampling the same `inset_uncovered` mask as a
    texture (`emit_masked_pieces`), so multisampling covers each sample once. A triangle is masked
    rather than analytic: its silhouette's corners are rounded, and the GPU's analytic modes see a
    triangle only as its three edges, which would cut them sharp.
  - **Text and images, both backends:** `inset_layer` draws the command on its own onto transparent
    pixels, glyphs laid out as `CpuReplay._text` lays them out or the image blitted as
    `CpuReplay._image` blits it, and mixes the shadow into each pixel's interior share (the white
    silhouette's alpha). The CPU blits the layer and the GPU draws it as a texture, in place of the
    command. Neither has a spread, as for its drop shadow.
  - A line's or a curve's interior is its stroke, and its silhouette the stroke thinned by twice the
    spread. Every mask and layer is uncached, built once a frame, as a blurred Bézier's shadow is.

The offset is one transform (`shadow_transform`). A screen-fixed offset composes a device
translation after the command transform; one that follows the transform composes
`Transform(translation=offset)` before it.

Parity (`test_gl_parity.mojo`) needed no extra tolerance for blurred cases: both backends evaluate
the same coverage formulas at pixel centres.

## Images

An image follows the transform like every render call. An upright image (`upright`: an axis-aligned
scale on either axis, unmirrored) is a device rect, `upright_rect`, blitted row by row
(`blit_image`). Otherwise the CPU fills the mapped parallelogram's bounding box through the inverse
mapping (`blit_image_mapped`, the texel coordinate stepped per column) and the GPU draws one quad
through the four mapped corners, multisampled. On the CPU a pixel whose footprint (stepped like the
texel coordinate) lies inside the image is painted whole; one on the edge counts its `grid`×`grid`
sample centres inside, as a shape's edge does, and scales the centre's texel alpha by that share. A
blurred shadow's mask (`image_shadow_mask`) samples centres only, on both backends, so they blur the
same mask. The CPU samples texels nearest-neighbour where the image is drawn at its size or larger.
Drawn smaller along either device axis, each pixel averages the texels whose centres fall in its
footprint, weighting colour by alpha (`_footprints` upright, `_footprint` mapped, both through
`_averaged`), so a fine detail or a faded rim blends instead of being skipped; a turn alone keeps
one texel a pixel. The GPU samples linearly without mipmaps, so parity holds inside a solid image;
its rim and a minified image's fine detail may differ.

## CPU rasteriser

Compute each row's covered run analytically and hand `(start, count)` to `fill_span` once — never
test every pixel in a bounding box. `fill_span` owns the opaque-store and vectorised compositing.
`blend` is only for genuinely per-pixel alpha (glyph coverage, image texels).

The command's `BlendMode` rides on the `Surface` (`_with_blend_mode`, set once in `CpuReplay._one`),
as does its clip (see Clips), so no raster loop threads either; `blend` and `fill_span` read it and
share `_blend_lanes` for every mode but `NORMAL`. A new mode goes there and in
`GLRenderer._blend_mode`. It must be one fixed-function GL blend equation, which is why there is no
`DIFFERENCE`.

## GPU path (OpenGL 3.3)

`_tessellate.mojo` bakes each command's transform into its vertices (13 × `Float32`: `x, y, u, v, r,
g, b, a, mode, s0, s1, s2, s3`), so everything accumulates into one buffer and flushes as one
`glBufferData` + `glDrawArrays`. `s0..s3` are per-mode shape parameters, zero where unused; they
only ever hold quantities affine across a triangle, so interpolation evaluates them exactly.

| Mode | Value | Fragment |
|---|---|---|
| `MODE_SOLID` | 0 | Vertex colour, no sampling |
| `MODE_MASK` | 1 | Glyph: atlas red scales alpha |
| `MODE_TEXTURE` | 2 | Image: sampled RGBA × colour |
| `MODE_SILHOUETTE` | 3 | Image shadow: sampled alpha scales colour alpha |
| `MODE_SHADOW_BOX` | 4 | Blurred rect/rounded rect/circle/butt or square line shadow; `s3` a ring |
| `MODE_SHADOW_EDGES` | 5 | Blurred triangle shadow, three edge distances; `s3` a ring |
| `MODE_INSET_BOX` | 6 | 4 without ring, coverage inverted |
| `MODE_GRADIENT` | 8 | Gradient fill: `uv` the device mapping, `s0` radial, `s1` ramp row; samples unit 2, dithers |
| `MODE_SHADOW_CAPSULE` | 9 | Blurred round-capped line shadow: `s0` the core's half-length, `s1` the radius |

A batch breaks only on an opaque clear, a second distinct unit-1 texture, a `BlendMode` change, a
clip change (see Clips), or frame end. The glyph atlas is on texture unit 0, images on unit 1, and
gradient ramps on unit 2, which is never rebound, so gradients batch with anything; refilling the
ramp texture flushes once. A blurred image shadow's mask is its own unit-1 texture, so a shadowed
image costs one extra draw call, and interleaving several costs one per switch; a blurred Bézier,
sector or polygon shadow likewise costs one. Blurred text shadows live in the atlas and cost none.
Per frame, only the viewport is written, and only on resize.

Before optimising: `pixi run benchmark frame` measures ~6 ms/frame at 1920x1080 (vsync off); the
vertex list stops reallocating after frame 1; orphan-then-`glBufferSubData` measured identical to
the current single `glBufferData`. `pixi run benchmark raster` measures CPU rasterisation headless.

**`render` reaches GL without `_window`:** `_gl.mojo` `dlopen`s SDL itself and resolves through
`SDL_GL_GetProcAddress`. A GL context must be current before `GL()` is constructed.

**FFI rules for `_gl.mojo`** (calls go through bitcast `thin abi("C")` pointers; this works):
1. A `String` whose pointer goes to C must outlive the call — put `_ = s` after it. Check every
   resolved address against 0.
2. Read C out-parameters from heap memory (`List`), not a local `InlineArray` — the optimizer may
   serve the local stale.
3. Keep the GL context owner alive past the last GL call (`_ = win^` in tests and spikes).
