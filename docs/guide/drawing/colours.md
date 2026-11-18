# Colours

Every colour in Create is a `Color`: the fill, the stroke, text, shadows, the background and the
stops of a gradient. This page explains how a colour is made up, the ways to write one, and how to
mix and fade colours.

## Red, green, blue and alpha

A screen makes every colour it shows by mixing red, green and blue light, so a `Color` is three
numbers, one for each, from 0 (none of that light) to 255 (as much as possible). All three at 0 is
black, all three at 255 is white, and equal amounts of each make a grey. A fourth number, the
**alpha**, is how opaque the colour is, from 0 (invisible) to 255 (fully opaque). It is 255 when you
leave it out:

```mojo
# In `update`:
canvas.fill(Color(255, 128, 0))  # orange: full red, half green, no blue
canvas.fill(Color(255, 128, 0, 128))  # the same orange, half transparent
canvas.fill(Color(200))  # one number is a gray: Color(200, 200, 200)
```

A translucent colour lets what is behind it show through, blended with it by its alpha.

## Named colours

The common colours have names, so you don't need to remember their numbers: `BLACK`, `WHITE`,
`DARK_GRAY`, `GRAY`, `LIGHT_GRAY`, `RED`, `GREEN`, `BLUE`, `CYAN`, `MAGENTA`, `YELLOW`, `ORANGE`,
`PINK`, `PURPLE`, `BROWN`, and `TRANSPARENT`, which is invisible.

```mojo
canvas.fill(Color.RED)
canvas.fill(Color.RED.with_alpha(64))  # red, mostly transparent
```

`with_alpha(a)` gives the same colour at another opacity. Like every method of a value in Create, it
returns a new colour and leaves the one it was called on as it was.

## Hex codes

Design tools, colour pickers and web pages write colours as **hex codes**, such as `#336699`: a `#`
and then two hexadecimal digits each for red, green and blue. `Color.hex` reads them, so a colour
can be copied straight from one of those tools:

```mojo
canvas.fill(Color.hex("#336699"))
canvas.fill(Color.hex("#33669980"))  # two more digits are the alpha
canvas.fill(Color.hex("#369"))  # the short form: the same as #336699
canvas.fill(Color.hex(0x336699))  # a number written in hexadecimal works too
```

The string forms are `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`, with or without the `#`, and
`Color.hex` raises an error for a string that isn't one of them.

## Hue, saturation and value

Red, green and blue are how a screen thinks about colour, but not how people usually do. "A slightly
darker, less intense blue" is hard to turn into three numbers. **HSV** describes a colour the way
people tend to:

- The **hue** is which colour it is, as an angle in degrees round a colour wheel: 0 is red, 60
  yellow, 120 green, 180 cyan, 240 blue, 300 magenta, and 360 is back to red.
- The **saturation**, from 0 to 1, is how intense it is: 0 is a grey, and 1 the purest form of the
  hue.
- The **value**, from 0 to 1, is how bright it is: 0 is black, and 1 as bright as the colour gets.

```mojo
canvas.fill(Color.hsv(200, 0.8, 1.0))  # a bright sky blue
canvas.fill(Color.hsv(200, 0.8, 0.5))  # the same blue, darker
canvas.fill(Color.hsv(200, 0.3, 1.0))  # the same blue, paler
```

Because the hue wraps round, moving it steadily cycles through the rainbow, which is the usual way
to make a colour that keeps changing:

```mojo
# In `update`: a colour that runs through the whole rainbow every 6 seconds.
canvas.fill(Color.hsv(context.time.elapsed * 60, 1.0, 1.0))
```

`color.to_hsv()` goes the other way, returning a colour's hue, saturation and value, so you can take
an existing colour and change only its brightness, for example.

## Mixing colours

`a.lerp(b, t)` mixes two colours: `t` is how far to go from `a` towards `b`, from 0 (all `a`) to 1
(all `b`), so 0.5 is halfway between them. It is the way to fade smoothly from one colour to
another:

```mojo
# In `update`: a health bar that turns from green to red as health runs out.
canvas.fill(Color.RED.lerp(Color.GREEN, self.health / self.max_health))
```

`t` is kept between 0 and 1, so a value outside that range gives the nearer of the two colours. How
`lerp` works for numbers, and why it is so useful, is in [Interpolation](../math/interpolation.md).

## Light or dark

`color.luminance()` is how bright a colour looks to the eye, from 0 (black) to 1 (white). Green
looks much brighter than blue at the same strength, and luminance takes that into account. It
answers questions such as whether text drawn on a colour should be black or white. The eye is more
sensitive to differences between dark colours than between light ones, so the point where black text
starts to read better than white is lower than you might expect, at about 0.18:

```mojo
var text_color = Color.BLACK if background.luminance() > 0.18 else Color.WHITE
```
