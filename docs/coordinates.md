# Coordinates, camera and autoscale

**Not Processing's coordinates.** Origin at the screen centre, **y up**; `x ∈ [-w/2, w/2]`,
`y ∈ [-h/2, h/2]`. So `rotate` is counter-clockwise, gravity is negative `y`, and `canvas.left()`/
`bottom()` are negative — use the edge methods, not `width`/`height` arithmetic. `canvas.width()`/
`height()` are `Float64` units (under `EXTEND` the window's pixels divide out to a fraction), and
`canvas.bounds()` is the screen as a `Rectangle`, for `snapshot`, `clip` or `contains`. Glyphs and images
are not flipped by the y-up axis, but turn, shear and mirror with `canvas.transform` like every
render call. **All shapes are centre-positioned**, including `Rectangle.position`.

**Camera:** `canvas.camera(camera)` maps world space onto screen space for every later render call and
nested transform, reset every frame. `canvas.overlay()` suspends it for HUD content.
`context.mouse.position` is in screen space; `canvas.to_local(context.mouse.position)` picks in the frame a
shape is drawn in, camera and transform included, and `camera.to_world(context.mouse.position)` gives
the world position.

```mojo
canvas.camera(self.camera)
canvas.image(self.player.image, self.player.position)       # world space
with canvas.overlay():
    canvas.text("Score: " + String(self.score), (0, canvas.top() - 20))  # screen space
```

**Design size** is the `width`/`height` passed to `run` (or `context.design_size(w, h)` later): the
space the program is authored in, not a window size. Fullscreen/maximized scale the design onto the
display. `run(..., autoscale=)` (or `context.autoscale(mode)` later) takes `FIT` (default),
`EXTEND` or `OFF`; `OFF` makes coordinates the window's own pixels. Both decide frame 1's mapping
only as `run` arguments: the viewport is derived before `create`. Under `EXTEND` the reported size
grows with the window, so anchor layout to the edges. Font size, stroke thickness and image size
scale by `canvas.scale()`. See [examples/window/main.mojo](../examples/window/main.mojo).

`Context` dials are the run's, not the drawing's: `design_size`, `autoscale`, `title`,
`window_mode`, `resizable`, `cursor`, `lock_mouse`, `text_input`, `quit_on_escape`, `max_frame_rate`.
They are methods
(`context.autoscale(Autoscale.EXTEND)`, like the canvas setters), each read back with no arguments;
`Context`'s only fields are the readings: `time`, `keyboard` and `mouse` (the gamepads are
`context.gamepad(player)`, a copy, since there can be several). Every `run` argument but `backend`
has a setter — a dial here, or `canvas.antialiasing` — and the argument is only the starting value.
Not every dial is a `run` argument: `cursor`, `quit_on_escape` and `max_frame_rate` are set in
`create`.

**Cursor:** `context.cursor(Cursor.CROSSHAIR)` is Processing's `cursor(CROSS)`, and
`Cursor.HIDDEN` its `noCursor()`; any other value shows the cursor again. Each `Cursor` is the
platform's own system cursor (`ARROW` by default, `CROSSHAIR`, `HAND`, `TEXT`, `WAIT`, `PROGRESS`,
`MOVE`, `NOT_ALLOWED`, and four resize ones, the diagonals named by slope: `RISING` is `/`). Sent
only when it changes, so setting it every frame from a hover test is free. Image cursors are not
supported.

**When a change applies:** a frame-wide setting applies to the frame it is set in — the canvas
ones above, and `title`/`resizable`/`cursor`/`lock_mouse`/`text_input`, which the windowed loops send
before presenting. What
decides the frame's geometry waits for the next frame: `design_size`, `autoscale` and
`window_mode` (switched after presenting; some compositors report the new size a frame later). A
getter reports the value as set. `max_frame_rate()`, `quit()` and `rumble()` are read after the
frame body returns. Headless runs ignore the window dials, like `rumble`.
