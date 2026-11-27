"""A typing test: a `TextField` takes what is typed, accented letters
included, and the result is scored in words per minute. The field draws only
its caret and selection; the test draws the letters itself, red where they
are wrong.

Type the phrase shown; Enter moves on once it is right.
"""

from create import *

comptime COLORS = ColorScheme.dark()
comptime BACKGROUND = COLORS.background
comptime HINT = COLORS.on_surface_variant
comptime TYPED = COLORS.on_surface
comptime MISTAKE = Color.RED
comptime SELECTION = COLORS.primary_container
comptime SIZE = 28.0


def characters(text: String) -> List[String]:
    """`text` split into characters, not bytes: an accented letter is two
    bytes of UTF-8 but one character to type."""
    var result = List[String]()
    for character in text.codepoint_slices():
        result.append(String(character))
    return result^


@fieldwise_init
struct TypingTest(Program):
    var field: TextField
    """Does the editing; the test reads what it holds."""
    var phrases: List[String]
    var phrase: Int
    var selection_start: Int
    """Where typing lands, in characters: the start of the selection, as
    the field left it last frame."""
    var started_at: Float64
    var keystrokes: Int
    var mistakes: Int
    var result: String

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> TypingTest:
        return TypingTest(
            # It draws only its caret and selection: no container, and its
            # text transparent. Wide enough that it never scrolls.
            field=TextField(
                container=Style(fill_enabled=False, stroke_enabled=False),
                text_style=Style(text_color=Color.TRANSPARENT, font_size=SIZE),
                caret=Style(stroke=TYPED),
                selection=Style(fill=SELECTION),
                padding=0,
            ),
            phrases=[
                "the quick brown fox jumps over the lazy dog",
                "a café naïve enough to serve crème brûlée",
                "sphinx of black quartz, judge my vow",
            ],
            phrase=0,
            selection_start=0,
            started_at=0,
            keystrokes=0,
            mistakes=0,
            result="",
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        # Set every frame; the window is only told when it changes.
        context.title(
            "Typing — phrase "
            + String(self.phrase + 1)
            + " of "
            + String(len(self.phrases))
        )

        canvas.background(BACKGROUND)

        # Once the phrase is typed, Enter moves on to the next one.
        var target = characters(self.phrases[self.phrase])
        var finished = self.field.text() == self.phrases[self.phrase]
        if finished and context.keyboard.pressed(Key.ENTER):
            self.phrase = (self.phrase + 1) % len(self.phrases)
            self.field.set_text("")
            self.result = ""
            self.selection_start = 0
            finished = False
            target = characters(self.phrases[self.phrase])

        if not finished:
            self.count_keystrokes(context, target)

        # Both lines start at the same left edge, so each typed letter sits
        # under the one it should match.
        canvas.font_size(SIZE)
        canvas.text_alignment(Align.LEFT)
        var left = -canvas.text_width(self.phrases[self.phrase]) / 2
        canvas.text_color(HINT)
        canvas.text(self.phrases[self.phrase], (left, 60))

        # The field does the editing: typed text, Backspace, Delete, the
        # arrows, Shift to select, word moves and copy/paste. It starts at
        # the same left edge and measures in the same font, so its caret and
        # selection fall between the letters drawn below. Given focus every
        # frame, typing keeps going to it, even after a click elsewhere.
        var width = canvas.right() - left
        self.field.rect = Rectangle(Point(left + width / 2, 0), width, 40.0)
        self.field.enabled = not finished
        self.field.focus(not finished)
        self.field.update(context, canvas)
        canvas.draw(self.field)
        self.selection_start = len(characters(self.field.before_selection()))

        # The test ends the moment the field matches the phrase.
        if not finished and self.field.text() == self.phrases[self.phrase]:
            self.result = self.score(len(target), context.time.elapsed)
            finished = True

        # Drawn after the field, so the letters sit over the selection's
        # highlight.
        var x = left
        var typed = characters(self.field.text())
        for i in range(len(typed)):
            var right = i < len(target) and typed[i] == target[i]
            canvas.text_color(TYPED if right else MISTAKE)
            canvas.text(typed[i], (x, 0))
            x += canvas.text_width(typed[i])

        canvas.font_size(20)
        canvas.text_alignment(Align.CENTER)
        canvas.text_color(HINT)

        if finished:
            canvas.text(self.result, (0, -80))
            canvas.text("Enter for the next phrase", (0, -120))
        else:
            canvas.text("Type the phrase above", (0, -80))

    def count_keystrokes(mut self, context: Context, target: List[String]):
        """Count this frame's typed characters, and those that went in wrong
        for where the caret put them. The clock starts on the first."""
        var typed = characters(context.keyboard.text)
        if not typed:
            return

        if not self.field.text():
            self.started_at = context.time.elapsed
            self.keystrokes = 0
            self.mistakes = 0

        # Typing replaces a selection, so it lands where the selection starts.
        var position = self.selection_start
        for i in range(len(typed)):
            self.keystrokes += 1
            var at = position + i
            if at >= len(target) or typed[i] != target[at]:
                self.mistakes += 1

    def score(self, characters: Int, now: Float64) -> String:
        """Words per minute counts five characters as a word, the standard
        typing-test measure; accuracy is the share of keystrokes that were
        right when typed, so a corrected mistake still counts against it."""
        var minutes = max(now - self.started_at, 0.001) / 60
        var wpm = Int(Float64(characters) / 5 / minutes)

        var accuracy = (
            100 * (self.keystrokes - self.mistakes) // max(self.keystrokes, 1)
        )

        return String(wpm, " wpm, ", accuracy, "% accuracy")


def main() raises:
    run[TypingTest]("Typing", width=900, height=600)
