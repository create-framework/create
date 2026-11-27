"""`OptionalColor`, the type of `Style`'s colour keywords."""

from std.collections import Optional

from .color import Color
from .color_role import ColorRole
from .color_scheme import ColorScheme


struct OptionalColor(
    Boolable, Copyable, Equatable, ImplicitlyCopyable, Movable, Writable
):
    """A colour that may be left out: a `Color`, a `ColorRole` that the
    colour scheme turns into a colour, or `None`.

    It is the type of a style's colour keywords, such as `fill=`, `stroke=`
    and `text_color=`, so each of `fill=Color.RED`, `fill=ColorRole.PRIMARY`
    and `fill=None` works. A program passes a colour or a role and never
    names the type.

    `Optional[Color]` can't take the place of it: a role isn't a colour until
    a scheme says which, and a colour wouldn't become an `Optional` of
    anything wider in one step, since Mojo makes only one conversion.

    Read it as you would an `Optional`: it is true when a colour or a role
    was given. `resolve(scheme)` is the colour, with a role looked up in
    `scheme`; `role()` is the role, if one was given.
    """

    var _color: Optional[Color]
    var _role: Optional[ColorRole]

    @implicit
    def __init__(out self, color: Color):
        self._color = color
        self._role = None

    @implicit
    def __init__(out self, role: ColorRole):
        self._color = None
        self._role = role

    @implicit
    def __init__(out self, color: Optional[Color]):
        self._color = color
        self._role = None

    @implicit
    def __init__(out self, none: NoneType._mlir_type):
        self._color = None
        self._role = None

    def __bool__(self) -> Bool:
        """Whether a colour or a role was given."""
        return Bool(self._color) or Bool(self._role)

    def __eq__(self, other: OptionalColor) -> Bool:
        return self._color == other._color and self._role == other._role

    def __ne__(self, other: OptionalColor) -> Bool:
        return not self == other

    def role(self) -> Optional[ColorRole]:
        """The role given, or `None` when a colour, or nothing, was."""
        return self._role

    def resolve(self, scheme: ColorScheme) -> Color:
        """The colour: the one given, or `scheme`'s colour for the role
        given. Only call it when one of them was given."""
        if self._role:
            return scheme[self._role.value()]
        return self._color.value()

    def or_else(self, default: Color, scheme: ColorScheme) -> Color:
        """The colour, with a role looked up in `scheme`, or `default` when
        neither was given."""
        if self:
            return self.resolve(scheme)
        return default

    def write_to[W: Writer](self, mut writer: W):
        if self._role:
            writer.write(self._role.value())
        elif self._color:
            writer.write(self._color.value())
        else:
            writer.write("None")
