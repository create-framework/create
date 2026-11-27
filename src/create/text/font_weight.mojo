"""`FontWeight`: a stroke weight, for `canvas.font_weight`."""


struct FontWeight(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """A stroke weight, for `canvas.font_weight`.

    Design-space values on the packaged variable faces, so they interpolate
    rather than selecting a file: any number in 100..900 is valid, the
    constants are CSS's names for each hundred. `FontWeight(450)` names one in
    between.

    A wrapped number rather than a bare `Int`, like `WindowMode`, so a stray
    number (a font size, say) cannot be passed where a weight is expected.
    """

    var value: Int

    comptime THIN = FontWeight(100)
    comptime EXTRA_LIGHT = FontWeight(200)
    comptime LIGHT = FontWeight(300)
    comptime REGULAR = FontWeight(400)
    comptime MEDIUM = FontWeight(500)
    comptime SEMI_BOLD = FontWeight(600)
    comptime BOLD = FontWeight(700)
    comptime EXTRA_BOLD = FontWeight(800)
    comptime BLACK = FontWeight(900)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: FontWeight) -> Bool:
        return self.value == other.value

    def __ne__(self, other: FontWeight) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        comptime names = [
            (FontWeight.THIN, StaticString("THIN")),
            (FontWeight.EXTRA_LIGHT, StaticString("EXTRA_LIGHT")),
            (FontWeight.LIGHT, StaticString("LIGHT")),
            (FontWeight.REGULAR, StaticString("REGULAR")),
            (FontWeight.MEDIUM, StaticString("MEDIUM")),
            (FontWeight.SEMI_BOLD, StaticString("SEMI_BOLD")),
            (FontWeight.BOLD, StaticString("BOLD")),
            (FontWeight.EXTRA_BOLD, StaticString("EXTRA_BOLD")),
            (FontWeight.BLACK, StaticString("BLACK")),
        ]
        comptime for i in range(len(names)):
            comptime entry = names[i]
            if self == entry[0]:
                writer.write("FontWeight.", entry[1])
                return
        writer.write("FontWeight(", self.value, ")")
