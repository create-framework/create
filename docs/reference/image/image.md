# Image

```mojo
struct Image
```

An RGBA image, row-major, 8 bits per channel: an asset, never changed once made.

Decoded once at load — `Image.load` picks a BMP, PNG or JPEG decoder by
file extension — and blitted many times afterwards. `Image(buffer^)`
takes over the pixels of a `PixelBuffer`, the way to build one pixel by
pixel; `Image.solid` and `Image.from_rgba` build one without a file, and
`resize` returns a resampled copy. `pixel` reads one pixel. Since nothing
changes an image, a backend's cached copy of one is never stale.

Deliberately not a render type: `raster.blit_image` takes a pixel pointer
with a width and a height rather than this struct, so the image decoders
stay out of the render path and the rasteriser is written against no layout
but its own.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, var pixels: PixelBuffer) raises
```

An image of `pixels`, which it takes over without copying.

### `solid`

```mojo
@staticmethod
def solid(width: Int, height: Int, color: Color) raises -> Self
```

A `width` x `height` image every pixel of which is `color`.

### `from_rgba`

```mojo
@staticmethod
def from_rgba(width: Int, height: Int, data: List[UInt8]) raises -> Self
```

A `width` x `height` image of `data`: RGBA bytes, row by row from the top-left corner. Bytes past `width * height * 4` are ignored.

Raises if either dimension is negative or `data` is too short.

### `load`

```mojo
@staticmethod
def load(path: String) raises -> Self
```

Load an image file. Supports BMP, PNG, and JPEG.

A relative `path` is resolved against the directory of the calling
source file, not the working directory, so
`Image.load("assets/hero.png")` finds the file beside the program
wherever it is run from.

## Methods

### `width`

```mojo
def width(self) -> Int
```

The image's width in pixels.

### `height`

```mojo
def height(self) -> Int
```

The image's height in pixels.

### `pixel`

```mojo
def pixel(self, x: Int, y: Int) -> Color
```

The pixel in column `x` of row `y`, counted from the top-left corner — image coordinates, unlike the canvas's. Outside the image it is `Color.TRANSPARENT`.

### `resize`

```mojo
def resize(self, width: Int, height: Int) raises -> Self
```

A copy of this image at `width` x `height`, nearest-neighbour sampled. This image is unchanged; the copy is a new image, with its own identity.
