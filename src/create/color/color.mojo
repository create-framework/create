from std.math import abs, atan2, cos, max, min, pi, sin, sqrt


def _channel(v: Float64) -> UInt8:
    """Round a 0..1 channel to a byte, clamped."""
    return UInt8(Int(min(max(v, 0.0), 1.0) * 255.0 + 0.5))


def _linear(v: UInt8) -> Float64:
    """Undo the sRGB transfer curve for one channel."""
    var c = Float64(Int(v)) / 255.0
    if c <= 0.03928:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def _encode(c: Float64) -> Float64:
    """Apply the sRGB transfer curve to one linear channel."""
    if c <= 0.0031308:
        return 12.92 * c
    return 1.055 * c ** (1.0 / 2.4) - 0.055


def _cube_root(x: Float64) -> Float64:
    return x ** (1.0 / 3.0) if x >= 0.0 else -((-x) ** (1.0 / 3.0))


def _oklab_to_linear(
    l: Float64, a: Float64, b: Float64
) -> Tuple[Float64, Float64, Float64]:
    """An OKLab colour as linear sRGB, each channel 0 to 1 when the screen
    can show it (Björn Ottosson's matrices)."""
    var l_ = l + 0.3963377774 * a + 0.2158037573 * b
    var m_ = l - 0.1055613458 * a - 0.0638541728 * b
    var s_ = l - 0.0894841775 * a - 1.2914855480 * b
    var ll = l_ * l_ * l_
    var mm = m_ * m_ * m_
    var ss = s_ * s_ * s_
    return (
        4.0767416621 * ll - 3.3077115913 * mm + 0.2309699292 * ss,
        -1.2684380046 * ll + 2.6097574011 * mm - 0.3413193965 * ss,
        -0.0041960863 * ll - 0.7034186147 * mm + 1.7076147010 * ss,
    )


def _in_gamut(rgb: Tuple[Float64, Float64, Float64]) -> Bool:
    """Whether every channel is one the screen can show, allowing for
    rounding."""
    comptime slack = 1e-4
    return (
        -slack <= rgb[0] <= 1.0 + slack
        and -slack <= rgb[1] <= 1.0 + slack
        and -slack <= rgb[2] <= 1.0 + slack
    )


def _hex_digit(byte: UInt8) -> Int:
    """One hex digit's value, or -1 if the byte is not a hex digit."""
    var c = Int(byte)
    if c >= 48 and c <= 57:  # '0'-'9'
        return c - 48
    if c >= 97 and c <= 102:  # 'a'-'f'
        return c - 87
    if c >= 65 and c <= 70:  # 'A'-'F'
        return c - 55
    return -1


def _mix(a: UInt8, b: UInt8, t: Float64) -> UInt8:
    var fa = Float64(Int(a))
    var fb = Float64(Int(b))
    return UInt8(Int(fa + (fb - fa) * t + 0.5))


@always_inline
def _multiplied(c: UInt8, t: UInt8) -> UInt8:
    """One channel `c` scaled by `t / 255`, rounded; exact for `t == 255`."""
    return UInt8((UInt32(c) * UInt32(t) + 127) // 255)


def _tinted(color: Color, tint: Color, opacity: Float64 = 1.0) -> Color:
    """`color` multiplied channel by channel by `tint`, its alpha also by
    `opacity`, clamped to `UInt8`. A white `tint` and an `opacity` of 1 leave
    it exactly as it was."""
    var a = Float64(color.a) * (opacity * (Float64(tint.a) / 255.0))
    return Color(
        _multiplied(color.r, tint.r),
        _multiplied(color.g, tint.g),
        _multiplied(color.b, tint.b),
        UInt8(max(0.0, min(255.0, a))),
    )


struct Color(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A colour: red, green and blue, each from 0 to 255, and an alpha from 0
    (invisible) to 255 (opaque, the default).

    `Color(200)` is a gray. Build one from text with `hex`, or from hue,
    saturation and value with `hsv`; the named colours (`RED`, `TRANSPARENT`,
    …) are constants. `with_alpha` and `lerp` derive new colours.
    """

    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8

    def __init__(out self, r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255):
        self.r = r
        self.g = g
        self.b = b
        self.a = a

    def __init__(out self, gray: UInt8):
        self = Color(gray, gray, gray)

    def __eq__(self, other: Color) -> Bool:
        return (
            self.r == other.r
            and self.g == other.g
            and self.b == other.b
            and self.a == other.a
        )

    def __ne__(self, other: Color) -> Bool:
        return not (self == other)

    def write_to[W: Writer](self, mut writer: W):
        writer.write(
            "Color(", self.r, ", ", self.g, ", ", self.b, ", ", self.a, ")"
        )

    def luminance(self) -> Float64:
        """WCAG relative luminance, 0.0 (black) to 1.0 (white).

        Answers "is this background light or dark" — the usual caller picks
        black or white text against it, with 0.18 as the crossover.
        """
        return (
            0.2126 * _linear(self.r)
            + 0.7152 * _linear(self.g)
            + 0.0722 * _linear(self.b)
        )

    def to_hsv(self) -> Tuple[Float64, Float64, Float64]:
        """Inverse of `hsv`: hue in degrees, saturation and value in 0..1.

        Hue is 0.0 for grays, which have none.
        """
        var r = Float64(Int(self.r)) / 255.0
        var g = Float64(Int(self.g)) / 255.0
        var b = Float64(Int(self.b)) / 255.0
        var mx = max(r, max(g, b))
        var mn = min(r, min(g, b))
        var d = mx - mn
        var h = 0.0
        if d > 0.0:
            if mx == r:
                h = 60.0 * ((g - b) / d)
            elif mx == g:
                h = 60.0 * ((b - r) / d + 2.0)
            else:
                h = 60.0 * ((r - g) / d + 4.0)
            if h < 0.0:
                h += 360.0
        var s = 0.0 if mx == 0.0 else d / mx
        return (h, s, mx)

    def over(self, dst: Color) -> Color:
        """Composite this color over `dst`, source-over.

        `self.a` decides how much of `self` shows through. Compositing over an
        opaque color yields an opaque color, so this is what a background fill does
        against the framebuffer.
        """
        if self.a == 255:
            return self
        if self.a == 0:
            return dst
        var a = Int(self.a)
        var ia = 255 - a
        return Color(
            UInt8((Int(self.r) * a + Int(dst.r) * ia) // 255),
            UInt8((Int(self.g) * a + Int(dst.g) * ia) // 255),
            UInt8((Int(self.b) * a + Int(dst.b) * ia) // 255),
            UInt8(a + Int(dst.a) * ia // 255),
        )

    def with_alpha(self, a: UInt8) -> Color:
        """This color at a different opacity, 0 (invisible) to 255 (opaque).

        The RGB channels are carried over untouched, so a named constant or a
        computed color stays spelled once: `Color.RED.with_alpha(128)` rather
        than respelling all three channels to change the fourth.
        """
        return Color(self.r, self.g, self.b, a)

    @staticmethod
    def hex(rgb: Int) -> Color:
        """Build a color from a packed literal: `Color.hex(0x336699)`."""
        return Color(
            UInt8((rgb >> 16) & 0xFF),
            UInt8((rgb >> 8) & 0xFF),
            UInt8(rgb & 0xFF),
        )

    @staticmethod
    def hex(code: String) raises -> Color:
        """Build a color from a CSS hex string: `Color.hex("#336699")`.

        Accepts `#rgb`, `#rgba`, `#rrggbb` and `#rrggbbaa`; the leading `#` is
        optional and case does not matter. The short forms double each digit,
        as CSS does, so `"#f80"` is `"#ff8800"`. Alpha defaults to opaque.

        This is the form to paste into from a design tool, and the only one
        that carries alpha in a single token. `hex(Int)` stays the form for a
        literal written in source, since a parse can raise and so cannot run
        at compile time.

        Raises:
            If the string is not one of the four accepted lengths, or holds a
            character that is not a hex digit.
        """
        var bytes = code.as_bytes()
        var start = 0
        if len(bytes) > 0 and bytes[0] == 35:  # '#'
            start = 1
        var count = len(bytes) - start
        if count != 3 and count != 4 and count != 6 and count != 8:
            raise Error(
                "Color.hex: expected 3, 4, 6 or 8 hex digits, got '",
                code,
                "'",
            )
        var digits = List[Int]()
        for i in range(start, len(bytes)):
            var d = _hex_digit(bytes[i])
            if d < 0:
                raise Error("Color.hex: not a hex color: '", code, "'")
            digits.append(d)

        if count <= 4:
            var a = 255 if count == 3 else digits[3] * 17
            return Color(
                UInt8(digits[0] * 17),
                UInt8(digits[1] * 17),
                UInt8(digits[2] * 17),
                UInt8(a),
            )
        var a = 255 if count == 6 else (digits[6] << 4) | digits[7]
        return Color(
            UInt8((digits[0] << 4) | digits[1]),
            UInt8((digits[2] << 4) | digits[3]),
            UInt8((digits[4] << 4) | digits[5]),
            UInt8(a),
        )

    @staticmethod
    def hsv(h: Float64, s: Float64, v: Float64) -> Color:
        """Build a color from hue in degrees (wraps) and saturation/value in 0..1.

        Hue cycling is the point: `Color.hsv(Float64(context.frame_count()) % 360.0, 1.0, 1.0)`
        sweeps the spectrum without hand-mixing channels.
        """
        var hh = h - 360.0 * Float64(Int(h / 360.0))
        if hh < 0.0:
            hh += 360.0
        var ss = min(max(s, 0.0), 1.0)
        var vv = min(max(v, 0.0), 1.0)
        var c = vv * ss
        var seg = hh / 60.0
        var f = seg - 2.0 * Float64(Int(seg / 2.0))
        var x = c * (1.0 - abs(f - 1.0))
        var m = vv - c
        var r = 0.0
        var g = 0.0
        var b = 0.0
        if hh < 60.0:
            r = c
            g = x
        elif hh < 120.0:
            r = x
            g = c
        elif hh < 180.0:
            g = c
            b = x
        elif hh < 240.0:
            g = x
            b = c
        elif hh < 300.0:
            r = x
            b = c
        else:
            r = c
            b = x
        return Color(_channel(r + m), _channel(g + m), _channel(b + m))

    @staticmethod
    def oklch(lightness: Float64, chroma: Float64, hue: Float64) -> Color:
        """Build a colour from OKLCH: perceived lightness from 0 (black) to 1
        (white), chroma (how colourful, 0 for a grey, up to about 0.37 for
        the most vivid colours a screen shows) and hue in degrees (wraps).

        Unlike HSV's value, equal steps of lightness look like equal steps
        to the eye, whatever the hue: a yellow and a blue at the same
        lightness look about as light as each other. A colour too vivid for
        the screen to show is brought inside by lowering its chroma, keeping
        its lightness and hue.
        """
        var l = min(max(lightness, 0.0), 1.0)
        var c = max(chroma, 0.0)
        var h = hue * pi / 180.0
        var rgb = _oklab_to_linear(l, c * cos(h), c * sin(h))
        if not _in_gamut(rgb):
            # Lower the chroma until the colour fits, by halving the gap.
            var low = 0.0
            var high = c
            for _ in range(24):
                var middle = (low + high) / 2
                if _in_gamut(
                    _oklab_to_linear(l, middle * cos(h), middle * sin(h))
                ):
                    low = middle
                else:
                    high = middle
            rgb = _oklab_to_linear(l, low * cos(h), low * sin(h))
        return Color(
            _channel(_encode(rgb[0])),
            _channel(_encode(rgb[1])),
            _channel(_encode(rgb[2])),
        )

    def to_oklch(self) -> Tuple[Float64, Float64, Float64]:
        """Inverse of `oklch`: perceived lightness from 0 to 1, chroma, and
        hue in degrees from 0 to 360. Hue is 0.0 for greys, which have none.
        """
        var r = _linear(self.r)
        var g = _linear(self.g)
        var b = _linear(self.b)
        var l_ = _cube_root(
            0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        )
        var m_ = _cube_root(
            0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        )
        var s_ = _cube_root(
            0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
        )
        var lightness = (
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
        )
        var a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
        var bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        var chroma = sqrt(a * a + bb * bb)
        var hue = 0.0
        if chroma > 1e-4:
            hue = atan2(bb, a) * 180.0 / pi
            if hue < 0.0:
                hue += 360.0
        else:
            chroma = 0.0
        return (lightness, chroma, hue)

    def lerp(self, other: Color, t: Float64) -> Color:
        """A new colour `t` of the way from this one to `other`, `t` clamped
        to 0..1; this one is unchanged. Mixes in sRGB, like a paint program's
        gradient — not perceptually uniform, but what the eye expects from two
        swatches."""
        var tt = min(max(t, 0.0), 1.0)
        return Color(
            _mix(self.r, other.r, tt),
            _mix(self.g, other.g, tt),
            _mix(self.b, other.b, tt),
            _mix(self.a, other.a, tt),
        )

    comptime TRANSPARENT = Color(0, 0, 0, 0)

    comptime BLACK = Color(0)
    comptime WHITE = Color(255)

    comptime DARK_GRAY = Color(0x40)
    comptime GRAY = Color(0x80)
    comptime LIGHT_GRAY = Color(0xC0)

    comptime RED = Color(255, 0, 0)
    comptime GREEN = Color(0, 255, 0)
    comptime BLUE = Color(0, 0, 255)

    comptime CYAN = Color(0, 255, 255)
    comptime MAGENTA = Color(255, 0, 255)
    comptime YELLOW = Color(255, 255, 0)

    comptime ORANGE = Color(255, 128, 0)
    comptime PINK = Color(255, 128, 192)
    comptime PURPLE = Color(128, 0, 255)
    comptime BROWN = Color(128, 64, 0)
