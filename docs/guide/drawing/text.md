# Text

`canvas.text` draws text, and like a shape it is drawn in the current style and transform. This page
explains how to choose a font and its size, weight and slant, how text is placed and how to draw
text over several lines or wrapped to fit a column.

## Drawing text

`canvas.text(string, position)` draws `string` centred on `position`, in the current text style:

```mojo
# In `update`:
canvas.text_color(Color.WHITE)
canvas.font_size(32)
canvas.text("Hello", (0, 0))
```

Text has its own colour, set by `text_color`, separate from the fill and the stroke: `fill` never
colours text. Text is black until you set it.

## Fonts

Fonts are part of the style: set one with `canvas.font(f)`, `Style(font=f)` or `with
canvas.style(font=f):`. Its size (`font_size`), weight (`font_weight`) and slant (`font_italic`) are
set the same way:

```mojo
# In `create`, loading the `title_font` field:
var title_font = Font.load("fonts/Title.ttf")

# In `update`:
with canvas.style(font=self.title_font, font_size=48, font_weight=FontWeight.BOLD):
    canvas.text("Game over", (0, 0))
```

- `Font.load(path)` reads a TrueType or OpenType file. A relative path is relative to the source
  file that makes the call (see [File paths](../basics/programs.md#file-paths)).
- A `Font` is kept as a field, like an `Image`: it is a shared asset, cheap to copy, and closed when
  its last copy goes.
- With no font set, text is in Noto Sans, which comes with Create, and a character Noto Sans lacks
  is drawn from Noto Sans Symbols instead.
- Different `text` calls in one frame can use different fonts, and switching fonts costs nothing.
  Like every style setter, `canvas.font` is reset at the end of the frame.

## Italic

`canvas.font_italic(True)`, or the `font_italic=` keyword, slants the text, whatever the font. It
takes the slant from the best source the font has:

1. A separate italic file, loaded with `Font.load(path, italic_path=...)`. The packaged Noto Sans
   ships its italic this way.
2. Otherwise, an italic or slant axis in the font file itself (a variable font's `ital` or `slnt`).
3. Otherwise, its upright letters, sheared 12°.

Letters drawn from a fallback font slant too, so symbols from Noto Sans Symbols, which has no
italic, come out sheared. Weights apply to italic text just as to upright text. `text_width` ignores
the slant, as in CSS, so italic text can stick out slightly past the width it reports.

## Alignment

`canvas.text_alignment(Align.CENTER)`, the default, centres the text on its position, like every
shape. The other eight values name the point of the text's box that lands on the position: `TOP`,
`BOTTOM`, `LEFT` and `RIGHT` are the middles of its edges, and `TOP_LEFT`, `TOP_RIGHT`,
`BOTTOM_LEFT` and `BOTTOM_RIGHT` its corners. So `Align.TOP_LEFT` puts the text's top-left corner on
the position, and the text hangs below it and to its right.

## Several lines

A newline (`"\n"`, or `"\r\n"`) in the string starts a new line, the font's line height below the
last. `text_alignment` places each line separately from side to side, but places the block of lines
as a whole up and down: `TOP` aligns the top of the first line, and `BOTTOM` the bottom of the last.
`canvas.text_width(string)` is the width of the widest line, and `canvas.text_height(string)` the
height of the whole block, from the top of the first line's tallest letters to the bottom of the
last line's lowest:

```mojo
# In `update`: a two-line caption hanging from the top-left corner,
# and a line under it.
var caption = "Level 1\nThe caves"
var corner = Point2D(canvas.left() + 20, canvas.top() - 20)
canvas.text_alignment(Align.TOP_LEFT)
canvas.text(caption, corner)
var under = corner.y - canvas.text_height(caption) - 4
canvas.line((corner.x, under), (corner.x + canvas.text_width(caption), under))
```

## Wrapping

`canvas.text(string, position, width)` also wraps each line so that it is at most `width` units
wide, breaking it at the last space that fits and dropping the spaces at the break. A word wider
than `width` on its own is broken between its letters. Newlines still start new lines, and every
line is still aligned on its own. So with `Align.TOP_LEFT` the text hangs from `position`, with a
straight left edge and a ragged right one. `canvas.text_width(string, width=w)` and
`canvas.text_height(string, width=w)` measure the wrapped block:

```mojo
# In `update`: a paragraph in a 300-unit column, a panel behind it.
var story = "The caves run deeper than the old maps show, and nobody who went down came back."
canvas.text_alignment(Align.TOP_LEFT)
var corner = Point2D(canvas.left() + 20, canvas.top() - 20)
var height = canvas.text_height(story, width=300)
canvas.fill(Color(0, 0, 0, 160))
canvas.rectangle((corner.x + 150, corner.y - height / 2), 300, height)
canvas.text_color(Color.WHITE)
canvas.text(story, corner, 300)
```

Typing text into a program, rather than drawing it, is in [Typing](../interaction/typing.md).
