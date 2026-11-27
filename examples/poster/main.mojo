"""A generative type poster: words in random faces, weights and sizes, each
fitted to its row.

Every choice comes from a `Random` seeded with the poster's number, made
afresh each frame: the same seed always deals the same poster, so the
picture holds still, and a good one can be had again from its number.

The words mix the packaged Noto Sans with JetBrains Mono, a variable font
loaded from this example's assets with `Font.load`, its italic from a
second file. Each word is measured with `text_width` at one size and scaled
to fill its share of the width, then aligned left, centre or right.

Space deals a new poster.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime PAPER = COLORS.background
comptime INK = COLORS.on_surface
comptime WIDTH = 600
comptime HEIGHT = 840
comptime MARGIN = 40.0
comptime MEASURE_SIZE = 100.0
"""The size words are measured at before they are scaled to fit."""


def words() -> List[String]:
    return [
        "CREATE",
        "SKETCH",
        "MOJO",
        "DRAW",
        "PLAY",
        "SHAPE",
        "COLOUR",
        "MOTION",
        "PIXEL",
        "CODE",
        "FORM",
        "make",
        "type",
        "grid",
    ]


def weights() -> List[FontWeight]:
    return [
        FontWeight.THIN,
        FontWeight.LIGHT,
        FontWeight.REGULAR,
        FontWeight.BOLD,
        FontWeight.EXTRA_BOLD,
    ]


def accents() -> List[Color]:
    return [
        Color.RED,
        Color.YELLOW,
        Color.GREEN,
        Color.CYAN,
        Color.BLUE,
        Color.MAGENTA,
    ]


@fieldwise_init
struct Poster(Program):
    var mono: Font
    var seed: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Poster:
        var mono = Font.load(
            "assets/fonts/JetBrainsMono.ttf",
            italic_path="assets/fonts/JetBrainsMono-Italic.ttf",
        )
        return Poster(mono=mono, seed=1)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        if context.keyboard.pressed(Key.SPACE):
            self.seed += 1

        # The same seed makes the same choices, so the poster holds still until
        # Space changes it.
        var random = Random(UInt64(self.seed))
        var all_accents = accents()
        var accent = all_accents[random.int(0, len(all_accents))]

        canvas.background(PAPER)

        # A translucent accent shape behind the words.
        with canvas.style(fill=accent.with_alpha(110), stroke_enabled=False):
            canvas.circle(
                (
                    random.float(canvas.left(), canvas.right()),
                    random.float(canvas.bottom(), canvas.top()),
                ),
                random.float(120.0, 260.0),
            )

        # Each row is a word sized to fill a random share of the width.
        var all_words = words()
        var all_weights = weights()
        var rows = random.int(4, 8)
        var footer = 50.0
        var row_height = (canvas.height() - 2.0 * MARGIN - footer) / Float64(
            rows
        )
        var full_width = canvas.width() - 2.0 * MARGIN

        for row in range(rows):
            var y = canvas.top() - MARGIN - (Float64(row) + 0.5) * row_height
            var word = all_words[random.int(0, len(all_words))]
            var share = random.float(0.45, 1.0)
            var align = random.int(0, 3)

            # Each row's own style, so nothing carries into the next.
            with canvas.style():
                if random.bool():
                    canvas.font(self.mono)
                canvas.font_weight(all_weights[random.int(0, len(all_weights))])
                canvas.font_italic(random.float() < 0.3)
                canvas.text_color(accent if random.float() < 0.25 else INK)

                # Measured once, then scaled: text width grows in proportion
                # to the size, so one measurement says what size fills the
                # share. Capped by the row's height so tall words still fit.
                canvas.font_size(MEASURE_SIZE)
                var measured = canvas.text_width(word)
                var size = min(
                    MEASURE_SIZE * full_width * share / measured,
                    row_height * 1.2,
                )
                canvas.font_size(size)

                if align == 0:
                    canvas.text_alignment(Align.LEFT)
                    canvas.text(word, (canvas.left() + MARGIN, y))
                elif align == 1:
                    canvas.text(word, (0.0, y))
                else:
                    canvas.text_alignment(Align.RIGHT)
                    canvas.text(word, (canvas.right() - MARGIN, y))

        with canvas.style(
            font=self.mono,
            font_size=16,
            text_color=INK,
            opacity=0.6,
            text_alignment=Align.BOTTOM,
        ):
            canvas.text(
                String("Seed ", self.seed, "   Space: a new poster"),
                (0.0, canvas.bottom() + 20.0),
            )


def main() raises:
    run[Poster]("Poster", width=WIDTH, height=HEIGHT)
