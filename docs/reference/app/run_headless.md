# run_headless

```mojo
def run_headless[P: Program](
    width: Int,
    height: Int,
    frames: Int = Int(1),
    window_size: Optional[Tuple[Int, Int]] = None,
    backend: RenderBackend = RenderBackend.CPU,
    antialiasing: Antialiasing = Antialiasing.MEDIUM,
    autoscale: Autoscale = Autoscale.FIT,
) raises -> Image
```

Run `P` without a window (`create`'s frame, then `frames` calls to `update`), and return the last frame as an `Image`, read back with `pixel(x, y)` in image coordinates (top-left origin, y down).

The same sequence as `run`, minus the window: `create` draws frame 1,
then `update` draws one frame per call, with the letterbox painted after
each. `frames=0` returns `create`'s frame alone. `width`
and `height` are the design size; `window_size` is the pixel size of
the window it stands in for, the design size when `None`: pass a
different shape to exercise autoscale, since a design that matches the
window maps 1:1 and leaves no bars. The returned image is that size.

Time is synthetic and the input is empty, so the result depends only on
the program. A program that feeds `context.keyboard` or `context.mouse`
itself (a test pressing keys) gets the windowed loops' frame boundaries: a press,
release or typed text lasts the frame it was fed in, while a key held
down stays down.

`backend=RenderBackend.GPU` runs the same frames through the GL backend
into an offscreen framebuffer instead, reading the result back at the
end rather than replaying onto the buffer every frame: see
`_headless_gl.mojo`. It raises if no GL context can be created; it never
falls back to the CPU backend.

`antialiasing` is `run`'s, with the same default, and reaches both
backends as it does in a window.

`autoscale` is `run`'s too: how the design maps onto the framebuffer.
