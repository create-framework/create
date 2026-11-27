# OptionalColor

```mojo
struct OptionalColor
```

A colour that may be left out: a `Color`, a `ColorRole` that the colour scheme turns into a colour, or `None`.

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

Implements `Boolable`, `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, color: Color)
@staticmethod
def __init__(out self, role: ColorRole)
@staticmethod
def __init__(out self, color: Optional[Color])
@staticmethod
def __init__(out self, none: None)
```

## Methods

### `role`

```mojo
def role(self) -> Optional[ColorRole]
```

The role given, or `None` when a colour, or nothing, was.

### `resolve`

```mojo
def resolve(self, scheme: ColorScheme) -> Color
```

The colour: the one given, or `scheme`'s colour for the role given. Only call it when one of them was given.

### `or_else`

```mojo
def or_else(self, default: Color, scheme: ColorScheme) -> Color
```

The colour, with a role looked up in `scheme`, or `default` when neither was given.

## Special methods

### `__bool__`

```mojo
def __bool__(self) -> Bool
```

Whether a colour or a role was given.

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
