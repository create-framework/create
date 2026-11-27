# Animation

```mojo
struct Animation
```

An ordered sequence of frames and the rate they play at.

An `Animation` is the asset, not the playhead: it holds the frames
and how fast they are meant to run, and never mutates. `Animator`
walks it. The rate lives here because it is a property of the artwork: a
run cycle and an idle cycle are rendered for different speeds.

Frames are cut into owned `Image`s at construction, so a sheet or a folder
is paid for once and every render afterwards is a plain blit.

Copying one is cheap, like copying an `Image`: the copies share the
frames, so several animators can hold the same animation.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`.

## Fields

- `fps: Float64`

## Constructors

```mojo
@staticmethod
def __init__(out self, var frames: List[Image], fps: Float64 = 12) raises
```

Build an animation from frames already in memory.

Raises on an empty frame list: an animation with no frames has no valid
frame index, so every consumer would have to guard against it.

### `from_sheet`

```mojo
@staticmethod
def from_sheet(
    sheet: Image,
    frame_width: Int,
    frame_height: Int,
    start: Int = Int(0),
    count: Int = Int(0),
    fps: Float64 = 12,
) raises -> Self
```

Cut frames out of a sprite sheet, left to right then top to bottom.

Cells are numbered row-major from zero, so one sheet holding idle on
row 0 and run on row 1 yields two animations without a sheet type:

```mojo
var idle = Animation.from_sheet(sheet, 32, 32, start=0, count=4)
var run = Animation.from_sheet(sheet, 32, 32, start=4, count=6)
```

`count = 0` means every remaining cell. Raises when the sheet is not a
whole number of cells wide or tall, or when the window runs past the
last cell: a silently truncated animation is harder to notice than a
failed load.

### `from_folder`

```mojo
@staticmethod
def from_folder(path: String, fps: Float64 = 12) raises -> Self
```

Load every image in a directory as a frame, in natural number order.

```mojo
var run = Animation.from_folder("assets/run")
```

A relative `path` is resolved against the directory of the calling
source file, as `Image.load`'s is.

Names are ordered by the number they end in, not by string comparison,
so `frame_2` comes before `frame_10`: the ordering an author means
and the one zero-padding is usually a workaround for. Files that are
not BMP, PNG or JPEG are skipped; a directory with no images at all
raises rather than yielding an empty animation.

## Methods

### `frame_count`

```mojo
def frame_count(self) -> Int
```

The number of frames.

### `frame`

```mojo
def frame(self, index: Int) -> Image
```

Frame `index`, from 0 to `frame_count() - 1`. Cheap: an `Image` copy shares its pixels.

### `frame_duration`

```mojo
def frame_duration(self) -> Float64
```

Seconds each frame is held.
