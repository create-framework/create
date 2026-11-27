# Picture

```mojo
struct Picture
```

An `Image` placed in the world, to draw with `canvas.draw`.

An `Image` is an asset: the pixels, loaded once and shared, with no place
of its own. A `Picture` is one place to draw it, centred on `position`
and stretched to `width` by `height`, so `canvas.draw(picture)` draws
what `canvas.image(image, position, width, height)` draws, tinted and
faded by the style's `tint` and `opacity`. As a value it can be kept in a
field and be one part of a `Drawable` of your own:

```mojo
@fieldwise_init
struct Card(Drawable):
    var frame: Rectangle
    var portrait: Picture

    def draw_to(self, mut canvas: Canvas):
        canvas.draw(self.frame)
        canvas.draw(self.portrait)
```

Copying a `Picture` shares its image's pixels, as copying the `Image`
does, so several pictures of one image cost nothing more.

Implements `Copyable`, `Deinitable`, `Drawable`, `Movable`.

## Fields

- `image: Image`: The image drawn.
- `position: Point`: Where its centre is.
- `width: Float64`: How wide it is drawn, in units.
- `height: Float64`: How tall it is drawn, in units.

## Constructors

```mojo
@staticmethod
def __init__(out self, image: Image, position: Point)
```

The image at its own size: one unit per image pixel, as `canvas.image(image, position)` draws it.

```mojo
@staticmethod
def __init__(out self, image: Image, position: Point, width: Number, height: Number)
```

The image stretched to `width` by `height`.

## Methods

### `bounds`

```mojo
def bounds(self) -> Rectangle
```

The rectangle it covers: `width` by `height`, centred on `position`.

### `move_to`

```mojo
def move_to(self, position: Point) -> Self
```

The picture centred on `position` instead; this one is unchanged.

### `translate`

```mojo
def translate(self, delta: Vector) -> Self
```

The picture moved by `delta`; this one is unchanged.

### `draw_to`

```mojo
def draw_to(self, mut canvas: Canvas)
```
