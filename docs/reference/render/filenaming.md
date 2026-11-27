# FileNaming

```mojo
struct FileNaming
```

How a capture's file is named from the path it is given.

| Naming | File |
|---|---|
| `EXACT` | The path as given, replacing a file already there |
| `NUMBERED` | A number added before the extension, `image-0001.png`, one more than the highest already in the folder |

`canvas.save_image`, `save_screenshot` and `start_recording` take it as
`naming=`. Given a path, they use it `EXACT` unless told otherwise; with
no path, they save `NUMBERED`, as `image`, `screenshot` or `recording`,
so a capture never replaces an earlier one:

```mojo
# In `update`:
canvas.save_image()  # image-0001.png, then image-0002.png, …
canvas.save_image("poster.png")  # poster.png, replaced each time
canvas.save_image("frames/frame.png", naming=FileNaming.NUMBERED)
```

A number has four digits, and more once it passes 9999. The first
numbered save to a name in a run looks in its folder for the highest
number already there, so a new run carries on after the last one rather
than starting again from 1. A type of its own, so a bare number never
passes for one.

Implements `Copyable`, `Deinitable`, `Equatable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Constants

- `EXACT = FileNaming(Int(0))`
- `NUMBERED = FileNaming(Int(1))`

## Fields

- `value: Int`

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Int)
```

## Special methods

### `__eq__`

```mojo
def __eq__(self, other: Self) -> Bool
```

### `__ne__`

```mojo
def __ne__(self, other: Self) -> Bool
```
