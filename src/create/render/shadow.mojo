from create.color.color import Color
from create.math.transform import Transform
from create.math.vector import Vector

from ._command import RenderCommand
from ._cpu_replay import CpuReplay, draw_shadow
from ._resources import Resources
from ._surface import Surface


comptime _DrawShadow = def(
    mut CpuReplay,
    mut Resources,
    Surface[MutUntrackedOrigin],
    RenderCommand,
    Float64,
    Transform,
    Bool,
) thin raises -> None
"""`draw_shadow`: paints a command's outer or inset shadow on the CPU."""


struct Shadow(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A shadow cast by what is rendered: a darkened copy of its silhouette,
    offset and softened, as CSS's `drop-shadow` is.

    Every part has a default, so `Shadow()` is a soft, translucent black
    shadow down and to the right. Set it with `canvas.shadow(...)`,
    `Style(shadow=)` or `canvas.style(shadow=)`:

    ```mojo
    with canvas.style(shadow=Shadow(Color(0, 0, 0, 120), blur=12)):
        canvas.rectangle((0, 0), 200, 120)
    ```

    `color` is the shadow's colour; a translucent black darkens what is
    behind it rather than covering it. `offset` is how far it sits from its
    shape, `(4, -4)`: down and to the right, since y is up. It is fixed to
    the screen unless `follows_transform`, which turns it with the shape.
    `blur` is how far the fade from shadow to nothing reaches, the CSS blur
    radius; 0 gives a hard edge. `spread` grows the silhouette before it is
    blurred. `blur`, `spread` and the offset are world units, scaled like a
    coordinate.

    `inset=True` paints the shadow inside the shape instead, over its fill
    and within its stroke, as if the shape were a hole cut in a surface.
    Only rectangles, circles and triangles take an inset shadow; other
    shapes, text and images cast none while it is set.
    """

    var color: Color
    var offset: Vector
    var blur: Float64
    var spread: Float64
    var inset: Bool
    var follows_transform: Bool
    var _draw: _DrawShadow
    """`draw_shadow`, carried by the shadow so that a program compiles the
    CPU replay's shadow code only if it makes a `Shadow`."""

    def __init__(
        out self,
        color: Color = Color(0, 0, 0, 96),
        *,
        offset: Vector = Vector(4, -4),
        blur: Float64 = 8.0,
        spread: Float64 = 0.0,
        inset: Bool = False,
        follows_transform: Bool = False,
    ):
        self.color = color
        self.offset = offset
        self.blur = blur
        self.spread = spread
        self.inset = inset
        self.follows_transform = follows_transform
        self._draw = draw_shadow

    def __eq__(self, other: Shadow) -> Bool:
        return (
            self.color == other.color
            and self.offset == other.offset
            and self.blur == other.blur
            and self.spread == other.spread
            and self.inset == other.inset
            and self.follows_transform == other.follows_transform
        )

    def __ne__(self, other: Shadow) -> Bool:
        return not self == other

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Shadow(",
            self.color,
            ", offset=",
            self.offset,
            ", blur=",
            self.blur,
            ", spread=",
            self.spread,
            ", inset=",
            self.inset,
            ", follows_transform=",
            self.follows_transform,
            ")",
        )
