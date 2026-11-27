from std.collections import Optional
from std.math import ceil, floor

from create.color.color import Color
from create.render.gradient import Gradient
from .align import Align
from .stroke_align import StrokeAlign
from .stroke_cap import StrokeCap
from .stroke_dash import StrokeDash
from create.color.blend_mode import BlendMode
from .antialiasing import Antialiasing
from .autoscale import Autoscale
from create.text.font import Font
from create.text.font_weight import FontWeight
from ._surface import MemorySurface
from ._viewport import Viewport
from .camera import Camera
from create.geometry.bezier import Bezier
from create.geometry.spline import Spline
from create.geometry import Geometry, Shape
from ._geometry_target import _GeometryTarget, draw_geometry
from .drawable import Drawable
from .text import Text
from create.geometry import (
    Arc,
    Capsule,
    Circle,
    Ellipse,
    Line,
    Rectangle,
    Polygon,
    Sector,
    Triangle,
)
from create.math.point import Point
from create.math.vector import Vector
from create.math.transform import Transform
from create.image.image import Image
from create.animation.animator import Animator
from ._backend import Backend, _seed
from ._backend_handle import BackendHandle
from create._native import IN_LIBRARY, Slot, address, at, check, entry
from ._captures import _ImageRequest, _Recording
from ._gif import GifWriter
from ._command import (
    clear_command,
    letterbox_command,
    image_command,
    text_command,
)
from .style import Style, _ResolvedStyle
from create.math import OptionalNumber
from create._path import _caller_relative
from ._command import RenderCommand
from ._shape_command import RegionCapture, curves_command, shape_command
from ._text import NO_WRAP
from ._transform import pixel_scale, text_pixel_scale


comptime _AUTOCLEAR_COLOR = Color(200)

# The library's entry points a canvas calls, by type; each takes the canvas's
# address first and an error `String`'s last, and returns whether it worked.
# See `create/_native.mojo`.
comptime _CanvasCall = def(Int, Int) thin abi("C") -> Bool
comptime _CanvasPath = def(Int, Int, Int) thin abi("C") -> Bool
comptime _ColorAt = def(Int, Int, Int, Int) thin abi("C") -> Bool
comptime _Snapshot = def(Int, Int, Float64, Int, Int) thin abi("C") -> Bool
comptime _SaveImage = def(Int, Int, Float64, Bool, Int) thin abi("C") -> Bool
comptime _Measure = def(Int, Int, Float64, Bool, Int, Int) thin abi("C") -> Bool
comptime _InternImage = def(Int, Int) thin abi("C") -> Int


def intern_image(mut backend: Backend, image: Image) -> Int:
    """Intern `image` into `backend`, for a command to name by id."""
    return backend.resources.intern_image(
        image._id, image._pixels, image.width(), image.height()
    )


@fieldwise_init
struct _RecordingRequest(Movable):
    """`start_recording`'s arguments, passed to the library in one."""

    var path: String
    var seconds: OptionalNumber
    var frames: Optional[Int]
    var fps: Float64
    var scale: Float64
    var dither: Bool
    var transparent: Bool


struct _PersistentCanvasState(Movable):
    """The part of a `Canvas` that outlives the frame it was rendered in.

    A `Canvas` is built fresh each frame, so anything it must remember between
    frames — the backend, and through it the glyph cache and the interned
    images — is moved out at the end of one frame and into
    the next. The transform stack and the style are deliberately absent: both
    start fresh every frame by construction, so a missing pop or a forgotten
    `stroke_enabled(False)` cannot leak into the next frame.

    It also holds the frame-wide settings a program sets once and keeps —
    the autoclear, the letterbox colour and the antialiasing — so they can be
    set in `create` and last until changed. What decides the frame's geometry (the design size
    and the autoscale mode) stays on `Context`, which the loop reads to
    derive `_view` before a `Canvas` exists.

    It also owns what the run loop needs *before* a `Canvas` exists: event
    processing maps pointer positions through `_view`, and the dimension wait
    reads `_view.width`/`height` before the first frame exists at all.
    """

    var _backend: BackendHandle
    var _view: Viewport
    """The authoritative design-to-pixel mapping, re-derived by the loop every
    frame from `Context`. A `Canvas` copies it; `Canvas._release` deliberately
    does not write it back, which would undo the loop's own resize handling."""
    var letterbox_color: Color
    """The colour of the bars outside the design area under `Autoscale.FIT`,
    set through `canvas.letterbox_color`."""
    var autoclear: Bool
    """Whether each frame opens with a clear, set through
    `canvas.autoclear`."""

    def __init__(out self) raises:
        self._backend = BackendHandle()
        self._view = Viewport()
        self.letterbox_color = Color.BLACK
        self.autoclear = True

    def _set_viewport(
        mut self,
        autoscale: Autoscale,
        design_w: Float64,
        design_h: Float64,
        pixel_w: Int,
        pixel_h: Int,
    ):
        """Remap onto a framebuffer of this size.

        The design size and the autoscale mode are pushed in from `Context`
        rather than stored here, so there is one authority for both and a
        dial the last frame turned is picked up at exactly one place — the
        top of the next frame. Plain values rather than the `Context`, which
        lives in `app` above this package.
        """
        self._view.autoscale = autoscale
        self._view.set_design(design_w, design_h)
        self._view.set_size(pixel_w, pixel_h)


struct _TransformGuard[origin: Origin[mut=True]](Movable):
    """Pops the matrix `canvas.transform` pushed, on scope exit.

    Only `canvas.transform` builds one: its constructor's `_`-keywords are
    the library's own."""

    var _canvas: Pointer[Canvas, Self.origin]

    def __init__(out self, *, ref[Self.origin] _canvas: Canvas):
        self._canvas = Pointer(to=_canvas)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        self._canvas[]._pop_transform()


struct _OverlayGuard[origin: Origin[mut=True]](Movable):
    """Restores the camera and transform `canvas.overlay` suspended, on scope
    exit. Only `canvas.overlay` builds one."""

    var _canvas: Pointer[Canvas, Self.origin]
    var _saved_camera: Camera
    var _saved_user: Transform
    var _saved_user_inv: Transform
    var _saved_transform: Transform
    var _saved_transform_inv: Transform

    def __init__(out self, *, ref[Self.origin] _canvas: Canvas):
        self._saved_camera = _canvas._camera
        self._saved_user = _canvas._user
        self._saved_user_inv = _canvas._user_inv
        self._saved_transform = _canvas._transform
        self._saved_transform_inv = _canvas._transform_inv
        _canvas._camera = Camera()
        _canvas._user = Transform()
        _canvas._user_inv = Transform()
        _canvas._transform = _canvas._base.copy()
        _canvas._transform_inv = _canvas._base_inv.copy()
        self._canvas = Pointer(to=_canvas)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        self._canvas[]._camera = self._saved_camera
        self._canvas[]._user = self._saved_user
        self._canvas[]._user_inv = self._saved_user_inv
        self._canvas[]._transform = self._saved_transform
        self._canvas[]._transform_inv = self._saved_transform_inv


struct _StyleGuard[origin: Origin[mut=True]](Movable):
    """Restores the style the frame had when the scope was entered.

    `Style` is a plain value, so the guard carries its own snapshot and no
    stack is needed — nesting works because each guard restores what it saw.
    Only `canvas.style` builds one.
    """

    var _canvas: Pointer[Canvas, Self.origin]
    var _saved: _ResolvedStyle

    def __init__(out self, *, ref[Self.origin] _canvas: Canvas):
        self._saved = _canvas._style
        self._canvas = Pointer(to=_canvas)

    def __init__(
        out self, *, ref[Self.origin] _canvas: Canvas, _style: _ResolvedStyle
    ):
        """Snapshot, then replace the canvas's style with `_style`."""
        self._saved = _canvas._style
        _canvas._style = _style
        self._canvas = Pointer(to=_canvas)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        self._canvas[]._style = self._saved


struct _ClipGuard[origin: Origin[mut=True]](Movable):
    """Closes the clip `canvas.clip` opened, on scope exit. Only `canvas.clip`
    builds one.

    Holds the clip that was current before it rather than popping a stack, so
    nesting works the way `_StyleGuard`'s does.
    """

    var _canvas: Pointer[Canvas, Self.origin]
    var _saved: Int

    def __init__(
        out self,
        *,
        ref[Self.origin] _canvas: Canvas,
        var _region: RenderCommand,
        _invert: Bool,
    ):
        self._saved = _canvas._state._backend[].buffer.push_clip(
            _region^, _invert
        )
        self._canvas = Pointer(to=_canvas)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        self._canvas[]._state._backend[].buffer.clip = self._saved


struct Canvas(Movable, _GeometryTarget):
    """One frame: the geometry and the rendering API.

    This is the object a program is handed to render a frame with. `width`/`height`
    are the screen extent and `left`/`right`/`bottom`/`top` its edges — use
    those rather than width arithmetic, since the origin is centred and two of
    them are negative. `scale` is the autoscale factor. Screen space is camera-independent: these don't know a
    `Camera` exists, since a program sets one on the canvas's transform, not on
    the geometry it reports.

    A `mut` parameter because the program renders on it, and the recording it
    appends to is the frame's whole output. What it does *not* carry is a
    setting, the clock or input: everything that outlives a frame is in
    `Context`, handed to `update` beside it. A `Canvas` that carried a dial would be offering to
    change something it is not around to see the effect of.

    The canvas the loop hands to `create` and `update` is built fresh each
    frame and dropped before the frame is presented, so don't keep it in a
    field.

    `Canvas(width, height)` builds an *offscreen* canvas instead: a program's
    own, drawn into with the same calls and read back with `color_at` and
    `snapshot`, which may be kept as a field across frames. It starts
    transparent, and has no frames to present: each read replays what has
    been drawn since the last one onto its own pixels, so drawing after a
    read lands on what is already there.

    **It takes no parameters, and holds no `Surface`.** It used to need one
    origin parameter for the framebuffer it borrowed, which constrained the
    whole API: a second parameter would have broken every
    `Program.update` signature at once, and pointing an existing `Canvas` at a
    new framebuffer could not compile at all. Both
    limits are gone because a `Canvas` no longer touches pixels — it records,
    and the backend replays onto a `Surface` the canvas never sees. Don't
    reintroduce a `Surface` field or a parameter to hold one.

    Its extent comes from the `Viewport` rather than from a framebuffer. The
    two can disagree for one frame after a resize, which is harmless here: the
    extent is only used for coordinate arithmetic, and the replay clips against
    the real surface it is handed.

    A render call touches no pixels: it appends a `RenderCommand` to the backend's
    recording, and the backend replays the whole frame afterwards. So a
    `Canvas` is a recorder, and the geometry it records is *local* — the shape
    as the program asked for it, paired with the current transform — never
    device pixels. A style is resolved at record time, so a later `fill()`
    cannot reach back and change what an earlier command paints.

    Every pixel write blends source-over, so a fill, stroke, image, glyph or
    `background` with `a < 255` composites with what is already there —
    unless `blend_mode` picks another way to combine them.
    """

    var _width: Float64
    var _height: Float64
    var _scale: Float64
    var _view: Viewport
    var _state: _PersistentCanvasState
    # Style is per-frame, not carried in `_state`: carrying one across would
    # only preserve a forgotten setting. A reusable style is a `Style` field.
    var _style: _ResolvedStyle
    var _base: Transform
    var _base_inv: Transform
    # Camera is per-frame too, and for the same reason as style: it resets to
    # identity every frame, so `render` sets one explicitly each time it wants
    # one rather than it leaking from the last frame that set it.
    var _camera: Camera
    # `_user` is the composition of the matrices the program pushed, mapping
    # local coordinates to world. `_base` maps screen to pixels, `_camera`
    # world to screen. Rendering uses the full product; `to_local`/`to_screen`
    # stop at screen space, the space of `context.mouse.position` and `color_at`, so a
    # program never sees the window's pixel mapping it did not ask for.
    var _user: Transform
    var _user_inv: Transform
    var _transform: Transform
    var _transform_inv: Transform
    var _transform_stack: List[Transform]

    def __init__(out self, *, var _state: _PersistentCanvasState):
        """Adopt the carried-over state and this frame's mapping, and open
        the frame with a clear unless `autoclear` is off."""
        var state = _state^
        self._view = state._view
        self._width = state._view.width
        self._height = state._view.height
        self._scale = state._view.scale
        self._state = state^
        self._style = _ResolvedStyle()
        self._base = self._view.base_matrix()
        self._base_inv = self._base.inverse()
        self._camera = Camera()
        # The stack starts empty, so the base mapping is the current transform;
        # user transforms compose on top of it.
        self._user = Transform()
        self._user_inv = Transform()
        self._transform = self._base
        self._transform_inv = self._base_inv
        self._transform_stack = List[Transform]()
        self._state._backend[].begin_frame(
            self._base, self._width, self._height
        )
        # Recorded here rather than by the loop so both loops get it from one
        # place, and so a program's own `background()` can coalesce with it.
        if self._state.autoclear:
            self._state._backend[].buffer.open_with_clear(
                clear_command(_AUTOCLEAR_COLOR)
            )

    def __init__(
        out self,
        width: Float64,
        height: Float64,
        *,
        pixel_scale: Float64 = 1.0,
        antialiasing: Antialiasing = Antialiasing.MEDIUM,
    ) raises:
        """An offscreen canvas of `width` by `height` screen units, with
        `pixel_scale` pixels to the unit — `pixel_scale=canvas.pixel_scale()` matches the
        window's density.

        Screen space as on the frame canvas: origin centred, y up. Always
        rasterised on the CPU, whatever backend the program runs on; what
        comes out of it is an `Image`, which any canvas can draw.
        """
        if width <= 0.0 or height <= 0.0:
            raise Error(
                "an offscreen canvas needs a size of at least one unit, got "
                + String(width)
                + " x "
                + String(height)
            )
        if pixel_scale <= 0.0:
            raise Error(
                "an offscreen canvas needs a positive pixel_scale, got "
                + String(pixel_scale)
            )
        var pixel_w = Int(width * pixel_scale + 0.5)
        var pixel_h = Int(height * pixel_scale + 0.5)
        var state = _PersistentCanvasState()
        state.autoclear = False
        state._backend[].antialiasing = antialiasing
        state._set_viewport(Autoscale.FIT, width, height, pixel_w, pixel_h)
        state._backend[].target = MemorySurface(pixel_w, pixel_h)
        self = Canvas(_state=state^)

    def __init__(
        out self,
        width: Int,
        height: Int,
        *,
        pixel_scale: Float64 = 1.0,
        antialiasing: Antialiasing = Antialiasing.MEDIUM,
    ) raises:
        self = Canvas(
            Float64(width),
            Float64(height),
            pixel_scale=pixel_scale,
            antialiasing=antialiasing,
        )

    def _offscreen(self) -> Bool:
        """Whether this is a program's own canvas rather than a frame's."""
        return Bool(self._state._backend[].target)

    def _release(deinit self) -> _PersistentCanvasState:
        """Hand back the state the next frame's `Canvas` should start from.

        Consumes the canvas, so the recording is complete before the loop
        presents it — nothing can append to a frame that is being replayed.

        Nothing is written back. `self._view` is this frame's copy of a mapping
        the loop re-derives every frame, and the settings a program sets on
        the canvas that outlive the frame are written to `_state` directly —
        so there is no merge to get wrong here.
        """
        return self._state^

    def width(self) -> Float64:
        """The width in screen units, `right() - left()`: the design width
        under `Autoscale.FIT`, more under `EXTEND` as the window grows — by
        a fraction of a unit too, as the window's pixels divide out — the
        window's pixels under `OFF`. Rebuilt every frame."""
        return self._width

    def height(self) -> Float64:
        """The height in screen units, `top() - bottom()`; see `width`."""
        return self._height

    def bounds(self) -> Rectangle:
        """The screen as a rectangle in screen space, `left()` to `right()`
        and `bottom()` to `top()`: centred on the origin, `width()` by
        `height()`. What `snapshot` and `clip` take, and what `contains`
        asks whether something is on the screen."""
        return Rectangle(Point(0.0, 0.0), self._width, self._height)

    def bounds(self, text: Text) raises -> Rectangle:
        """The rectangle `text` covers when drawn in the current style: as
        wide as its widest line and as tall as `text_height` measures it,
        placed where `text_alignment` anchors it on `text.position`.

        ```mojo
        # In `update`, with a `caption: Text` field: a plate behind it.
        var plate = canvas.bounds(self.caption).inset(-8)
        with canvas.style(fill=Color.BLACK, text_color=Color.WHITE):
            canvas.draw(plate)
            canvas.draw(self.caption)
        ```

        It is in the space the text is drawn in, as a shape's `bounds` is,
        and measured at the current transform's scale, so it matches what
        `canvas.draw(text)` draws there.
        """
        var wrap = text._wrap()
        var width = self._measure_width(text.value, wrap)
        var height = self._measure_height(text.value, wrap)
        var align = self._style.text_alignment
        var center = text.position
        if align._left():
            center.x += width / 2
        elif align._right():
            center.x -= width / 2
        if align._top():
            center.y -= height / 2
        elif align._bottom():
            center.y += height / 2
        return Rectangle(center, width, height)

    def bounds(mut self, text: Text, *, style: Style) raises -> Rectangle:
        """The rectangle `text` covers when drawn in `style`, applied over the
        current style as `canvas.draw(text, style=style)` applies it."""
        var saved = self._style
        self._style.apply(style)
        try:
            var covered = self.bounds(text)
            self._style = saved
            return covered
        except error:
            self._style = saved
            raise error^

    def pixel_scale(self) -> Float64:
        """Window pixels per screen unit: what font size, stroke thickness
        and image size are scaled by."""
        return self._scale

    def left(self) -> Float64:
        """Screen x of the left edge — negative, since the origin is centred."""
        return self._view.left()

    def right(self) -> Float64:
        return self._view.right()

    def bottom(self) -> Float64:
        """Screen y of the bottom edge — negative, since y grows upward."""
        return self._view.bottom()

    def top(self) -> Float64:
        return self._view.top()

    def _render_letterbox(mut self):
        """Record the window area outside the design bounds.

        Runs after render, so it doubles as the clip for anything rendered past
        the edges of the design area. Nothing to do under `Autoscale.EXTEND`:
        the design covers the whole frame, so there is neither a bar to paint
        nor an out-of-bounds region to clip — and rounding the extended size
        could otherwise leave a one-pixel seam along an edge.

        The one command whose geometry is already in device pixels: it is the
        frame's clip rather than something the program drew, so no transform
        applies to it.
        """
        if not self._view.scaled() or self._view.autoscale == Autoscale.EXTEND:
            return
        var cx0 = Float64(Int(self._view.offset_x))
        var cy0 = Float64(Int(self._view.offset_y))
        var cx1 = Float64(
            Int(self._view.offset_x + self._width * self._scale + 0.5)
        )
        var cy1 = Float64(
            Int(self._view.offset_y + self._height * self._scale + 0.5)
        )
        self._state._backend[].buffer.record(
            letterbox_command(self._state.letterbox_color, cx0, cy0, cx1, cy1)
        )

    # `_uniform`, `_pixel_scale`, `_device_bounds` and `_stroke_thickness_px`
    # used to live here. They are properties of a matrix, not of a frame, and only
    # the replay needs them now — see `_transform.mojo`.

    def translate(mut self, delta: Vector):
        """Move everything drawn after this, until the end of the frame, by
        `delta`, as Processing's `translate` does.

        It applies inside whatever transform is already current, so a
        `rotate` after it turns about the point it moved to. Wrap the
        drawing in `with canvas.transform():` to undo it when the block
        ends.

        ```mojo
        with canvas.transform():
            canvas.translate(Vector(100, 0))
            canvas.rotate(PI / 4)
            canvas.rectangle((0, 0), 40, 40)  # turned about (100, 0)
        ```
        """
        self._apply_transform(Transform(translation=Vector(delta.x, delta.y)))

    def rotate(mut self, angle: Float64):
        """Turn everything drawn after this, until the end of the frame,
        counter-clockwise by `angle` radians about the current origin, as
        Processing's `rotate` does. See `translate`."""
        self._apply_transform(Transform(rotation=angle))

    def scale(mut self, s: Float64):
        """Make everything drawn after this, until the end of the frame, `s`
        times as big about the current origin, as Processing's `scale` does.
        See `translate`."""
        self._apply_transform(Transform(scale_x=s, scale_y=s))

    def scale(mut self, sx: Float64, sy: Float64):
        """Stretch everything drawn after this, until the end of the frame,
        by `sx` across and `sy` up and down about the current origin. A
        negative value mirrors. See `translate`."""
        self._apply_transform(Transform(scale_x=sx, scale_y=sy))

    def transform(mut self) -> _TransformGuard[origin_of(self)]:
        """Keep the current transform for a `with` block, and restore it when
        the block ends, as Processing's `pushMatrix` and `popMatrix` do.

        `translate`, `rotate` and `scale` inside the block are undone at its
        end, so a helper that draws with them doesn't change what its
        caller draws next.

        ```mojo
        with canvas.transform():
            canvas.translate(Vector(self.position))
            canvas.rotate(self.angle)
            canvas.rectangle((0, 0), 40, 40)
        ```
        """
        self._push_transform(Transform())
        return _TransformGuard[origin_of(self)](_canvas=self)

    def transform(mut self, t: Transform) -> _TransformGuard[origin_of(self)]:
        """Apply `t` to everything drawn inside a `with` block, on top of the
        current transform, and restore the current transform when the block
        ends.

        ```mojo
        with canvas.transform(Transform(translation=Vector(50, 50))):
            canvas.rectangle((0, 0), 100, 100)
        ```

        The block restores the transform on exit, including on an early
        return or a raise.
        """
        self._push_transform(t)
        return _TransformGuard[origin_of(self)](_canvas=self)

    def style(
        mut self,
        *,
        fill: Optional[Color] = None,
        fill_gradient: Optional[Gradient] = None,
        fill_enabled: Optional[Bool] = None,
        stroke: Optional[Color] = None,
        stroke_thickness: OptionalNumber = None,
        stroke_enabled: Optional[Bool] = None,
        stroke_alignment: Optional[StrokeAlign] = None,
        stroke_cap: Optional[StrokeCap] = None,
        stroke_dash: Optional[StrokeDash] = None,
        corner_radius: OptionalNumber = None,
        text_color: Optional[Color] = None,
        font: Optional[Font] = None,
        font_size: OptionalNumber = None,
        font_weight: Optional[FontWeight] = None,
        font_italic: Optional[Bool] = None,
        text_alignment: Optional[Align] = None,
        tint: Optional[Color] = None,
        opacity: OptionalNumber = None,
        blend_mode: Optional[BlendMode] = None,
        shadow: Optional[Color] = None,
        shadow_offset: Optional[Vector] = None,
        shadow_blur: OptionalNumber = None,
        shadow_spread: OptionalNumber = None,
        shadow_inset: Optional[Bool] = None,
        shadow_follows_transform: Optional[Bool] = None,
        shadow_enabled: Optional[Bool] = None,
    ) -> _StyleGuard[origin_of(self)]:
        """Scope style changes to a `with` block, restoring the previous style
        on exit.

        Each keyword applied goes through the setter of the same name, so it
        behaves exactly like calling that setter; the rest of the style is kept.
        `fill_gradient` goes through `fill`'s `Gradient` overload; given
        beside `fill`, the gradient paints. With no keywords it only scopes: for helpers that set style before
        rendering, where without it a callee's `stroke_enabled(False)`
        silently applies to whatever the caller renders next.

        ```mojo
        with canvas.style(fill=Color.RED, stroke_enabled=False):
            canvas.circle(position, 10)
        ```
        """
        var guard = _StyleGuard[origin_of(self)](_canvas=self)
        if fill:
            self.fill(fill.value())
        # After the colour, which clears a gradient: given both, the gradient
        # paints and the colour is kept.
        if fill_gradient:
            self.fill(fill_gradient.value())
        if stroke or stroke_thickness:
            self.stroke(stroke, stroke_thickness)
        # After the colors, which switch fill and stroke on: an explicit
        # `*_enabled=False` beside a color wins.
        if fill_enabled:
            self.fill_enabled(fill_enabled.value())
        if stroke_enabled:
            self.stroke_enabled(stroke_enabled.value())
        if stroke_alignment:
            self.stroke_alignment(stroke_alignment.value())
        if stroke_cap:
            self.stroke_cap(stroke_cap.value())
        if stroke_dash:
            self.stroke_dash(stroke_dash.value())
        if corner_radius:
            self.corner_radius(corner_radius.value())
        if text_color:
            self.text_color(text_color.value())
        if font:
            self.font(font.value())
        if font_size:
            self.font_size(font_size.value())
        if font_weight:
            self.font_weight(font_weight.value())
        if font_italic:
            self.font_italic(font_italic.value())
        if text_alignment:
            self.text_alignment(text_alignment.value())
        if tint:
            self.tint(tint.value())
        if opacity:
            self.opacity(opacity.value())
        if blend_mode:
            self.blend_mode(blend_mode.value())
        if (
            shadow
            or shadow_offset
            or shadow_blur
            or shadow_spread
            or shadow_inset
        ):
            self.shadow(
                shadow, shadow_offset, shadow_blur, shadow_spread, shadow_inset
            )
        if shadow_follows_transform:
            self.shadow_follows_transform(shadow_follows_transform.value())
        # After the shadow parts, which switch it on: an explicit
        # `shadow_enabled=False` beside them wins.
        if shadow_enabled:
            self.shadow_enabled(shadow_enabled.value())
        return guard^

    def style(mut self, style: Style) -> _StyleGuard[origin_of(self)]:
        """Apply the parts `style` sets for a `with` block, then restore the
        whole style as it was.

        Each part goes through the setter of the same name, so it behaves as
        calling that setter would, and a part `style` leaves unset keeps its
        current value. Applied as soon as this is called, like
        `transform(m)`, so outside a `with` it holds for the rest of the
        frame.

        ```mojo
        with canvas.style(self.label_style):
            canvas.text("Score", (0, canvas.top() - 20))
        ```
        """
        var guard = _StyleGuard[origin_of(self)](_canvas=self)
        self._style.apply(style)
        return guard^

    def _with_style(
        mut self, style: _ResolvedStyle
    ) -> _StyleGuard[origin_of(self)]:
        """`style(s)` for a style already resolved: how the library applies
        the looks it built itself, such as a widget's."""
        return _StyleGuard[origin_of(self)](_canvas=self, _style=style)

    def _push_transform(mut self, m: Transform):
        # Parent first, then child: a point is mapped by the innermost matrix
        # before the ones it nests inside. Composing the other way round would
        # apply the outer transform last, so a nested translate would move in
        # the frame of its own children rather than its parent's.
        self._transform_stack.append(self._user)
        self._user = self._user @ m
        self._sync_transform()

    def _apply_transform(mut self, m: Transform):
        # Like `_push_transform`, composed inside the current transform, but
        # without a push: it lasts until a guard pops past it or the frame
        # ends.
        self._user = self._user @ m
        self._sync_transform()

    def _pop_transform(mut self):
        if len(self._transform_stack) > 0:
            self._user = self._transform_stack.pop()
            self._sync_transform()

    def _sync_transform(mut self):
        self._user_inv = self._user.inverse()
        var cam_m = self._camera.transform()
        self._transform = self._base @ cam_m @ self._user
        self._transform_inv = self._user_inv @ cam_m.inverse() @ self._base_inv

    def to_screen(self, local: Point) -> Point:
        """A point in the current transform's frame, in screen space: through
        the transform, then the camera (none inside `overlay`). Where
        something drawn at `local` lands on screen.

        For its position in world space, ask the camera:
        `camera.to_world(canvas.to_screen(local))`.
        """
        return (self._camera.transform() @ self._user).apply(local)

    def clip[
        S: Shape
    ](mut self, shape: S, invert: Bool = False) -> _ClipGuard[origin_of(self)]:
        """Render only inside `shape` for a `with` block — or, with
        `invert`, only outside it. `shape` is any `Shape`: a `Rectangle`,
        `Circle`, `Triangle`, `Sector` or `Polygon`, rounded by its own
        `corner_radius`; a polygon's inside is by the nonzero rule.

        ```mojo
        with canvas.clip(Rectangle((0, 0), 200, 120)):
            canvas.image(self.photo, (0, 0))
        ```

        `shape` is placed by the transform and camera current here, and
        stays there for the block: a `transform` or `overlay` inside it moves
        what is rendered, not the clip. A clip inside another keeps only what
        both keep. Every render call is clipped, its shadow and `background()`
        included; the letterbox is not. The clip's edge is the edge
        `canvas.draw(shape)` would have.

        Closes on exit, including on an early return or a raise.
        """
        var capture = RegionCapture(self._transform, self._scale)
        draw_geometry(shape, capture)
        return _ClipGuard[origin_of(self)](
            _canvas=self, _region=capture.command.take(), _invert=invert
        )

    def to_local(self, screen: Point) -> Point:
        """A screen-space point — `context.mouse.position`, say — in the current
        transform's frame: back through the camera (none inside `overlay`),
        then the transform. So `canvas.to_local(context.mouse.position)` picks
        in the frame a shape is drawn in, with or without a camera.
        """
        return self._user_inv.apply(self._camera.to_world(screen))

    def camera(mut self, camera: Camera):
        """Set the active camera. Applies to every render call and every nested
        `transform()` from here on, until changed again or `canvas.overlay()`
        suspends it — and resets to identity next frame, like the rest of the
        transform state.

        ```mojo
        canvas.camera(self.camera)
        canvas.image(self.player.position, ...)  # world-space coordinates
        with canvas.overlay():
            canvas.text("Score: " + str(self.score), (0, canvas.top() - 20))
        ```
        """
        self._camera = camera
        self._sync_transform()

    def overlay(mut self) -> _OverlayGuard[origin_of(self)]:
        """Suspend the camera and any active transform for a `with` block, so
        what's rendered inside lands in screen space regardless of where the
        camera looks — for a HUD or other UI that must stay put.

        Pops back to whatever camera and transform were active on exit,
        including on an early return or a raise.
        """
        return _OverlayGuard[origin_of(self)](_canvas=self)

    def fill(mut self, color: Optional[Color] = None):
        """Paint the inside of shapes, switching the fill on. A `color`
        replaces any gradient; left unset, the current fill is kept, colour
        or gradient, so `fill()` alone brings back the last fill. The fill is *off* by default, in white, so `fill()` on a fresh
        frame paints shapes white.

        Holds until changed or until the frame ends — every frame starts from
        the `Style` defaults, so nothing set here leaks into the next one.
        """
        if color:
            self._style.fill_color = color.value()
            self._style.fill_gradient = None
        self._style.fill_enabled = True

    def fill(mut self, gradient: Gradient):
        """Paint the inside of shapes with `gradient`, switching the fill on.
        It spans each shape's own bounding box, so it moves and turns with
        the shape; see `Gradient`. Only fills take one: strokes, text and
        shadows keep their colours.

        Holds until a `fill(color)` replaces it or the frame ends. The fill
        color is kept meanwhile, so `fill(color)` alone brings a solid back.
        """
        self._style.fill_gradient = gradient
        self._style.fill_enabled = True

    def stroke(
        mut self,
        color: Optional[Color] = None,
        thickness: OptionalNumber = None,
    ):
        """Stroke shapes, switching the stroke on if `stroke_enabled(False)`
        had turned it off. `color`/`thickness` left unset keep their current
        values. Worth knowing stroke is *on* by default, in black, 1 unit
        thick — a `rectangle` rendered without `stroke_enabled(False)` gets
        one nobody asked for.

        Thickness is in world units, scaled by autoscale like every other
        coordinate, and never rendered thinner than one pixel; a fractional
        one (`thickness=1.5`) rounds to whole pixels once scaled.
        """
        if color:
            self._style.stroke_color = color.value()
        if thickness:
            self._style.stroke_thickness = thickness.value()
        self._style.stroke_enabled = True

    def fill_enabled(mut self, enabled: Bool):
        """Switch the fill off or back on. The fill color and any gradient
        are kept while off, so `fill_enabled(True)` brings back the same
        fill; `fill(...)` switches it on too."""
        self._style.fill_enabled = enabled

    def stroke_enabled(mut self, enabled: Bool):
        """Switch the stroke off or back on. Color and thickness are kept
        while off, so `stroke_enabled(True)` brings back the same stroke;
        `stroke(...)` switches it on too."""
        self._style.stroke_enabled = enabled

    def stroke_alignment(mut self, alignment: StrokeAlign):
        """Place the stroke of every region inside its edge
        (`StrokeAlign.INSIDE`, the default), centred on it (`CENTER`) or
        around it (`OUTSIDE`). The fill meets the stroke's inner edge. Lines
        and curves have no inside and are always stroked centred, so it
        changes nothing there. Doesn't switch the stroke on."""
        self._style.stroke_alignment = alignment

    def stroke_cap(mut self, cap: StrokeCap):
        """Finish the open ends of lines and curves with `cap`:
        `StrokeCap.BUTT` (the default) flush with the end point, `ROUND` a
        half disc, `SQUARE` pushed out by half the thickness. A region's
        stroke and a closed curve have no ends, so it changes nothing there
        unless the stroke is dashed, when it finishes every dash.
        Doesn't switch the stroke on."""
        self._style.stroke_cap = cap

    def stroke_dash(mut self, dash: StrokeDash):
        """Break every stroke into dashes: `StrokeDash.DASHED` or `DOTTED`,
        scaled to the stroke's thickness, or exact lengths in world units
        such as `StrokeDash(12, 6)`. `StrokeDash.SOLID` (the default) draws
        it unbroken again. Each dash's ends take `stroke_cap`, a region's
        too; see `StrokeDash` for where a pattern starts. Doesn't switch
        the stroke on."""
        self._style.stroke_dash = dash

    def corner_radius(mut self, radius: Float64):
        """Round the shapes built from numbers by `rectangle`, `triangle`,
        `polygon` and `sector`, in world units, unless a call names its own
        `corner_radius`. A shape value carries its own radius, so
        `draw(shape)` and `clip(shape)` ignore this one: what is drawn from
        a shape is what its `contains` tests. Clamped per shape as the shape
        describes."""
        self._style.corner_radius = radius

    def corner_radius(mut self, radius: Int):
        self.corner_radius(Float64(radius))

    def clear(mut self):
        """Discard everything drawn so far, back to how the canvas started.

        An offscreen canvas is transparent again. The frame canvas starts
        the frame over: opened with the clear to grey 200 while the
        autoclear is on, or from the last frame's pixels while it is off.
        Style, transform, camera and settings are untouched — this undoes
        drawing, not state — and inside a `clip` block the clip still
        applies to what is drawn next. To paint over what is there instead,
        use `background()`.
        """
        self._state._backend[].discard()
        if self._state.autoclear and not self._offscreen():
            self._state._backend[].buffer.open_with_clear(
                clear_command(_AUTOCLEAR_COLOR)
            )

    def background(mut self, color: Color):
        """Paint the whole framebuffer — the usual first call in `update`.

        A translucent color blends instead of clearing, which is how motion
        trails are rendered: `canvas.background(Color(0x11, 0x11, 0x11, 24))`
        fades the previous frame a little further each time. Trails need
        `canvas.autoclear(False)` set in `create`, or the frame's own clear wipes
        what they were fading.

        An opaque color replaces the autoclear rather than
        stacking on it, so opening `update` with this costs one clear, not two.
        """
        self._state._backend[].buffer.record_clear(clear_command(color))

    def background(mut self, gradient: Gradient):
        """Paint the whole framebuffer with `gradient` — a sky, a vignette.

        It spans the screen, `left()` to `right()` and `bottom()` to
        `top()`, whatever the camera is doing; under `EXTEND` that is the
        whole window. Where `FIT` leaves letterbox bars, the bars are painted
        over it as usual.

        Like a colour, it replaces the autoclear if every stop
        is opaque, and blends over what is there otherwise.
        """
        self._state._backend[].buffer.record_clear(
            clear_command(
                gradient,
                self._base,
                self._width,
                self._height,
            )
        )

    @always_inline
    def save_image(
        mut self,
        path: String,
        pixel_scale: Float64 = 1.0,
        transparent: Bool = False,
    ) raises:
        """Save this frame as a PNG at the design size, times `pixel_scale`.

        Window-independent by construction: the size of the file is the space
        the program renders in, never the size of the window, and the letterbox
        bars are absent because they belong to a window this image is not of.
        The same call under either backend produces the same image — the
        capture is rasterised on the CPU from the recorded commands, so the
        GPU path needs no readback. That is what makes this the export to use
        for artwork, posters and golden-image tests; use `save_screenshot` for
        what the user actually saw.

        `transparent` drops the frame's `background`, leaving alpha 0 wherever
        nothing was rendered. `pixel_scale` multiplies the output resolution, so
        `pixel_scale=2.0` gives a 2x export of the identical layout.

        Deferred, not immediate: the file is written when the frame is
        presented, so it holds the whole frame however early in `update` this
        was called. A failure to write raises there, from `present`, rather
        than here.

        An offscreen canvas has no frame to present, so it writes at once,
        what it has drawn so far. Its pixels are already rasterised, so a
        `pixel_scale` other than its own resamples them, and `transparent` keeps
        their alpha rather than dropping a `background` it has painted.

        A relative `path` is resolved against the directory of the calling
        source file, not the working directory, as `Image.load`'s is.
        """
        self._save_image(_caller_relative(path), pixel_scale, transparent)

    def _save_image(
        mut self, path: String, pixel_scale: Float64, transparent: Bool
    ) raises:
        """`save_image`, to a path already resolved."""
        comptime if IN_LIBRARY:
            self._save_image_here(path, pixel_scale, transparent)
        else:
            var error = Slot(String())
            var ok = entry[_SaveImage, "create_canvas_save_image"]()(
                address(self),
                address(path),
                pixel_scale,
                transparent,
                error.address(),
            )
            check(ok, error^)

    def _save_image_here(
        mut self, path: String, pixel_scale: Float64, transparent: Bool
    ) raises:
        """`_save_image`, in the library."""
        if pixel_scale <= 0.0:
            raise Error(
                "save_image needs a positive pixel_scale, got "
                + String(pixel_scale)
            )
        if self._offscreen():
            var mem = self._read_offscreen(self.bounds(), pixel_scale)
            mem.save(path, opaque=not transparent)
            return
        var capture = Viewport()
        # The design size, not the window's: under `EXTEND` that is the
        # extended space, which is exactly the area the program drew into.
        capture.autoscale = Autoscale.FIT
        capture.set_design(self._width, self._height)
        var pw = Int(self._width * pixel_scale + 0.5)
        var ph = Int(self._height * pixel_scale + 0.5)
        capture.set_size(pw, ph)
        self._state._backend[].captures.request_image(
            _ImageRequest(
                path,
                pw,
                ph,
                capture.scale,
                # Commands carry the *window's* mapping baked in; undoing it
                # and applying the capture's is a pure similarity, so one
                # matrix in front of the replay is the whole rebase.
                capture.base_matrix() @ self._base_inv,
                transparent,
            )
        )

    def color_at(mut self, position: Point) raises -> Color:
        """The colour at `position` in what this frame has drawn so far.

        `position` is in screen space, whatever the camera or transform —
        a read is of the screen, not the scene — so
        `canvas.color_at(context.mouse.position)` picks under the mouse as it is.
        Outside the screen it is `Color.TRANSPARENT`.

        Reads what is drawn *so far*: a render call after this one does not
        change what it returned. The pixels are those `save_image` would
        write at scale 1, on either backend, without the letterbox. Reading
        replays the frame on the CPU once, and again only after something
        more is drawn, so many reads in a row cost one replay.

        With `canvas.autoclear(False)`, a read starts from the last frame's
        pixels, as the frame did — from the second frame that reads on; the
        first sees only what it drew itself. That needs the CPU backend,
        which is also the only one that accumulates.

        On an offscreen canvas a read replays what was drawn since the last
        one onto the canvas's own pixels, at its own `scale`.
        """
        comptime if IN_LIBRARY:
            return self._color_at_here(position)
        else:
            var color = Slot(Color.TRANSPARENT)
            var error = Slot(String())
            var ok = entry[_ColorAt, "create_canvas_color_at"]()(
                address(self),
                address(position),
                color.address(),
                error.address(),
            )
            check(ok, error^)
            return color^.take()

    def _color_at_here(mut self, position: Point) raises -> Color:
        """`color_at`, in the library."""
        if self._offscreen():
            self._state._backend[].bake(self._scale)
            var p = self._base._apply_xy(position.x, position.y)
            ref target = self._state._backend[].target.value()
            var px = Int(floor(p[0]))
            var py = Int(floor(p[1]))
            if px < 0 or py < 0 or px >= target.width or py >= target.height:
                return Color.TRANSPARENT
            return target.pixel(px, py)
        # The read is whole units, centred on the screen like the frame.
        ref backend = self._state._backend[]
        var x = Int(floor(position.x + Float64(backend.frame_w) / 2.0))
        var y = Int(floor(Float64(backend.frame_h) / 2.0 - position.y))
        if x < 0 or y < 0 or x >= backend.frame_w or y >= backend.frame_h:
            return Color.TRANSPARENT
        backend.read_frame(seeded=not self._state.autoclear)
        return backend.frame_read.value().pixel(x, y)

    def snapshot(mut self, pixel_scale: Float64 = 1.0) raises -> Image:
        """What this frame has drawn so far, as an `Image` of the whole
        screen: `width * pixel_scale` by `height * pixel_scale` pixels.

        Drawn back with `canvas.image(shot, (0, 0), canvas.width(),
        canvas.height())` it lines up with the frame exactly — a feedback
        effect is a snapshot kept as a field and drawn under the next frame.
        `pixel_scale=canvas.pixel_scale()` gives the window's own resolution instead.
        Everything `color_at` says about what is read applies.
        """
        return self.snapshot(self.bounds(), pixel_scale)

    def snapshot(
        mut self, region: Rectangle, pixel_scale: Float64 = 1.0
    ) raises -> Image:
        """What this frame has drawn so far inside `region`, as an `Image`
        of `region.w * pixel_scale` by `region.h * pixel_scale` pixels.

        `region` is in screen space, like `color_at`'s position, so it is always
        upright, and a turned one raises; outside the screen the image is
        transparent.

        On an offscreen canvas `pixel_scale=canvas.pixel_scale()` reads its pixels as they
        are; any other value resamples them, nearest pixel.
        """
        comptime if IN_LIBRARY:
            return self._snapshot_here(region, pixel_scale)
        else:
            var image = Slot(Optional[Image]())
            var error = Slot(String())
            var ok = entry[_Snapshot, "create_canvas_snapshot"]()(
                address(self),
                address(region),
                pixel_scale,
                image.address(),
                error.address(),
            )
            check(ok, error^)
            var shot = image^.take()
            return shot.take()

    def _snapshot_here(
        mut self, region: Rectangle, pixel_scale: Float64
    ) raises -> Image:
        """`snapshot`, in the library."""
        if pixel_scale <= 0.0:
            raise Error(
                "snapshot needs a positive pixel_scale, got "
                + String(pixel_scale)
            )
        if region.rotation != 0.0:
            raise Error(
                "snapshot needs an upright region, got " + String(region)
            )
        var pw = Int(region.width * pixel_scale + 0.5)
        var ph = Int(region.height * pixel_scale + 0.5)
        if pw <= 0 or ph <= 0:
            raise Error(
                "snapshot needs a region of at least one pixel, got "
                + String(region)
            )
        if self._offscreen():
            var mem = self._read_offscreen(region, pixel_scale)
            return Image.from_rgba(pw, ph, mem.data)
        ref backend = self._state._backend[]
        if (
            pixel_scale == 1.0
            and pw == backend.frame_w
            and ph == backend.frame_h
            and region.position == Point(0.0, 0.0)
        ):
            # The whole screen at design size is what `color_at` reads,
            # so the two share one replay.
            backend.read_frame(seeded=not self._state.autoclear)
            return Image.from_rgba(pw, ph, backend.frame_read.value().data)
        var to_target = Transform(
            translation=Vector(
                (region.width / 2.0 - region.position.x) * pixel_scale,
                (region.height / 2.0 + region.position.y) * pixel_scale,
            )
        ) @ Transform(scale_x=pixel_scale, scale_y=-pixel_scale)
        var mem = backend.read(
            pw, ph, pixel_scale, to_target, not self._state.autoclear
        )
        return Image.from_rgba(pw, ph, mem.data)

    def _read_offscreen(
        mut self, region: Rectangle, scale: Float64
    ) raises -> MemorySurface:
        """An offscreen canvas's pixels inside `region`, `scale` pixels to
        the unit, once what was drawn since the last read is baked in."""
        ref backend = self._state._backend[]
        backend.bake(self._scale)
        ref target = backend.target.value()
        var pw = Int(region.width * scale + 0.5)
        var ph = Int(region.height * scale + 0.5)
        var mem = MemorySurface(pw, ph)
        if (
            pw == target.width
            and ph == target.height
            and region.position == Point(0.0, 0.0)
        ):
            # The whole canvas at its own density: the pixels as they are.
            mem.data = target.data.copy()
            return mem^
        var to_target = Transform(
            translation=Vector(
                (region.width / 2.0 - region.position.x) * scale,
                (region.height / 2.0 + region.position.y) * scale,
            )
        ) @ Transform(scale_x=scale, scale_y=-scale)
        _seed(mem, target, self._base, to_target)
        return mem^

    @always_inline
    def save_screenshot(mut self, path: String) raises:
        """Save this frame as a PNG at the framebuffer's own resolution.

        The complement of `save_image`: this answers what the user *saw*, so
        it is the size of the drawable, letterbox bars included, rendered by
        whichever rasteriser actually drew the frame. That makes it
        deliberately machine-dependent — window size, HiDPI scaling and any
        driver antialiasing are all in it, and two machines will not produce
        the same file. Right for a bug report or for sharing a running sketch;
        use `save_image` for anything that has to be reproducible.

        Deferred and raising in the same way as `save_image`: the file is
        written when the frame is presented, and a failure raises from there.

        An offscreen canvas writes at once: its own pixels, at its own
        density, alpha kept — it has no window to have been seen in.

        A relative `path` is resolved against the directory of the calling
        source file, as `save_image`'s is.
        """
        self._save_screenshot(_caller_relative(path))

    def _save_screenshot(mut self, path: String) raises:
        """`save_screenshot`, to a path already resolved."""
        comptime if IN_LIBRARY:
            self._save_screenshot_here(path)
        else:
            var error = Slot(String())
            var ok = entry[_CanvasPath, "create_canvas_save_screenshot"]()(
                address(self), address(path), error.address()
            )
            check(ok, error^)

    def _save_screenshot_here(mut self, path: String) raises:
        """`_save_screenshot`, in the library."""
        if self._offscreen():
            self._state._backend[].bake(self._scale)
            self._state._backend[].target.value().save(path, opaque=False)
            return
        self._state._backend[].captures.request_screenshot(path)

    @always_inline
    def start_recording(
        mut self,
        path: String,
        *,
        seconds: OptionalNumber = None,
        frames: Optional[Int] = None,
        fps: Float64 = 30.0,
        pixel_scale: Float64 = 1.0,
        dither: Bool = False,
        transparent: Bool = False,
    ) raises:
        """Record the frames from this one on as an animated GIF at `path`.

        Each frame is what `save_image` would save: the design size times
        `pixel_scale`, no letterbox, replayed on the CPU, so either backend and
        every machine records the same pixels, and a headless run records
        deterministically. Recording starts with the frame this is called
        in, captured whole however early in `update` it was called, and runs
        until `seconds` of the run's time or `frames` frames, until
        `stop_recording`, or until the run ends, which finishes the file;
        `cancel_recording` ends it without one. A new `start_recording`
        finishes the recording in progress first.

        Until it finishes, the frames stream to `path` with `.partial`
        added, which then replaces `path` in one step: a file already at
        `path` is untouched until then, and stays if the recording is
        cancelled.

        The run's clock is sampled `fps` times a second, so the GIF plays at
        the program's own speed whatever the display's rate: a window faster
        than `fps` skips frames, and a slow frame stays on screen longer. A
        GIF times frames in hundredths of a second, and many players slow
        anything faster than 50 fps, so `fps` is at most 50.

        Each frame gets a palette of its own: exact if it has 256 colours or
        fewer, the nearest 256 otherwise. `dither` mixes neighbouring pixels
        so smooth gradients don't band, at the cost of a grainier file. Only
        what changed is stored: a frame after the first holds the rectangle
        that changed, and an unchanged frame lengthens the one before.

        `transparent` leaves the background out, as `save_image`'s does:
        the frame's clears and `background` calls are dropped, and a pixel
        under half alpha is transparent. A GIF pixel is either transparent
        or opaque, so an antialiased edge comes out hard, though in its own
        colour, with no fringe. Each frame replaces the last rather than
        drawing over it, so nothing earlier shows through its holes. With
        the autoclear off, it starts from nothing rather than the picture on
        screen, which has the background in it.

        Capturing and encoding run as each frame is presented, so a long
        recording of a heavy scene slows it down.

        With the autoclear off, the recording keeps what earlier frames
        left, as the screen does: every frame is replayed into it, captured
        or not, so ink drawn between two captured frames is kept, at the
        cost of a CPU replay of every frame while it records. It starts from
        the picture already on screen: its first frame is the window's own,
        sampled to the recording's size, so that one frame, unlike the rest,
        depends on the window and the backend. Whatever
        starts the screen's picture over starts the recording's over too:
        resizing the window, and on the GPU changing the antialiasing.

        Raises at once for a path not ending in `.gif`, `seconds` and
        `frames` both given, a value that isn't positive, `fps` above 50, a
        file that can't be opened, or an offscreen canvas, which has no
        frames to record.

        A relative `path` is resolved against the directory of the calling
        source file, as `save_image`'s is.
        """
        self._start_recording(
            _caller_relative(path),
            seconds,
            frames,
            fps,
            pixel_scale,
            dither,
            transparent,
        )

    def _start_recording(
        mut self,
        path: String,
        seconds: OptionalNumber,
        frames: Optional[Int],
        fps: Float64,
        scale: Float64,
        dither: Bool,
        transparent: Bool,
    ) raises:
        """`start_recording`, to a path already resolved."""
        comptime if IN_LIBRARY:
            self._start_recording_here(
                path, seconds, frames, fps, scale, dither, transparent
            )
        else:
            var request = _RecordingRequest(
                path, seconds, frames, fps, scale, dither, transparent
            )
            var error = Slot(String())
            var ok = entry[_CanvasPath, "create_canvas_start_recording"]()(
                address(self), address(request), error.address()
            )
            _ = request^  # passed by address only: kept alive past the call
            check(ok, error^)

    def _start_recording_here(
        mut self,
        path: String,
        seconds: OptionalNumber,
        frames: Optional[Int],
        fps: Float64,
        scale: Float64,
        dither: Bool,
        transparent: Bool,
    ) raises:
        """`_start_recording`, in the library."""
        if self._offscreen():
            raise Error(
                "start_recording needs the frame canvas: an offscreen canvas"
                " has no frames"
            )
        if not path.lower().endswith(".gif"):
            raise Error(
                "start_recording saves GIF files, so its path must end in .gif,"
                " got "
                + path
            )
        if seconds and frames:
            raise Error("start_recording takes seconds or frames, not both")
        if seconds and seconds.value() <= 0.0:
            raise Error(
                "start_recording needs positive seconds, got "
                + String(seconds.value())
            )
        if frames and frames.value() <= 0:
            raise Error(
                "start_recording needs a positive number of frames, got "
                + String(frames.value())
            )
        if fps <= 0.0 or fps > 50.0:
            raise Error("start_recording's fps must be above 0 and at most 50")
        if scale <= 0.0:
            raise Error(
                "start_recording needs a positive scale, got " + String(scale)
            )
        var capture = Viewport()
        capture.autoscale = Autoscale.FIT
        capture.set_design(self._width, self._height)
        var pw = Int(self._width * scale + 0.5)
        var ph = Int(self._height * scale + 0.5)
        capture.set_size(pw, ph)
        var max_slots = Optional[Int]()
        if seconds:
            max_slots = Int(ceil(seconds.value() * fps - 1e-9))
        self._state._backend[].captures.start_recording(
            _Recording(
                GifWriter(path, pw, ph),
                capture.scale,
                capture.base_matrix(),
                fps,
                dither,
                transparent,
                max_slots,
                frames,
            )
        )

    def stop_recording(mut self) raises:
        """Finish the recording in progress now and save it: the file is
        complete when this returns, and the frame it is called in is not in
        it. `cancel_recording` ends one without saving. Nothing happens when
        nothing is being recorded."""
        comptime if IN_LIBRARY:
            self._state._backend[].captures.finish_recording()
        else:
            self._recording_call["create_canvas_stop_recording"]()

    def cancel_recording(mut self) raises:
        """End the recording in progress without saving it: no file appears
        at its path, and a file already there is left as it was. Nothing
        happens when nothing is being recorded."""
        comptime if IN_LIBRARY:
            self._state._backend[].captures.cancel_recording()
        else:
            self._recording_call["create_canvas_cancel_recording"]()

    def _recording_call[name: StaticString](mut self) raises:
        """Stop or cancel the recording, through the library."""
        var error = Slot(String())
        var ok = entry[_CanvasCall, name]()(address(self), error.address())
        check(ok, error^)

    def recording(self) -> Bool:
        """Whether a recording started by `start_recording` is in progress."""
        return Bool(self._state._backend[].captures.recording)

    def rectangle(
        mut self,
        position: Point,
        width: Float64,
        height: Float64,
        *,
        corner_radius: OptionalNumber = None,
        rotation: OptionalNumber = 0.0,
    ):
        """Draw the `width` by `height` rectangle centred on `position`, its
        corners rounded by `corner_radius`, or by the style's when not given
        (clamped to half the shorter side), and turned about its centre by
        `rotation` radians counter-clockwise, as `Rectangle` describes it."""
        self.draw(
            Rectangle(
                position,
                width,
                height,
                corner_radius=corner_radius.or_else(self._style.corner_radius),
                rotation=rotation,
            )
        )

    def rectangle(
        mut self,
        position: Point,
        width: Int,
        height: Int,
        *,
        corner_radius: OptionalNumber = None,
        rotation: OptionalNumber = 0.0,
    ):
        self.rectangle(
            position,
            Float64(width),
            Float64(height),
            corner_radius=corner_radius,
            rotation=rotation,
        )

    def circle(mut self, position: Point, radius: Float64):
        self.draw(Circle(position, radius))

    def circle(mut self, position: Point, radius: Int):
        self.circle(position, Float64(radius))

    def ellipse(mut self, position: Point, width: Float64, height: Float64):
        """Draw the axis-aligned ellipse centred on `position`, `width` wide and
        `height` high: an `Ellipse`, filling the rectangle
        `rectangle(position, width, height)` would draw. Turn one with
        `transform`.

        The stroke is inset, as a circle's is, and as thick all round: the
        fill stops where it starts, and a translucent ellipse composites
        once. It is drawn as a polygon, flattened as finely as a circle of
        its larger radius, so filled it costs what a circle does and
        stroked what a stroked `polygon` of its outline does, about three
        times a circle's. A blurred drop shadow or an inset one costs what a
        `bezier`'s blurred shadow does. With `width == height` it covers what
        `circle(position, width / 2)` does, to within its flattening.
        """
        self.draw(Ellipse(position, width, height))

    def ellipse(mut self, position: Point, width: Int, height: Int):
        self.ellipse(position, Float64(width), Float64(height))

    def capsule(mut self, start: Point, end: Point, radius: Float64):
        """Draw the capsule round the segment from `start` to `end`: every
        point within `radius` of it, a `Capsule`, its ends half discs.

        The stroke is inset, as a circle's is: the fill stops where it
        starts, and a translucent capsule composites once. Unlike a
        round-capped `line`, it has a fill and a stroke of its own. It is
        drawn as a polygon, each end flattened as finely as a circle of
        `radius`, so filled it costs what a circle does and stroked what a
        stroked `polygon` of its outline does. A blurred drop shadow or an
        inset one costs what a `bezier`'s blurred shadow does. A zero
        `radius` draws nothing.
        """
        self.draw(Capsule(start, end, radius))

    def capsule(mut self, start: Point, end: Point, radius: Int):
        self.capsule(start, end, Float64(radius))

    def sector(
        mut self,
        position: Point,
        radius: Float64,
        start_angle: Float64,
        sweep_angle: Float64,
        *,
        corner_radius: OptionalNumber = None,
    ):
        """Draw the pie slice of the circle around `position` with `radius`,
        from `start_angle` round by `sweep_angle`: a `Sector`, its tip at
        `position`.

        Angles are radians, counter-clockwise from the +x axis (y is up); a
        negative sweep runs clockwise, and a full turn or more is the whole
        disc. The stroke is inset, as a circle's is: the fill stops where it
        starts, and a translucent sector composites once. A blurred drop
        shadow or an inset one costs what a `bezier`'s blurred shadow does.
        A zero radius or sweep draws nothing.

        `corner_radius`, or the style's when not given, rounds the tip and
        both ends of the arc, as `Sector` describes. A rounded sector is
        drawn as a polygon, so it costs what a stroked `polygon` of its
        flattened outline does.
        """
        self.draw(
            Sector(
                position,
                radius,
                start_angle,
                sweep_angle,
                corner_radius=corner_radius.or_else(self._style.corner_radius),
            )
        )

    def sector(
        mut self,
        position: Point,
        radius: Int,
        start_angle: Float64,
        sweep_angle: Float64,
        *,
        corner_radius: OptionalNumber = None,
    ):
        self.sector(
            position,
            Float64(radius),
            start_angle,
            sweep_angle,
            corner_radius=corner_radius,
        )

    def polygon(
        mut self, *vertices: Point, corner_radius: OptionalNumber = None
    ):
        """Draw the polygon through `vertices`, closed back to the first.

        Filled by the nonzero rule, so a self-crossing polygon fills every
        area its edges wind round, whichever way they run. The stroke is
        inset along the outside, as a sector's is, and centred on an edge
        running through the inside — a pentagram's inner pentagon — so every
        edge is stroked as thick; a translucent polygon composites once. A
        blurred drop shadow or an inset one costs what a `bezier`'s blurred
        shadow does. Fewer than three vertices draw nothing.

        `corner_radius`, or the style's when not given, rounds every corner,
        as `Polygon` describes; each
        rounded corner adds vertices, and so cost. A `Polygon` value is drawn
        with `draw`.
        """
        var points = List[Point](capacity=len(vertices))
        for v in vertices:
            points.append(v)
        self.polygon(points^, corner_radius=corner_radius)

    def polygon(
        mut self,
        var vertices: List[Point],
        corner_radius: OptionalNumber = None,
    ):
        """Draw the polygon through `vertices`, a list built at run time:
        otherwise as the variadic `polygon`, and like `spline`'s `points`."""
        self.draw(
            Polygon(
                vertices^,
                corner_radius=corner_radius.or_else(self._style.corner_radius),
            )
        )

    def line(mut self, start: Point, end: Point):
        """Stroke the line from `start` to `end` in the stroke colour and
        thickness, its ends finished as `stroke_cap` says. A line has no
        interior, so `fill` never applies; a line of no length is a dot under
        `StrokeCap.ROUND` or `SQUARE` and nothing under `BUTT`."""
        self.draw(Line(start, end))

    def point(mut self, position: Point):
        """Draw a dot at `position` in the stroke colour, as wide as the
        stroke is thick: round, or square under `StrokeCap.SQUARE`. A point
        is never dashed, and draws nothing while the stroke is off."""
        var cap = self._style.stroke_cap
        var dash = self._style.stroke_dash
        if cap != StrokeCap.SQUARE:
            self._style.stroke_cap = StrokeCap.ROUND
        self._style.stroke_dash = StrokeDash.SOLID
        self.draw(Line(position, position))
        self._style.stroke_cap = cap
        self._style.stroke_dash = dash

    def bezier(
        mut self,
        start: Point,
        control1: Point,
        control2: Point,
        end: Point,
    ):
        """Stroke the cubic Bézier from `start` to `end`, shaped by the two
        controls, in the stroke colour and thickness.

        A curve, like a line, has no interior: `fill` never applies, and with
        the stroke off nothing is drawn. The curve is flattened at replay,
        in device pixels, so it stays smooth under any camera zoom; its ends
        are finished as `stroke_cap` says, like a line's, unless `end` is
        `start`: then the curve closes on a mitred joint and has none. Joints
        are mitred and caps share the end's edge, so a translucent stroke
        composites once, except at a sharp cusp, where it may overlap slightly.

        A blurred shadow is blurred afresh every frame (it cannot be cached
        like an image's), and on the GPU costs one extra draw call.
        """
        self.draw(Bezier(start, control1, control2, end))

    def spline(
        mut self,
        var points: List[Point],
        alpha: Float64 = 0.5,
        closed: Bool = False,
    ):
        """Stroke a smooth curve through every one of `points`, in order, in
        the stroke colour and thickness: a `Spline`, which is Catmull-Rom.

        `alpha` sets how the spacing of the points shapes the curve: 0 can
        loop or cusp where points bunch up, 0.5 (centripetal) never does,
        1 hugs the points more loosely still. With `closed`, the curve runs
        on from the last point back to the first, and that joint is mitred
        like the rest.

        Drawn as one stroke, like `bezier`: no fill, nothing with the stroke
        off, ends as `stroke_cap` says when open, and a translucent stroke
        composites once. A blurred shadow costs what a `bezier`'s does. Fewer
        than two distinct
        points draw nothing.
        """
        self.draw(Spline(points^, alpha, closed))

    def arc(
        mut self,
        position: Point,
        radius: Float64,
        start_angle: Float64,
        sweep_angle: Float64,
    ):
        """Stroke the arc of the circle around `position` with radius `radius`,
        from `start_angle` round by `sweep_angle`, in the stroke colour and
        thickness: an `Arc`.

        Angles are radians, counter-clockwise from the +x axis (y is up); a
        negative sweep runs clockwise, and a full turn or more is the whole
        circle, closed on a mitred joint.

        Drawn as one stroke, like `bezier`: no fill, nothing with the stroke
        off, ends as `stroke_cap` says short of a whole turn, and a translucent
        stroke composites once. A blurred shadow costs what a `bezier`'s does.
        A zero radius or sweep
        draws nothing.
        """
        self.draw(Arc(position, radius, start_angle, sweep_angle))

    def arc(
        mut self,
        position: Point,
        radius: Int,
        start_angle: Float64,
        sweep_angle: Float64,
    ):
        self.arc(position, Float64(radius), start_angle, sweep_angle)

    def triangle(
        mut self,
        a: Point,
        b: Point,
        c: Point,
        *,
        corner_radius: OptionalNumber = None,
    ):
        """Draw the triangle through `a`, `b` and `c`, its corners rounded
        by `corner_radius`, or by the style's when not given, as `Triangle`
        describes it."""
        self.draw(
            Triangle(
                a,
                b,
                c,
                corner_radius=corner_radius.or_else(self._style.corner_radius),
            )
        )

    def draw[G: Geometry](mut self, shape: G):
        """Draw `shape`, any shape or curve, in the current style and
        transform: `canvas.draw(Circle((0, 0), 20))` is
        `canvas.circle((0, 0), 20)`. A shape value carries its own
        `corner_radius`, so the style's doesn't round it."""
        draw_geometry(shape, self)

    def draw[D: Drawable](mut self, drawable: D):
        """Draw a `Drawable` of the program's own: its `draw_to` draws its
        parts, each in the current style and transform."""
        drawable.draw_to(self)

    def draw[G: Geometry](mut self, shape: G, *, style: Style):
        """Draw `shape` in `style`, applied over the current style for this
        call alone: the parts `style` sets are used, and the rest keep their
        current values. The style is as it was afterwards.

        ```mojo
        # In `update`, with a `highlight: Style` field:
        canvas.draw(Circle((0, 0), 20), style=self.highlight)
        ```

        It reads best with a style you have named. A style written out in
        the call reads better as a `with canvas.style(...)` block around it.
        """
        var saved = self._style
        self._style.apply(style)
        draw_geometry(shape, self)
        self._style = saved

    def draw[D: Drawable](mut self, drawable: D, *, style: Style):
        """Draw a `Drawable` of the program's own in `style`, applied over the
        current style for this call alone. Its parts are drawn in it, and a
        part drawn with a style of its own applies that over it in turn.

        ```mojo
        # In a `Drawable`'s `draw_to`, with an `accent: Style` field: the
        # plate in the style around it, the disc in `accent` over that.
        canvas.draw(self.plate)
        canvas.draw(self.disc, style=self.accent)
        ```
        """
        var saved = self._style
        self._style.apply(style)
        drawable.draw_to(self)
        self._style = saved

    # The geometry primitives: the one place a shape becomes a recorded
    # command, in the current style and transform. `draw(shape)` reaches
    # them through `draw_geometry`, and every named method above through
    # its shape.

    def _rectangle(mut self, r: Rectangle):
        self._state._backend[].buffer.record(
            shape_command(r, self._transform, self._style, self._scale)
        )

    def _circle(mut self, c: Circle):
        self._state._backend[].buffer.record(
            shape_command(c, self._transform, self._style, self._scale)
        )

    def _ellipse(mut self, e: Ellipse):
        self._state._backend[].buffer.record(
            shape_command(e, self._transform, self._style, self._scale)
        )

    def _capsule(mut self, c: Capsule):
        self._state._backend[].buffer.record(
            shape_command(c, self._transform, self._style, self._scale)
        )

    def _triangle(mut self, t: Triangle):
        self._state._backend[].buffer.record(
            shape_command(t, self._transform, self._style, self._scale)
        )

    def _sector(mut self, s: Sector):
        self._state._backend[].buffer.record(
            shape_command(s, self._transform, self._style, self._scale)
        )

    def _polygon(mut self, p: Polygon):
        self._state._backend[].buffer.record(
            shape_command(p, self._transform, self._style, self._scale)
        )

    def _line(mut self, l: Line):
        # Recorded only when it would render: a stroke-less line is the one
        # shape with nothing left to paint, so the command would be pure
        # overhead.
        if not self._style.stroke_enabled:
            return
        self._state._backend[].buffer.record(
            shape_command(l, self._transform, self._style, self._scale)
        )

    def _curves(mut self, curves: List[Bezier]):
        # Recorded only when it would render, as `line` is; no curves, no
        # stroke.
        if not self._style.stroke_enabled or len(curves) == 0:
            return
        self._state._backend[].buffer.record(
            curves_command(curves, self._transform, self._style)
        )

    def image(mut self, image: Image, position: Point):
        """Render `image` at its own pixel size.

        The same command as the sized overload: at a pixel scale of 1 the two
        agree exactly, and the one-image-pixel-per-framebuffer-pixel shortcut
        they used to differ by now lives inside `blit_image`, where the replay
        can take it without the record site having to know.
        """
        self.image(
            image, position, Float64(image.width()), Float64(image.height())
        )

    def image(
        mut self,
        image: Image,
        position: Point,
        width: Float64,
        height: Float64,
    ):
        # The image is interned *now*, not at replay: the command then carries
        # an id rather than a borrow of the program's pixels, which is what
        # keeps caller-owned memory out of a buffer that outlives the call.
        var id: Int
        comptime if IN_LIBRARY:
            id = intern_image(self._state._backend[], image)
        else:
            try:
                id = entry[_InternImage, "create_backend_intern_image"]()(
                    address(self._state._backend[]), address(image)
                )
            except:
                id = 0  # unreachable: the library is open, it built the backend
        self._state._backend[].buffer.record(
            image_command(
                self._transform,
                self._style,
                position.x,
                position.y,
                width,
                height,
                id,
                image.width(),
                image.height(),
            )
        )

    def image(mut self, animator: Animator, position: Point):
        """Render the animator's current frame, centred at `position`."""
        self.image(animator.animation().frame(animator.frame_index()), position)

    def image(
        mut self,
        animator: Animator,
        position: Point,
        width: Float64,
        height: Float64,
    ):
        self.image(
            animator.animation().frame(animator.frame_index()),
            position,
            width,
            height,
        )

    def image(mut self, image: Image, position: Point, width: Int, height: Int):
        self.image(image, position, Float64(width), Float64(height))

    def image(
        mut self, animator: Animator, position: Point, width: Int, height: Int
    ):
        self.image(animator, position, Float64(width), Float64(height))

    def text_color(mut self, color: Color):
        """Paint glyphs in `color`. Separate from `fill`, so a shape colour and
        a label colour do not have to be set in turn; a fully transparent one
        skips the text entirely."""
        self._style.text_color = color

    def font_size(mut self, size: Float64):
        """Text height in world units, scaled by autoscale like a coordinate.
        Glyphs are rasterised at whole pixel sizes, so a fractional size rounds
        once scaled."""
        self._style.font_size = size

    def font_size(mut self, size: Int):
        self.font_size(Float64(size))

    def font_weight(mut self, weight: FontWeight):
        """Stroke weight of the face, a `FontWeight`. The packaged Noto
        faces are variable, so this interpolates rather than swapping files."""
        self._style.font_weight = weight

    def font_italic(mut self, enabled: Bool):
        """Draw text in the face's italic: the font's `italic_path` file where
        it has one (the packaged Noto Sans does), otherwise its own italic
        axis, otherwise its upright glyphs slanted."""
        self._style.font_italic = enabled

    def tint(mut self, color: Color):
        """Multiply whatever is rendered next by `color`, channel by channel.

        Reaches fill, gradient, stroke, text, image and shadow alike, never
        `background`. `Color.WHITE` (the default) leaves it untouched; a
        colour recolours and darkens, and its alpha fades like `opacity`,
        which it stacks with. Tints a whole look at once, where `fill`,
        `stroke` and `text_color` each set one part:

        ```mojo
        with canvas.style(tint=Color(255, 90, 90)):
            self.player.draw(canvas)
        ```

        Resolved at record time, like every other style setting."""
        self._style.tint = color

    def opacity(mut self, value: Float64):
        """Fade whatever is rendered next: fill, gradient, stroke, text,
        image and shadow alike, never `background`. `1.0` (the default)
        leaves it untouched; `0.0` renders nothing visible. Each shape
        composites once, so a translucent one is evenly translucent, stroke
        and fill included. Resolved at record time, like every other style
        setting — it cannot reach back and fade what was already rendered."""
        self._style.opacity = value

    def blend_mode(mut self, mode: BlendMode):
        """Combine whatever is rendered next with what is already there by
        `mode` — `BlendMode.ADD` for glows, `MULTIPLY` for shadows — instead
        of painting over it. `BlendMode.NORMAL` (the default) paints over.

        Applies to shapes, text and images, never to `background`.
        """
        self._style.blend_mode = mode

    def shadow(
        mut self,
        color: Optional[Color] = None,
        offset: Optional[Vector] = None,
        blur: OptionalNumber = None,
        spread: OptionalNumber = None,
        inset: Optional[Bool] = None,
    ):
        """Cast a shadow behind what is rendered next, switching shadows on.
        Parts left unset keep their current values, so `shadow()` alone
        brings back the last shadow, and `shadow(blur=12)` changes only the
        blur; a fresh frame starts at a translucent black, an offset of
        `(4, -4)` (down and right, since y is up), a blur of 8 and no spread.

        Works like CSS `drop-shadow`: the shadow is the shape's whole
        silhouette, fill and stroke together, cast once — a translucent
        fill shows its own shadow through it. Lines cast their stroke, text
        its glyphs and images their alpha. `blur` is the CSS blur radius,
        twice the Gaussian's standard deviation; `spread` grows the
        silhouette before blurring. Both are world units, scaled like a
        coordinate.

        `inset=True` paints the shadow inside the shape instead, over its
        fill and within its stroke, as if the shape were a hole cut in a
        surface: the band shows on the side the offset points away from.
        A line's or a curve's inside is its stroke, and `spread` thins it;
        text's is its letters and an image's its opaque pixels, which
        `spread` leaves as they are.

        The offset is fixed to the screen, so a rotated shape's shadow still
        falls the same way; see `shadow_follows_transform`. The shadow
        combines with what is beneath it by the style's `blend_mode`, like
        the shape itself.

        ```mojo
        canvas.shadow(Color(0, 0, 0, 96), offset=Vector(6, -6), blur=12)
        canvas.rectangle((0, 0), 120, 80)
        ```
        """
        if color:
            self._style.shadow_color = color.value()
        if offset:
            self._style.shadow_offset = offset.value()
        if blur:
            self._style.shadow_blur = blur.value()
        if spread:
            self._style.shadow_spread = spread.value()
        if inset:
            self._style.shadow_inset = inset.value()
        self._style.shadow_enabled = True

    def shadow_enabled(mut self, enabled: Bool):
        """Switch shadows off or back on. Colour, offset, blur, spread and
        inset are kept while off, so `shadow_enabled(True)` brings back the
        same shadow; `shadow(color)` switches it on too. Off by default."""
        self._style.shadow_enabled = enabled

    def shadow_follows_transform(mut self, follows: Bool):
        """Whether the shadow's offset turns with the transform.

        `False` (the default) keeps it fixed to the screen, as a light
        overhead would: a rotating shape's shadow always falls the same way.
        Camera zoom and autoscale still scale it, so it stays in proportion.
        `True` applies the offset in the shape's own frame, before the
        transform, so it rotates and shears with the shape, as a CSS
        shadow does under a CSS transform.
        """
        self._style.shadow_follows_transform = follows

    def text_alignment(mut self, align: Align):
        """Anchor the next text at one of the nine points of its box.

        One argument covers both axes: `Align.CENTER` (the default) centres
        the text on the position, like every other shape, and
        `Align.TOP_LEFT` hangs it below and to the right of it. The one-word constants name an edge's
        midpoint — `Align.TOP` is top-centre. These are edges of the text box,
        not typographic baselines.
        """
        self._style.text_alignment = align

    def antialiasing(self) -> Antialiasing:
        """How smooth shape edges are: `run`'s `antialiasing` unless set."""
        return self._state._backend[].antialiasing

    def antialiasing(mut self, level: Antialiasing):
        """Smooth shape edges at `level` — `OFF` for hard pixels.

        A frame-wide setting: both backends rasterise the frame when it is
        presented, so the level covers every shape in this frame, including
        those drawn before the call, and lasts until changed. `run`'s
        `antialiasing` argument is the starting level; set it here, in
        `create` or any frame, to change it. See `Antialiasing`.
        """
        self._state._backend[].antialiasing = level
        # A read cached under the old level is stale now.
        self._state._backend[].buffer.recorded += 1

    def autoclear(self) -> Bool:
        """Whether frames open with the clear to grey 200. On unless set."""
        return self._state.autoclear

    def autoclear(mut self, enabled: Bool):
        """Switch the clear each frame opens with off or back on.

        On by default, clearing to grey 200 so the default style is visible
        on a program that never calls `background()`. Off lets ink
        accumulate across frames, on either backend.

        A frame-wide setting: it applies to this whole frame, wherever in it
        it is called — off takes this frame's opening clear back out, on puts
        it back — and lasts until changed, so set it once in `create`. An
        opaque `background()` already drawn this frame stays either way.

        No effect on an offscreen canvas, which has no frames to open and
        starts transparent; it is only read back.
        """
        self._state.autoclear = enabled
        if self._offscreen():
            return
        self._state._backend[].buffer.set_autoclear(
            enabled, clear_command(_AUTOCLEAR_COLOR)
        )

    def letterbox_color(self) -> Color:
        """The colour of the bars outside the design area. Black unless set."""
        return self._state.letterbox_color

    def letterbox_color(mut self, color: Color):
        """Colour the bars outside the design area under `Autoscale.FIT`.

        A frame-wide setting: the bars are painted after the frame is drawn,
        so this frame's bars take it wherever in the frame it is called, and
        it lasts until changed — set it once in `create`. Not part of a
        style. No effect on an offscreen canvas, which has no window to bar.
        """
        self._state.letterbox_color = color

    def font(mut self, font: Font):
        """Draw the next text in `font`, a face from `Font.load`.

        Part of the style, like `fill`: it holds for the rest of the frame,
        or for a `with canvas.style(font=...)` block, and each `text` call
        keeps the face it was drawn with. The next frame starts in the
        packaged Noto Sans again, so a font for the whole program is a
        field set at the top of `update`, or kept in a `Style`.
        """
        self._style.font = font

    def text_width(self, text: String) raises -> Float64:
        """How wide `text(text, ...)` would render under the current font, size
        and weight, in the units the next render call is positioned in: the
        width of its widest line.

        Exact for any prefix of a line too, since glyphs sit advance to
        advance with no kerning, so a caret after a line's first few
        characters goes at the line's left edge plus the width of those
        characters. With the default `Align.CENTER`, that left edge is
        `position.x - text_width(line) / 2`.

        Raises only if the default font has to be loaded and cannot be.
        """
        return self._measure_width(text, NO_WRAP)

    def text_width(self, text: String, *, width: Float64) raises -> Float64:
        """How wide `text(text, ..., width)` would render: the width of its
        widest line once wrapped at `width`, at most `width` unless a single
        glyph is wider.

        Raises only if the default font has to be loaded and cannot be.
        """
        return self._measure_width(text, max(width, 0.0))

    def text_height(self, text: String) raises -> Float64:
        """How tall `text(text, ...)` would render under the current font and
        size, in the units the next render call is positioned in: from the
        font's ascent above the first line to its descent below the last, the
        box `text_alignment` anchors. Each line break adds the font's line
        height.

        Raises only if the default font has to be loaded and cannot be.
        """
        return self._measure_height(text, NO_WRAP)

    def text_height(self, text: String, *, width: Float64) raises -> Float64:
        """How tall `text(text, ..., width)` would render: its height once
        wrapped at `width`, every line it wraps onto counted.

        Raises only if the default font has to be loaded and cannot be.
        """
        return self._measure_height(text, max(width, 0.0))

    def _text_scale(self) -> Float64:
        """The pixels per unit text is laid out at under the current
        transform, as the replays lay it out, so a measured string wraps
        where a drawn one does."""
        return text_pixel_scale(self._transform, self._scale)

    def _measure_width(self, text: String, wrap: Float64) raises -> Float64:
        return self._measure(text, wrap, height=False)

    def _measure_height(self, text: String, wrap: Float64) raises -> Float64:
        return self._measure(text, wrap, height=True)

    def _measure(
        self, text: String, wrap: Float64, height: Bool
    ) raises -> Float64:
        """`text`'s width, or its height, wrapped at `wrap`, through the
        library, whose text renderer lays it out."""
        comptime if IN_LIBRARY:
            if height:
                return self._measure_height_here(text, wrap)
            return self._measure_width_here(text, wrap)
        else:
            var result = Slot(0.0)
            var error = Slot(String())
            var ok = entry[_Measure, "create_canvas_measure"]()(
                address(self),
                address(text),
                wrap,
                height,
                result.address(),
                error.address(),
            )
            check(ok, error^)
            return result^.take()

    def _measure_width_here(
        self, text: String, wrap: Float64
    ) raises -> Float64:
        var scale = self._text_scale()
        var pixels = (
            self._state._backend[]
            .resources.text[]
            .width(
                text,
                self._style._text_style(),
                scale,
                wrap * scale if wrap != NO_WRAP else NO_WRAP,
            )
        )
        return Float64(pixels) / scale

    def _measure_height_here(
        self, text: String, wrap: Float64
    ) raises -> Float64:
        var scale = self._text_scale()
        var pixels = (
            self._state._backend[]
            .resources.text[]
            .height(
                text,
                self._style._text_style(),
                scale,
                wrap * scale if wrap != NO_WRAP else NO_WRAP,
            )
        )
        return Float64(pixels) / scale

    def text(mut self, text: String, position: Point):
        """Draw `text` at `position` in the current text style, anchored by
        `text_alignment`.

        A newline starts a new line, the font's line height below; each line
        is aligned on its own, and the alignment's top and bottom are those
        of the whole block (see `text_height`).
        """
        self._text(text, position, NO_WRAP)

    def text(mut self, text: String, position: Point, width: Float64):
        """Draw `text` at `position` as `text(text, position)` does, wrapped
        onto as many lines as keep each at most `width` units wide.

        A line breaks at its last space that fits, the spaces dropped; a word
        wider than `width` alone breaks between its letters. Newlines still
        break, and each line is aligned on its own, so `text_alignment` both
        anchors the block and aligns its lines: `Align.TOP_LEFT` sets ragged
        right text hanging from `position`. Measure the block with
        `text_width(text, width=...)` and `text_height(text, width=...)`.
        """
        self._text(text, position, max(width, 0.0))

    def _text(mut self, text: String, position: Point, wrap: Float64):
        if self._style.text_color.a == 0:
            return
        # Deferred whole. Nothing about the layout is decided here: the
        # advances, the line breaks, the alignment and the baseline all come
        # out of the font, which the backend owns, so they are resolved at
        # replay.
        self._state._backend[].buffer.record(
            text_command(
                self._transform,
                self._style,
                position.x,
                position.y,
                text.copy(),
                wrap,
            )
        )
