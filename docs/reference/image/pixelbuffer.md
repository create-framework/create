# PixelBuffer

```mojo
struct PixelBuffer
```

Pixels being built one at a time, to become an `Image`.

The mutable half of an image: `set` writes a pixel, `pixel` reads one
back, and `Image(buffer^)` takes the pixels over without copying them.
An `Image` is never changed after that, so this is where an image built
pixel by pixel is built.

Image coordinates, as `Image.pixel`: column `x` of row `y`, counted from
the top-left corner, y down, not the canvas's screen space. Off the
buffer, reads are transparent and writes do nothing. A new buffer is
transparent.

Implements `Deinitable`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, width: Int, height: Int)
```

## Methods

### `width`

```mojo
def width(self) -> Int
```

The buffer's width in pixels.

### `height`

```mojo
def height(self) -> Int
```

The buffer's height in pixels.

### `pixel`

```mojo
def pixel(self, x: Int, y: Int) -> Color
```

The pixel in column `x` of row `y`, counted from the top-left corner. Outside the buffer it is `Color.TRANSPARENT`.

### `set`

```mojo
def set(mut self, x: Int, y: Int, color: Color)
```

Replace the pixel in column `x` of row `y`, counted from the top-left corner. Outside the buffer it does nothing.
