# Font

```mojo
struct Font
```

A typeface loaded from a file: an asset, like an `Image`.

`Font.load(path)` opens it once; copies share the open face, so a font
is cheap to keep in a field, a `Style` or several of each. The face is
closed when the last copy goes. Size and weight are not part of a font:
they come from the style each time text is drawn.

Its italic is the `italic_path` file where one was given, otherwise the
font's own italic axis, otherwise its upright glyphs sheared.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constructors

### `load`

```mojo
@staticmethod
def load(path: String, italic_path: Optional[String] = None) raises -> Self
```

Open the face at `path`, and the italic at `italic_path` if given. Raises if either cannot be read as one.

A relative path is resolved against the directory of the calling
source file, not the working directory, as `Image.load`'s is.

## Methods

### `path`

```mojo
def path(self) -> String
```

The file it was loaded from.

### `italic_path`

```mojo
def italic_path(self) -> Optional[String]
```

The file its italic was loaded from, if it was given one.

### `has_glyph`

```mojo
def has_glyph(self, codepoint: Int) raises -> Bool
```

Whether this face can render `codepoint`.
