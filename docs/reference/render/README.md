# create.render

Drawing: `Canvas` and its `with`-block guards, `Style`, `Camera`, and the settings that shape a frame (`Antialiasing`, `Autoscale`, `Align`, `StrokeCap`, `StrokeDash`, `StrokeAlign`, `RenderBackend`).

## Types

| Type | Description |
|---|---|
| [`RenderBackend`](renderbackend.md) | Which renderer draws a run's frames: `run`'s and `run_headless`'s `backend`. |
| [`Antialiasing`](antialiasing.md) | How smoothly the edges of shapes are drawn. |
| [`Align`](align.md) | Which point of a box a position names — one value for both axes. |
| [`StrokeAlign`](strokealign.md) | Where a region's stroke sits against the shape's edge. |
| [`StrokeCap`](strokecap.md) | How the two open ends of a stroked line or curve are finished. |
| [`StrokeDash`](strokedash.md) | How a stroke is broken into dashes along its length. |
| [`Autoscale`](autoscale.md) | How the program's design size maps onto the window. |
| [`Style`](style.md) | How the next shape or glyph is painted, independent of where it goes. |
| [`Camera`](camera.md) | What part of world space maps onto the screen. |
| [`Canvas`](canvas.md) | One frame: the geometry and the rendering API. |
| [`StyleGuard`](styleguard.md) | Restores the style the frame had when the scope was entered. |
| [`TransformGuard`](transformguard.md) | Pops the matrix `canvas.transform` pushed, on scope exit. |
| [`OverlayGuard`](overlayguard.md) | Restores the camera and transform `canvas.overlay` suspended, on scope exit. Only `canvas.overlay` builds one. |
| [`ClipGuard`](clipguard.md) | Closes the clip `canvas.clip` opened, on scope exit. Only `canvas.clip` builds one. |
