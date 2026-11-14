from std.collections import Dict, Optional
from std.math import max, min
from .align import Align
from create.color.color import Color
from create.text.font import (
    Font,
    _GlyphInfo,
    _default_font,
    _fallback_font,
)
from ._blur import blur_alpha
from ._raster import blit_alpha_mapped, blit_glyph
from ._image_mapping import mask_mapping
from create.math.matrix import Matrix
from ._paint import TextStyle
from ._surface import Surface

comptime _MAX_SIZE = 4095
"""The largest pixel size text is rasterised at: 12 bits of the glyph key."""
comptime _MAX_WEIGHT = 1023
"""The largest weight a key can hold, 10 bits; faces stop at 900 anyway."""
comptime _MAX_BLUR = 1023
"""The widest shadow blur, in pixels, a glyph mask is made for: 10 bits."""
comptime _FONT_SLOTS = 1024
"""Faces one renderer keys glyphs for before it starts over: 10 bits."""

comptime _GLYPH_CACHE_LIMIT = 4096
"""Cached masks kept before the cache is dropped whole.

Autoscale makes the pixel size a function of the window, so a window being
dragged larger mints a fresh size — and a fresh set of masks — every frame.
Unbounded, that grows without limit; dropping the lot on the rare occasion it
fills costs one repopulating frame and needs no recency bookkeeping.
"""


def _pixel_size(style: TextStyle, pixel_scale: Float64) -> Int:
    """The font size in pixels: world units scaled, at least one and at most
    `_MAX_SIZE`."""
    return min(max(Int(style.font_size * pixel_scale + 0.5), 1), _MAX_SIZE)


def _key_weight(style: TextStyle) -> Int:
    """The style's weight, clamped into the glyph key's 10 bits."""
    return min(max(style.font_weight.value, 0), _MAX_WEIGHT)


struct PlacedGlyph(Copyable, Movable):
    """One glyph of a laid-out string, positioned in device pixels.

    What `layout` returns and both backends consume: the CPU replay blits the
    cached mask at `(x, y)`, the GL one packs that same mask into its atlas and
    emits a quad there. Neither re-derives a pen position, so alignment cannot
    drift between them.

    `key` indexes `TextRenderer`'s cache rather than carrying the mask, because
    a mask is a `List[UInt8]` and copying one per character per frame is the
    cost the cache exists to avoid.
    """

    var key: Int
    """`_ensure_glyph`'s key — already cached by the time this is returned."""
    var x: Int
    """Device x of the mask's left edge."""
    var y: Int
    """Device y of the mask's top edge."""
    var width: Int
    var height: Int

    def __init__(out self, key: Int, x: Int, y: Int, width: Int, height: Int):
        self.key = key
        self.x = x
        self.y = y
        self.width = width
        self.height = height


comptime _NEWLINE = 10
comptime _CARRIAGE_RETURN = 13
comptime _SPACE = 32

comptime NO_WRAP = -1.0
"""The wrap width of text that breaks only at its newlines."""


@fieldwise_init
struct _Line(ImplicitlyCopyable, Movable):
    """One line of a `_Run`: its glyphs `[start, end)` and their width in
    pixels."""

    var start: Int
    var end: Int
    var width: Int


struct _Run(Movable):
    """A string measured for layout: each glyph's cache key and pen position,
    and the lines they break into. Line breaks take no glyph."""

    var keys: List[Int]
    var pens: List[Int]
    """The pen's x before each glyph, from the run's start, and one more
    after the last: glyphs sit advance to advance with no kerning, so the
    glyphs `[a, b)` are `pens[b] - pens[a]` wide."""
    var spaces: List[Bool]
    """Whether each glyph is a space, where a wrapped line may break."""
    var lines: List[_Line]

    def __init__(out self):
        self.keys = List[Int]()
        self.pens = [0]
        self.spaces = List[Bool]()
        self.lines = List[_Line]()

    def append(mut self, key: Int, advance: Int, space: Bool):
        self.keys.append(key)
        self.pens.append(self.pens[len(self.pens) - 1] + advance)
        self.spaces.append(space)

    def width(self, start: Int, end: Int) -> Int:
        """How wide the glyphs `[start, end)` are, in pixels."""
        return self.pens[end] - self.pens[start]

    def end_line(mut self, start: Int, end: Int):
        self.lines.append(_Line(start, end, self.width(start, end)))


struct TextRenderer(Movable):
    """Font ownership and glyph layout, kept out of the rendering surface.

    Holds the loaded faces, so it is the other half of what has to survive a
    frame: reloading a font every frame would be absurd. Lays a string out in
    pixel space and hands each glyph's coverage mask to the rasteriser.
    """

    var _default: Optional[Font]
    """Noto Sans, loaded on first use."""
    var _fallback_font: List[Font]
    var _fallback_attempted: Bool
    var _fonts: Dict[Int, Font]
    """The faces glyphs have been cached for, by slot: the number a glyph
    key carries to say which face drew it. Held so a slot keeps naming its
    face for as long as its keys are cached."""
    var _font_slots: Dict[Int, Int]
    """`Font._id` to its slot."""
    var _glyphs: Dict[Int, _GlyphInfo]
    var atlas_generation: Int
    """Bumped whenever a glyph key starts meaning a different bitmap — only
    when the slots run out and are handed out afresh. A backend that caches
    glyphs of its own (the GL atlas does) watches this and drops them.
    Switching fonts does not bump it: each face has keys of its own."""

    def __init__(out self):
        self._default = None
        self._fallback_font = List[Font]()
        self._fallback_attempted = False
        self._fonts = Dict[Int, Font]()
        self._font_slots = Dict[Int, Int]()
        self._glyphs = Dict[Int, _GlyphInfo]()
        self.atlas_generation = 0

    def _ensure_font(mut self) raises:
        """Lazily load the packaged default/fallback fonts on first use.

        Construction opens nothing — a program that renders no text pays no
        freetype or decoding cost. The fallback load is attempted at most
        once; a fallback that fails to open just means no fallback glyphs,
        not a render failure.
        """
        if not self._default:
            self._default = _default_font()
        if not self._fallback_attempted:
            self._fallback_attempted = True
            try:
                self._fallback_font.append(_fallback_font())
            except:
                pass

    def _face(mut self, style: TextStyle) raises -> Font:
        """The face `style` draws text in: its own, or the packaged
        default, and its italic if the style asks for one. The italic has an
        identity of its own, so it takes a slot of its own."""
        self._ensure_font()
        var f = (
            style.font.value().copy() if style.font else self._default.value()
        )
        if style.font_italic:
            return f._italic()
        return f^

    def _slot(mut self, f: Font) -> Int:
        """The slot `f`'s glyphs are keyed by, assigned on first sight.

        Slots are 10 bits of the key. A renderer that has seen that many
        faces starts over: every cached glyph goes, and `atlas_generation`
        tells the GL atlas its keys now mean something else.
        """
        if f._id in self._font_slots:
            try:
                return self._font_slots[f._id]
            except:
                pass  # unreachable: just checked
        if len(self._fonts) >= _FONT_SLOTS:
            self._fonts.clear()
            self._font_slots.clear()
            self._glyphs.clear()
            self.atlas_generation += 1
        var slot = len(self._fonts)
        self._fonts[slot] = f.copy()
        self._font_slots[f._id] = slot
        return slot

    def _glyph_key(
        self, slot: Int, codepoint: Int, size: Int, weight: Int, blur: Int = 0
    ) -> Int:
        """Pack what a mask depends on into one key: 21 bits of codepoint,
        12 of size, 10 of weight, 10 of blur and 10 of font slot. Size, weight
        and blur are clamped into theirs where they enter (`_MAX_SIZE`,
        `_MAX_WEIGHT`, `_MAX_BLUR`)."""
        return (
            codepoint
            | (size << 21)
            | (weight << 33)
            | (blur << 43)
            | (slot << 53)
        )

    def _ensure_glyph(
        mut self,
        slot: Int,
        codepoint: Int,
        size: Int,
        weight: Int,
        blur: Int = 0,
    ) raises -> Int:
        """Cache the mask for `(codepoint, size, weight, blur)` in the face
        in `slot`, and return its key.

        A `blur` above 0 is a shadow's: the plain mask blurred with sigma
        `blur / 2` pixels, grown by the blur's reach and moved back by it, so
        it lays out exactly where the plain glyph does. `blur` is a whole
        number of pixels so that a zooming camera, which changes it
        continuously, mints a new mask only once per pixel.

        Every FreeType call in the text path is behind this miss: rasterising a
        glyph costs an `FT_Load_Char` and an `FT_Render_Glyph` over the C ABI,
        and choosing the face costs an `FT_Get_Char_Index` on top. Laying a
        string out reads each glyph twice — once to measure, once to render — so
        uncached, a static line of text paid all three per character per frame.

        The mask is alpha only and the pen advance is a number, so nothing here
        depends on the fill, the position or the alignment; only these three
        inputs change what is stored.
        """
        var key = self._glyph_key(slot, codepoint, size, weight, blur)
        if key in self._glyphs:
            return key
        if blur > 0:
            var plain = self._ensure_glyph(slot, codepoint, size, weight)
            ref g = self._glyphs[plain]
            var mask = blur_alpha(
                g.pixels, g.width, g.height, Float64(blur) / 2.0
            )
            var blurred = _GlyphInfo(
                mask.width,
                mask.height,
                g.bearing_x - mask.pad,
                g.bearing_y + mask.pad,
                g.advance_x,
            )
            blurred.pixels = mask.pixels.copy()
            if len(self._glyphs) >= _GLYPH_CACHE_LIMIT:
                self._glyphs.clear()
            self._glyphs[key] = blurred^
            return key
        if len(self._glyphs) >= _GLYPH_CACHE_LIMIT:
            self._glyphs.clear()
        # Both faces are set to the requested weight here rather than at the
        # call site, because this is the only place either one rasterises.
        # A copy shares the face, so this is where it rasterises.
        var face = self._fonts[slot].copy()
        if len(self._fallback_font) > 0 and not face.has_glyph(codepoint):
            # Italic text falls back to the fallback's italic. The key names
            # the primary face's slot, so the two never share an entry.
            var fallback = self._fallback_font[0].copy()
            if face._draws_italic:
                fallback = fallback._italic()
            fallback._set_weight(weight)
            self._glyphs[key] = fallback._render(codepoint, size)
        else:
            face._set_weight(weight)
            self._glyphs[key] = face._render(codepoint, size)
        return key

    def glyph_mask(
        self, key: Int
    ) raises -> ref[self._glyphs[0].pixels] List[UInt8]:
        """A cached glyph's coverage mask, row-major, 8-bit, by reference."""
        return self._glyphs[key].pixels

    def _measure(
        mut self,
        slot: Int,
        s: String,
        size: Int,
        weight: Int,
        blur: Int,
        wrap: Float64 = NO_WRAP,
    ) raises -> _Run:
        """Cache every glyph of `s` and break it into lines: at each newline,
        and, unless `wrap` is `NO_WRAP`, wherever a line would grow wider
        than `wrap` pixels.

        A carriage return is dropped, so a Windows line ending breaks once. A
        wrapped line breaks before the last run of spaces that fits, and the
        spaces are dropped, so no line starts or ends with them; a word wider
        than `wrap` alone breaks between its glyphs. Every line keeps at
        least one glyph, so a `wrap` of 0 puts one on each. Spaces may
        overhang `wrap`, as they do in CSS, since nothing is drawn of them.
        """
        var run = _Run()
        # The current line's first glyph.
        var start = 0
        # The current line's last run of spaces after a word, where it would
        # break: the run's first space.
        var gap = -1
        for cp in s.codepoints():
            var c = Int(cp)
            if c == _NEWLINE:
                run.end_line(start, len(run.keys))
                start = len(run.keys)
                gap = -1
                continue
            if c == _CARRIAGE_RETURN:
                continue
            var key = self._ensure_glyph(slot, c, size, weight, blur)
            var advance = self._glyphs[key].advance_x
            var i = len(run.keys)
            var space = c == _SPACE
            while (
                wrap >= 0.0
                and not space
                and i > start
                and Float64(run.width(start, i) + advance) > wrap
            ):
                if gap > start:
                    run.end_line(start, gap)
                    start = gap
                    while start < i and run.spaces[start]:
                        start += 1
                    gap = -1
                else:
                    run.end_line(start, i)
                    start = i
            if space and i > start and not run.spaces[i - 1]:
                gap = i
            run.append(key, advance, space)
        run.end_line(start, len(run.keys))
        return run^

    def width(
        mut self,
        s: String,
        style: TextStyle,
        pixel_scale: Float64,
        wrap: Float64 = NO_WRAP,
    ) raises -> Int:
        """How wide `layout` makes `s`, in pixels, without placing it: its
        widest line."""
        var size = _pixel_size(style, pixel_scale)
        var slot = self._slot(self._face(style))
        var run = self._measure(slot, s, size, _key_weight(style), 0, wrap)
        var widest = 0
        for ref line in run.lines:
            widest = max(widest, line.width)
        return widest

    def height(
        mut self,
        s: String,
        style: TextStyle,
        pixel_scale: Float64,
        wrap: Float64 = NO_WRAP,
    ) raises -> Int:
        """How tall `layout` makes `s`, in pixels: the top of its first line
        to the bottom of its last, the box `Align` anchors."""
        var size = _pixel_size(style, pixel_scale)
        var face = self._face(style)
        var slot = self._slot(face)
        var run = self._measure(slot, s, size, _key_weight(style), 0, wrap)
        var metrics = face._vertical_metrics(size)
        return metrics[0] - metrics[1] + (len(run.lines) - 1) * metrics[2]

    def layout(
        mut self,
        s: String,
        tx: Float64,
        ty: Float64,
        style: TextStyle,
        pixel_scale: Float64,
        blur: Int = 0,
        wrap: Float64 = NO_WRAP,
    ) raises -> List[PlacedGlyph]:
        """Place `s` around the already-mapped anchor `(tx, ty)`, as masks
        blurred by `blur` pixels (see `_ensure_glyph`), broken into lines at
        its newlines and wrapped at `wrap` pixels (see `_measure`).

        Glyphs lay out upright in pixel space, y down, so `Align.TOP`/`BOTTOM`
        mean the top and bottom of the text box: the first line's ascent to
        the last line's descent, lines a face's line height apart. Each line
        is aligned horizontally on its own. Under an upright transform the
        caller maps the anchor and the layout is final; under any other it
        lays out around the origin and maps each glyph's rect through
        `glyph_transform`, so the box turns with the text.

        Every glyph is in the cache when this returns, so a caller can read
        each one's mask by key without another FreeType call.
        """
        var size = _pixel_size(style, pixel_scale)
        var face = self._face(style)
        var slot = self._slot(face)
        var weight = _key_weight(style)
        var blur_px = min(max(blur, 0), _MAX_BLUR)

        # Two passes: measure every line for alignment, then place.
        var run = self._measure(slot, s, size, weight, blur_px, wrap)

        var metrics = face._vertical_metrics(size)
        var asc = metrics[0]
        var desc = metrics[1]
        var line_height = metrics[2]
        # From the first baseline to the last.
        var block = (len(run.lines) - 1) * line_height
        var align = style.text_alignment
        var baseline_y = Int(ty)
        if align._top():
            baseline_y += asc
        elif align._bottom():
            baseline_y += desc - block
        else:
            baseline_y += (asc + desc - block) // 2

        var placed = List[PlacedGlyph]()
        for ref line in run.lines:
            var cx = Int(tx)
            if align._right():
                cx -= line.width
            elif not align._left():
                cx -= line.width // 2
            for i in range(line.start, line.end):
                # Bound by reference: the mask stays in the cache rather than
                # being copied out of it once per character.
                var key = run.keys[i]
                ref g = self._glyphs[key]
                if g.width > 0 and g.height > 0:
                    var x = cx + run.width(line.start, i)
                    placed.append(
                        PlacedGlyph(
                            key,
                            x + g.bearing_x,
                            baseline_y - g.bearing_y,
                            g.width,
                            g.height,
                        )
                    )
            baseline_y += line_height
        return placed^

    def render[
        o: Origin[mut=True]
    ](
        mut self,
        surf: Surface[o],
        s: String,
        tx: Float64,
        ty: Float64,
        style: TextStyle,
        pixel_scale: Float64,
        blur: Int = 0,
        wrap: Float64 = NO_WRAP,
    ) raises:
        """Blit `s` through `layout`, so the CPU and GL paths place a glyph
        with one function rather than two that have to agree."""
        var c = style.text_color
        for ref p in self.layout(s, tx, ty, style, pixel_scale, blur, wrap):
            ref g = self._glyphs[p.key]
            blit_glyph(surf, g, p.x, p.y, c)

    def render_mapped[
        o: Origin[mut=True]
    ](
        mut self,
        surf: Surface[o],
        s: String,
        glyphs: Matrix[3, 3],
        style: TextStyle,
        pixel_scale: Float64,
        blur: Int = 0,
        wrap: Float64 = NO_WRAP,
    ) raises:
        """Blit `s` laid out upright around the origin, every glyph mapped
        onto the device by `glyphs` (`glyph_transform`): text turned,
        sheared or mirrored with its transform."""
        var c = style.text_color
        for ref p in self.layout(s, 0.0, 0.0, style, pixel_scale, blur, wrap):
            ref g = self._glyphs[p.key]
            blit_alpha_mapped(
                surf,
                g.pixels.unsafe_ptr(),
                g.width,
                g.height,
                mask_mapping(glyphs, p.x, p.y, g.width, g.height),
                c,
            )
