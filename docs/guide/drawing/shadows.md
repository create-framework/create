# Shadows

A shadow makes a shape look lifted off the screen, by drawing a darkened copy of its silhouette
behind it, offset and softened. An inset shadow does the opposite, darkening the inside of a shape
along its edge so that it looks pressed in. This page explains how to switch shadows on and
shape them.

## Switching a shadow on

Shadows are part of the style, and **off by default**. `canvas.shadow(color=, offset=, blur=,
spread=, inset=)` switches one on. Parts you leave unset keep their values, so `shadow()` alone
switches the last shadow back on. `shadow_enabled(False)` switches it off again. `canvas.style(...)`
takes the same parts as keywords starting with `shadow`, with `shadow=` for the colour:

```mojo
# In `update`:
with canvas.style(shadow=Color(0, 0, 0, 120), shadow_blur=12):
    canvas.rectangle((0, 0), 200, 120)
```

A translucent black, as here, gives the most natural shadow: it darkens whatever is behind it
rather than covering it.

## What casts a shadow

A render call casts **one silhouette**, as CSS's `drop-shadow` does. A shape's fill and stroke
cast it together, and a stroke alone casts a ring. Lines and arcs cast their stroke, text casts
its letters, and an image casts the shape of its opaque pixels. A translucent fill shows its own
shadow through it. The frame's clear, the background and the letterbox never cast a shadow.

## Shaping a shadow

- **The offset** is how far the shadow sits from its shape, `(4, -4)` by default: down and to the
  right. It is fixed to the screen, so rotating a shape doesn't turn its shadow's offset, as if the
  light always came from the same place; camera zoom and autoscale still scale it.
  `shadow_follows_transform(True)` makes the offset turn with the shape instead.
- **`blur`** softens the shadow's edge. It is roughly how far the fade from shadow to nothing
  reaches, as CSS's blur radius is, and a blur of 0 gives a hard edge.
- **`spread`** grows the shadow's shape before it is blurred, so it reaches out further on every
  side.

`blur` and `spread` are in units, so they scale like coordinates.

## Inset shadows

`inset=True` (`shadow_inset=True` in `canvas.style`) paints the shadow inside the shape instead,
after the shape itself, clipped to the inside of the stroke. It works on rectangles, circles and
triangles only; sectors, polygons, lines, arcs, text and images cast nothing while it is set.

## Shadows and the rest of the style

A shadow uses the render call's own tint, opacity and blend mode (see
[Style](style.md#tint-opacity-and-blend-modes)). A gradient fill doesn't change the shadow, which
is always the silhouette in the shadow's colour.
