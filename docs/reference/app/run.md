# run

```mojo
def run[P: Program](
    title: String,
    mode: WindowMode = WindowMode.WINDOWED,
    width: Int = Int(1280),
    height: Int = Int(720),
    backend: RenderBackend = RenderBackend.CPU,
    resizable: Bool = True,
    antialiasing: Antialiasing = Antialiasing.MEDIUM,
    autoscale: Autoscale = Autoscale.FIT,
) raises
```

Open a window and run `P` in it until it quits.

`width`/`height` are the design size: the space the program is
**authored** in, and the one `canvas.width()`/`height()`, the canvas edges and
`context.mouse.position` are reported in. They are not a window size that happens to double as one: a
`WINDOWED` or `BORDERLESS` launch opens a window of that size because the
two coincide there, while `FULLSCREEN` and `MAXIMIZED` take the display or
its work area and the design is scaled onto it. `mode=FULLSCREEN` with a
size therefore means *author at that size, present fullscreen*.

The scaling is `autoscale`, `Autoscale.FIT` by default, so a program keeps
its layout on any display:

| call                                          | FIT / EXTEND             | OFF            |
|-----------------------------------------------|--------------------------|----------------|
| `run("T", width=1000, height=1000)`           | design 1000x1000, scaled | world = window |
| `run("T", FULLSCREEN, width=1000, height=1000)`| design 1000x1000, scaled | world = monitor|
| `run("T", WindowMode.FULLSCREEN)`             | design 1280x720, scaled  | world = monitor|

`Autoscale.OFF` is the opt-out, and the only way the size here stops
meaning anything: the design size goes unused and coordinates become
the window's own pixels, which is how a program authors against the
display rather than against a fixed space. `context.autoscale(mode)`
switches it later in the run.

`context.design_size(w, h)` pins the same space from inside `create`, which
is where a program with an opinion of its own states it. The size here is
the shorthand for the common case where the window and the design agree.

`backend=RenderBackend.GPU` runs the same program through the GL backend
instead — a different window, a different loop, and the same frame. It is
a branch, taken once, rather than a value the loop holds, because Mojo
has no dynamic trait dispatch: each loop calls its own replay directly.

`antialiasing` smooths the edges of shapes on either backend
(`Antialiasing.MEDIUM` by default, `OFF` for hard pixels). See
`Antialiasing`.
