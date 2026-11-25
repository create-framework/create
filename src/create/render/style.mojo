from std.collections import Optional

from .align import Align
from .stroke_align import StrokeAlign
from .stroke_cap import StrokeCap
from .stroke_dash import StrokeDash
from create.color.blend_mode import BlendMode
from create.color.color import Color
from create.render.gradient import Gradient
from create.text.font import Font, FontWeight
from create.math.vector import Vector
from create.math import OptionalNumber
from ._paint import Paint, TextStyle


struct Style(Copyable, ImplicitlyCopyable, Movable, Writable):
    """A set of style changes: how something is painted, independent of where
    it goes. Each part is optional, and a part left unset changes nothing.

    The canvas holds a whole style, set piece by piece through `canvas.fill`,
    `canvas.stroke` and the other style setters, read by every render call
    until changed and rebuilt fresh each frame. A `Style` is a reusable set
    of changes to it: `with canvas.style(s):` applies the parts `s` sets,
    keeps the rest, and restores the whole style when the block ends.

    ```mojo
    var label = Style(stroke_enabled=False, text_color=Color.WHITE, font_size=24)
    with canvas.style(label):
        canvas.text("Score", (0, canvas.top() - 20))
    ```

    A shadow is part of the style too, so a card's look can carry its own:

    ```mojo
    var card = Style(
        fill=Color.WHITE,
        stroke_enabled=False,
        shadow=Color(0, 0, 0, 80),
        shadow_blur=16,
    )
    ```

    `over` layers one style over another, part by part:
    `Style(corner_radius=4).over(card)` is the card with square corners.

    `corner_radius` rounds the shapes the canvas builds from numbers --
    `canvas.rectangle(p, w, h)`, `triangle`, `polygon` and `sector` -- unless
    the call names its own `corner_radius`. A shape value carries its own
    radius, so `canvas.draw(shape)` and `canvas.clip(shape)` ignore the
    style's: what is drawn from a shape is what its `contains` tests.

    The keywords are named after the canvas setters and act like them when
    the style is applied: naming any part of the fill, stroke or shadow
    switches it on (a part, not a modifier such as `stroke_alignment`,
    `stroke_cap`, `stroke_dash` or `corner_radius`), unless `fill_enabled`,
    `stroke_enabled` or `shadow_enabled` says otherwise, so
    `Style(shadow=Color.RED, shadow_enabled=False)` keeps a shadow ready but
    off. `fill_gradient` is the keyword for `fill`'s `Gradient` overload,
    since one keyword can't take both: given beside `fill`, the gradient
    paints and the colour is kept for when it is cleared.
    """

    var fill: Optional[Color]
    var fill_gradient: Optional[Gradient]
    var fill_enabled: Optional[Bool]
    var stroke: Optional[Color]
    var stroke_thickness: Optional[Float64]
    var stroke_enabled: Optional[Bool]
    var stroke_alignment: Optional[StrokeAlign]
    var stroke_cap: Optional[StrokeCap]
    var stroke_dash: Optional[StrokeDash]
    var corner_radius: Optional[Float64]
    var text_color: Optional[Color]
    var font: Optional[Font]
    var font_size: Optional[Float64]
    var font_weight: Optional[FontWeight]
    var font_italic: Optional[Bool]
    var text_alignment: Optional[Align]
    var tint: Optional[Color]
    var opacity: Optional[Float64]
    var blend_mode: Optional[BlendMode]
    var shadow: Optional[Color]
    var shadow_offset: Optional[Vector]
    var shadow_blur: Optional[Float64]
    var shadow_spread: Optional[Float64]
    var shadow_inset: Optional[Bool]
    var shadow_follows_transform: Optional[Bool]
    var shadow_enabled: Optional[Bool]

    def __init__(
        out self,
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
    ):
        self.fill = fill
        self.fill_gradient = fill_gradient
        self.fill_enabled = fill_enabled
        self.stroke = stroke
        self.stroke_thickness = stroke_thickness._value
        self.stroke_enabled = stroke_enabled
        self.stroke_alignment = stroke_alignment
        self.stroke_cap = stroke_cap
        self.stroke_dash = stroke_dash
        self.corner_radius = corner_radius._value
        self.text_color = text_color
        self.font = font
        self.font_size = font_size._value
        self.font_weight = font_weight
        self.font_italic = font_italic
        self.text_alignment = text_alignment
        self.tint = tint
        self.opacity = opacity._value
        self.blend_mode = blend_mode
        self.shadow = shadow
        self.shadow_offset = shadow_offset
        self.shadow_blur = shadow_blur._value
        self.shadow_spread = shadow_spread._value
        self.shadow_inset = shadow_inset
        self.shadow_follows_transform = shadow_follows_transform
        self.shadow_enabled = shadow_enabled

    def over(self, base: Style) -> Style:
        """This style layered over `base`: each part this style sets, and
        `base`'s for the rest. Applying the result is applying `base` and
        then this style, so a part named here switches on what `base`
        switched off: `Style(stroke=Color.RED).over(Style(stroke_enabled=False))`
        is stroked.

        ```mojo
        var card = Style(fill=Color.WHITE, corner_radius=12)
        var square = Style(corner_radius=0).over(card)  # white, square
        ```
        """
        var layered = base.copy()
        if self.fill:
            layered.fill = self.fill
        if self.fill_gradient:
            layered.fill_gradient = self.fill_gradient
        if self.fill_enabled:
            layered.fill_enabled = self.fill_enabled
        if self.stroke:
            layered.stroke = self.stroke
        if self.stroke_thickness:
            layered.stroke_thickness = self.stroke_thickness
        if self.stroke_enabled:
            layered.stroke_enabled = self.stroke_enabled
        if self.stroke_alignment:
            layered.stroke_alignment = self.stroke_alignment
        if self.stroke_cap:
            layered.stroke_cap = self.stroke_cap
        if self.stroke_dash:
            layered.stroke_dash = self.stroke_dash
        if self.corner_radius:
            layered.corner_radius = self.corner_radius
        if self.text_color:
            layered.text_color = self.text_color
        if self.font:
            layered.font = self.font
        if self.font_size:
            layered.font_size = self.font_size
        if self.font_weight:
            layered.font_weight = self.font_weight
        if self.font_italic:
            layered.font_italic = self.font_italic
        if self.text_alignment:
            layered.text_alignment = self.text_alignment
        if self.tint:
            layered.tint = self.tint
        if self.opacity:
            layered.opacity = self.opacity
        if self.blend_mode:
            layered.blend_mode = self.blend_mode
        if self.shadow:
            layered.shadow = self.shadow
        if self.shadow_offset:
            layered.shadow_offset = self.shadow_offset
        if self.shadow_blur:
            layered.shadow_blur = self.shadow_blur
        if self.shadow_spread:
            layered.shadow_spread = self.shadow_spread
        if self.shadow_inset:
            layered.shadow_inset = self.shadow_inset
        if self.shadow_follows_transform:
            layered.shadow_follows_transform = self.shadow_follows_transform
        if self.shadow_enabled:
            layered.shadow_enabled = self.shadow_enabled
        # What applying this style after `base` would undo: a fill colour
        # clears the gradient, and naming a part switches it back on.
        if self.fill and not self.fill_gradient:
            layered.fill_gradient = None
        if (self.fill or self.fill_gradient) and not self.fill_enabled:
            layered.fill_enabled = None
        if (self.stroke or self.stroke_thickness) and not self.stroke_enabled:
            layered.stroke_enabled = None
        if (
            self.shadow
            or self.shadow_offset
            or self.shadow_blur
            or self.shadow_spread
            or self.shadow_inset
        ) and not self.shadow_enabled:
            layered.shadow_enabled = None
        return layered^

    def write_to[W: Writer](self, mut writer: W):
        # Only the parts that are set, by the constructor's keywords, so the
        # output reads back as the same `Style(...)` call.
        writer.write("Style(")
        var first = True
        if self.fill:
            writer.write("" if first else ", ", "fill=", self.fill.value())
            first = False
        if self.fill_gradient:
            writer.write(
                "" if first else ", ",
                "fill_gradient=",
                self.fill_gradient.value(),
            )
            first = False
        if self.fill_enabled:
            writer.write(
                "" if first else ", ",
                "fill_enabled=",
                self.fill_enabled.value(),
            )
            first = False
        if self.stroke:
            writer.write("" if first else ", ", "stroke=", self.stroke.value())
            first = False
        if self.stroke_thickness:
            writer.write(
                "" if first else ", ",
                "stroke_thickness=",
                self.stroke_thickness.value(),
            )
            first = False
        if self.stroke_enabled:
            writer.write(
                "" if first else ", ",
                "stroke_enabled=",
                self.stroke_enabled.value(),
            )
            first = False
        if self.stroke_alignment:
            writer.write(
                "" if first else ", ",
                "stroke_alignment=",
                self.stroke_alignment.value(),
            )
            first = False
        if self.stroke_cap:
            writer.write(
                "" if first else ", ", "stroke_cap=", self.stroke_cap.value()
            )
            first = False
        if self.stroke_dash:
            writer.write(
                "" if first else ", ", "stroke_dash=", self.stroke_dash.value()
            )
            first = False
        if self.corner_radius:
            writer.write(
                "" if first else ", ",
                "corner_radius=",
                self.corner_radius.value(),
            )
            first = False
        if self.text_color:
            writer.write(
                "" if first else ", ", "text_color=", self.text_color.value()
            )
            first = False
        if self.font:
            writer.write("" if first else ", ", "font=", self.font.value())
            first = False
        if self.font_size:
            writer.write(
                "" if first else ", ", "font_size=", self.font_size.value()
            )
            first = False
        if self.font_weight:
            writer.write(
                "" if first else ", ", "font_weight=", self.font_weight.value()
            )
            first = False
        if self.font_italic:
            writer.write(
                "" if first else ", ", "font_italic=", self.font_italic.value()
            )
            first = False
        if self.text_alignment:
            writer.write(
                "" if first else ", ",
                "text_alignment=",
                self.text_alignment.value(),
            )
            first = False
        if self.tint:
            writer.write("" if first else ", ", "tint=", self.tint.value())
            first = False
        if self.opacity:
            writer.write(
                "" if first else ", ", "opacity=", self.opacity.value()
            )
            first = False
        if self.blend_mode:
            writer.write(
                "" if first else ", ", "blend_mode=", self.blend_mode.value()
            )
            first = False
        if self.shadow:
            writer.write("" if first else ", ", "shadow=", self.shadow.value())
            first = False
        if self.shadow_offset:
            writer.write(
                "" if first else ", ",
                "shadow_offset=",
                self.shadow_offset.value(),
            )
            first = False
        if self.shadow_blur:
            writer.write(
                "" if first else ", ", "shadow_blur=", self.shadow_blur.value()
            )
            first = False
        if self.shadow_spread:
            writer.write(
                "" if first else ", ",
                "shadow_spread=",
                self.shadow_spread.value(),
            )
            first = False
        if self.shadow_inset:
            writer.write(
                "" if first else ", ",
                "shadow_inset=",
                self.shadow_inset.value(),
            )
            first = False
        if self.shadow_follows_transform:
            writer.write(
                "" if first else ", ",
                "shadow_follows_transform=",
                self.shadow_follows_transform.value(),
            )
            first = False
        if self.shadow_enabled:
            writer.write(
                "" if first else ", ",
                "shadow_enabled=",
                self.shadow_enabled.value(),
            )
        writer.write(")")

    def _resolved(self) -> _ResolvedStyle:
        """This style applied to a fresh frame's: every part decided."""
        var resolved = _ResolvedStyle()
        resolved.apply(self)
        return resolved^


struct _ResolvedStyle(Copyable, ImplicitlyCopyable, Movable):
    """A style with every part decided: what the canvas holds and draws with.

    A `Style` is resolved into one when it is applied. Its constructor takes
    the same keywords as `Style`'s, with the same defaults, so the library
    builds the looks it draws with directly.
    """

    var fill_color: Color
    var fill_gradient: Optional[Gradient]
    """Paints the fill instead of `fill_color` while set; `fill_color` is
    kept for when it is cleared."""
    var fill_enabled: Bool
    var stroke_color: Color
    var stroke_thickness: Float64
    var stroke_enabled: Bool
    var stroke_alignment: StrokeAlign
    """Where a region's stroke sits against its edge; `INSIDE` unless
    set. Lines and curves are always stroked centred."""
    var stroke_cap: StrokeCap
    """How the open ends of lines and curves are finished; `BUTT` unless
    set. Regions' strokes and closed curves have no ends, unless dashed."""
    var stroke_dash: StrokeDash
    """How the stroke is broken into dashes; `SOLID` unless set."""
    var corner_radius: Float64
    """How far the shapes the canvas builds from numbers are rounded, in
    world units; 0 is sharp. A shape value keeps its own."""
    var text_color: Color
    var font: Optional[Font]
    """The face text is drawn in; none for the packaged Noto Sans."""
    var font_size: Float64
    var font_weight: FontWeight
    var font_italic: Bool
    var text_alignment: Align
    var tint: Color
    var opacity: Float64
    var blend_mode: BlendMode
    var shadow_color: Color
    var shadow_offset: Vector
    var shadow_blur: Float64
    var shadow_spread: Float64
    var shadow_inset: Bool
    var shadow_follows_transform: Bool
    var shadow_enabled: Bool

    def __init__(
        out self,
        *,
        fill: Optional[Color] = None,
        fill_gradient: Optional[Gradient] = None,
        fill_enabled: Optional[Bool] = None,
        stroke: Optional[Color] = None,
        stroke_thickness: OptionalNumber = None,
        stroke_enabled: Optional[Bool] = None,
        stroke_alignment: StrokeAlign = StrokeAlign.INSIDE,
        stroke_cap: StrokeCap = StrokeCap.BUTT,
        stroke_dash: StrokeDash = StrokeDash.SOLID,
        corner_radius: OptionalNumber = None,
        text_color: Color = Color.BLACK,
        font: Optional[Font] = None,
        font_size: OptionalNumber = None,
        font_weight: FontWeight = FontWeight.REGULAR,
        font_italic: Bool = False,
        text_alignment: Align = Align.CENTER,
        tint: Color = Color.WHITE,
        opacity: OptionalNumber = None,
        blend_mode: BlendMode = BlendMode.NORMAL,
        shadow: Optional[Color] = None,
        shadow_offset: Optional[Vector] = None,
        shadow_blur: OptionalNumber = None,
        shadow_spread: OptionalNumber = None,
        shadow_inset: Optional[Bool] = None,
        shadow_follows_transform: Bool = False,
        shadow_enabled: Optional[Bool] = None,
    ):
        self.fill_color = fill.or_else(Color.WHITE)
        self.fill_gradient = fill_gradient
        self.fill_enabled = fill_enabled.or_else(
            Bool(fill) or Bool(fill_gradient)
        )
        self.stroke_color = stroke.or_else(Color.BLACK)
        self.stroke_thickness = stroke_thickness.or_else(1.0)
        self.stroke_enabled = stroke_enabled.or_else(True)
        self.stroke_alignment = stroke_alignment
        self.stroke_cap = stroke_cap
        self.stroke_dash = stroke_dash
        self.corner_radius = corner_radius.or_else(0.0)
        self.text_color = text_color
        self.font = font
        self.font_size = font_size.or_else(16.0)
        self.font_weight = font_weight
        self.font_italic = font_italic
        self.text_alignment = text_alignment
        self.tint = tint
        self.opacity = opacity.or_else(1.0)
        self.blend_mode = blend_mode
        self.shadow_color = shadow.or_else(Color(0, 0, 0, 96))
        self.shadow_offset = shadow_offset.or_else(Vector(4, -4))
        self.shadow_blur = shadow_blur.or_else(8.0)
        self.shadow_spread = shadow_spread.or_else(0.0)
        self.shadow_inset = shadow_inset.or_else(False)
        self.shadow_follows_transform = shadow_follows_transform
        self.shadow_enabled = shadow_enabled.or_else(
            Bool(shadow)
            or Bool(shadow_offset)
            or Bool(shadow_blur)
            or Bool(shadow_spread)
            or Bool(shadow_inset)
        )

    def apply(mut self, style: Style):
        """Apply `style`'s parts to this style, as the canvas setters of
        the same names would apply them, in this order: a gradient after
        the fill colour, so given both the gradient paints, and each
        `*_enabled` after the parts it switches, so an explicit `False`
        wins."""
        if style.fill:
            self.fill_color = style.fill.value()
            self.fill_gradient = None
            self.fill_enabled = True
        if style.fill_gradient:
            self.fill_gradient = style.fill_gradient
            self.fill_enabled = True
        if style.stroke:
            self.stroke_color = style.stroke.value()
            self.stroke_enabled = True
        if style.stroke_thickness:
            self.stroke_thickness = style.stroke_thickness.value()
            self.stroke_enabled = True
        if style.fill_enabled:
            self.fill_enabled = style.fill_enabled.value()
        if style.stroke_enabled:
            self.stroke_enabled = style.stroke_enabled.value()
        if style.stroke_alignment:
            self.stroke_alignment = style.stroke_alignment.value()
        if style.stroke_cap:
            self.stroke_cap = style.stroke_cap.value()
        if style.stroke_dash:
            self.stroke_dash = style.stroke_dash.value()
        if style.corner_radius:
            self.corner_radius = style.corner_radius.value()
        if style.text_color:
            self.text_color = style.text_color.value()
        if style.font:
            self.font = style.font
        if style.font_size:
            self.font_size = style.font_size.value()
        if style.font_weight:
            self.font_weight = style.font_weight.value()
        if style.font_italic:
            self.font_italic = style.font_italic.value()
        if style.text_alignment:
            self.text_alignment = style.text_alignment.value()
        if style.tint:
            self.tint = style.tint.value()
        if style.opacity:
            self.opacity = style.opacity.value()
        if style.blend_mode:
            self.blend_mode = style.blend_mode.value()
        if style.shadow:
            self.shadow_color = style.shadow.value()
            self.shadow_enabled = True
        if style.shadow_offset:
            self.shadow_offset = style.shadow_offset.value()
            self.shadow_enabled = True
        if style.shadow_blur:
            self.shadow_blur = style.shadow_blur.value()
            self.shadow_enabled = True
        if style.shadow_spread:
            self.shadow_spread = style.shadow_spread.value()
            self.shadow_enabled = True
        if style.shadow_inset:
            self.shadow_inset = style.shadow_inset.value()
            self.shadow_enabled = True
        if style.shadow_follows_transform:
            self.shadow_follows_transform = (
                style.shadow_follows_transform.value()
            )
        if style.shadow_enabled:
            self.shadow_enabled = style.shadow_enabled.value()

    def _paint(self) -> Paint:
        """What a command recorded in this style paints with: a dash preset
        resolved against the thickness, and `DOTTED`'s dots round."""
        var cap = self.stroke_cap
        if self.stroke_dash._is_dotted():
            cap = StrokeCap.ROUND
        return Paint(
            fill_color=self.fill_color,
            fill_gradient=self.fill_gradient,
            fill_enabled=self.fill_enabled,
            stroke_color=self.stroke_color,
            stroke_thickness=self.stroke_thickness,
            stroke_enabled=self.stroke_enabled,
            stroke_alignment=self.stroke_alignment,
            stroke_cap=cap,
            stroke_dash=self.stroke_dash._resolved(self.stroke_thickness),
            blend_mode=self.blend_mode,
            shadow_color=self.shadow_color,
            shadow_offset=self.shadow_offset,
            shadow_blur=self.shadow_blur,
            shadow_spread=self.shadow_spread,
            shadow_inset=self.shadow_inset,
            shadow_follows_transform=self.shadow_follows_transform,
            shadow_enabled=self.shadow_enabled,
        )

    def _text_style(self) -> TextStyle:
        """How text recorded or measured in this style is set."""
        return TextStyle(
            font=self.font,
            font_size=self.font_size,
            font_weight=self.font_weight,
            font_italic=self.font_italic,
            text_alignment=self.text_alignment,
            text_color=self.text_color,
        )
