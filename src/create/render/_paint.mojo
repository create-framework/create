"""What a recorded command paints with, resolved from the `Style` at record
time.

A `Style` is the program's: everything the next render call might use, text
and rounding included. A command needs only what its replay reads, so
`RenderCommand` keeps a `Paint` (fill, stroke, shadow, blend mode) and a text
command's payload a `TextStyle`. Tint and opacity are folded into the colours
when the command is built, so neither survives into either.
"""

from std.collections import Optional

from .align import Align
from .stroke_align import StrokeAlign
from .stroke_cap import StrokeCap
from create.color.blend_mode import BlendMode
from create.color.color import Color
from create.color.gradient import Gradient
from create.math.vector2d import Vector2D
from create.text.font import Font, FontWeight


@fieldwise_init
struct Paint(Copyable, ImplicitlyCopyable, Movable):
    """A command's fill, stroke, shadow and blend mode, named as on
    `Style`."""

    var fill_color: Color
    var fill_gradient: Optional[Gradient]
    """Paints the fill instead of `fill_color` while set."""
    var fill_enabled: Bool
    var stroke_color: Color
    var stroke_thickness: Float64
    var stroke_enabled: Bool
    var stroke_alignment: StrokeAlign
    var stroke_cap: StrokeCap
    var blend_mode: BlendMode
    var shadow_color: Color
    var shadow_offset: Vector2D
    var shadow_blur: Float64
    var shadow_spread: Float64
    var shadow_inset: Bool
    var shadow_follows_transform: Bool
    var shadow_enabled: Bool

    def _fill_visible(self) -> Bool:
        """Whether the fill actually paints anything.

        `fill_enabled` alone isn't enough — a fully transparent color, or a
        gradient whose every stop is, paints nothing either, and every
        rasteriser gate should skip that work rather than render an
        invisible fill.
        """
        if not self.fill_enabled:
            return False
        if self.fill_gradient:
            return self.fill_gradient.value()._visible()
        return self.fill_color.a > 0

    def _stroke_visible(self) -> Bool:
        """Whether the stroke actually paints anything.

        `stroke_enabled` alone isn't enough — a fully transparent color or a
        zero thickness paints nothing either, and every rasteriser gate
        should skip that work rather than render an invisible stroke.
        """
        return (
            self.stroke_enabled
            and self.stroke_color.a > 0
            and self.stroke_thickness > 0
        )

    def _shadow_visible(self) -> Bool:
        """Whether the shadow actually paints anything.

        Like `_fill_visible`: switched on and not fully transparent. Which
        kinds cast one (and which ignore `shadow_inset`) is the backends'
        call, not the paint's.
        """
        return self.shadow_enabled and self.shadow_color.a > 0


@fieldwise_init
struct TextStyle(Copyable, ImplicitlyCopyable, Movable):
    """How text is set and coloured: the face (none for the packaged Noto
    Sans), its size in world units, weight, slant, alignment and colour.
    What a text command carries and what `TextRenderer` lays out with."""

    var font: Optional[Font]
    var font_size: Float64
    var font_weight: FontWeight
    var font_italic: Bool
    var text_alignment: Align
    var text_color: Color
