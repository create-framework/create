# create.color

Colours: `Color` and `BlendMode`, and the colour schemes that name colours by what they are for: `ColorScheme`, `ColorRole` and `OptionalColor`.

## Types

| Type | Description |
|---|---|
| [`Color`](color.md) | A colour: red, green and blue, each from 0 to 255, and an alpha from 0 (invisible) to 255 (opaque, the default). |
| [`BlendMode`](blendmode.md) | How a shape, glyph or image combines with what is already rendered. |
| [`ColorScheme`](colorscheme.md) | The colours widgets are drawn in, as pairs of roles: each colour a widget is filled with, and the `on_` colour for text and icons drawn on it, chosen to read well together. A program gives its scheme to the canvas with `canvas.colors(scheme)`, which widgets are drawn in, and draws its own things in it too, such as `canvas.background(scheme.background)`. A style names a role with `ColorRole`, such as `Style(fill=ColorRole.PRIMARY)`, and `scheme[role]` is the colour the scheme gives it. |
| [`ColorRole`](colorrole.md) | A colour named by what it is for, such as `ColorRole.PRIMARY`, rather than by its channels: the colour scheme in use decides which colour it is. |
| [`OptionalColor`](optionalcolor.md) | A colour that may be left out: a `Color`, a `ColorRole` that the colour scheme turns into a colour, or `None`. |
