# Gradients

A gradient is a fill that blends smoothly from one colour to another, or through several: a sky
fading from deep blue to orange at the horizon, or a glow that fades out from its centre. This page
explains how to build one, how it fits each shape and how it combines with the rest of the style.

## Filling with a gradient

A `Gradient` fills regions and backgrounds: `canvas.fill(gradient)` and
`canvas.background(gradient)` work like their colour versions. Build a gradient once in `create` and
keep it as a field (or in a `Style`): building one does some work up front, and every drawing of it
then reuses that work:

```mojo
# In `create`, building the `sky` and `glow` fields:
var sky = Gradient.linear(Color(20, 30, 80), Color(250, 150, 90))  # top to bottom
var glow = Gradient.radial(Color.WHITE, Color.TRANSPARENT)

# In `update`:
canvas.background(self.sky)
with canvas.style(fill_gradient=self.glow, stroke_enabled=False):
    canvas.circle((0, 0), 80)
```

There are two kinds:

- A **linear** gradient changes along one direction, in straight bands, like the sky above.
- A **radial** gradient changes outwards from a centre, in rings, like the glow above.

## Stops

A gradient is a list of **stops**: colours placed at positions from 0, where the gradient starts, to
1, where it ends. Between two stops the colour blends from one to the other. Given colours alone, as
above, the stops are spread evenly; to place them yourself, give each a position:

```mojo
# In `create`, building the `sunset` field:
var sunset = Gradient.linear(
    [(0.0, Color.BLUE), (0.7, Color.PURPLE), (1.0, Color.ORANGE)]
)
```

Here the blue blends into purple over the first 70% of the way, and the purple into orange over the
rest.

## How a gradient fits a shape

**A gradient stretches to fit each shape it fills.** It is laid out across the shape's bounding box,
the smallest upright rectangle round the shape before any transform is applied. So it moves and
turns with the shape, and one gradient suits shapes of every size. A sector's box is that of its
whole circle.

- **A linear gradient** runs along its `direction`, a `Vector`, which is `Vector.DOWN` (top to
  bottom) unless you give another; only its direction matters, not its length. The gradient's 0
  lands on the box's corner furthest back along the direction, and its 1 on the corner furthest
  ahead, as in CSS, so the gradient covers the whole box.
- **A radial gradient** runs from its first stop at its `center` out to its last at the box's edges,
  so on a long box its rings are ellipses. `center` is measured across the box rather than in units:
  `(0, 0)` is the box's centre (the default), `(-1, -1)` its bottom-left corner and `(1, 1)` its
  top-right.
- A zero `direction`, or a box of no size, paints the first stop.
- A fade to `TRANSPARENT` stays clean, with no dark fringe.
- Gradients are dithered on both backends: they are given a faint, fine grain, which hides the steps
  a smooth blend can otherwise show.

## Gradients and the rest of the style

- In `Style` and `canvas.style`, the keyword is `fill_gradient=`, not `fill=`. Given `fill=` and
  `fill_gradient=` together, the gradient wins.
- While a gradient is set, it fills in place of the fill colour, which is kept. `fill(color)`
  removes the gradient, while `fill()` and `fill_enabled(...)` keep it.
- A gradient only fills. Strokes, lines, curves and text ignore it, and a shadow is still cast in
  the shadow's own colour, so a fill fading to transparent still casts a full shadow.
- `background(gradient)` spans the whole screen, from `left()` to `right()` and `bottom()` to
  `top()`, and ignores the camera.
