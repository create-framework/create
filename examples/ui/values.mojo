"""The Values page: a text field, a slider, a number field and a progress
bar."""

from create import *
from line import line


struct ValuesPage(Movable):
    """Values the player types or drags: a name, a volume on a slider and
    the voices' volume as a number. The progress bar follows the slider, to
    show a value the program sets."""

    var name: WidgetHandle[TextField]
    var volume: WidgetHandle[Slider]
    var voices: WidgetHandle[NumberField]
    var level: WidgetHandle[ProgressBar]

    def __init__(out self, mut ui: UI, page: WidgetHandle[Column]):
        self.name = ui.add(
            TextField(placeholder="Your name", max_length=16),
            line(ui, page, "Name"),
            width=0,
            grow=3,
        )

        self.volume = ui.add(
            Slider(0.6, 0, 1, step=0.1),
            line(ui, page, "Volume"),
            width=0,
            grow=3,
        )

        self.voices = ui.add(
            NumberField(80, 0, 100, step=5),
            line(ui, page, "Voices"),
            width=0,
            grow=3,
        )
        ui.tooltip(self.voices, "How loud the characters speak, in percent")

        self.level = ui.add(
            ProgressBar(0.6),
            line(ui, page, "Shown"),
            width=0,
            grow=3,
        )
        ui.tooltip(self.level, "The volume again, set by the program")

    def update(self, mut ui: UI) -> Optional[String]:
        """What the player did on this page this frame, to show them; the
        progress bar is set to the volume."""
        ui[self.level].value = ui[self.volume].value

        if ui[self.name].submitted():
            return "Hello, " + ui[self.name].text()
        if ui[self.voices].changed():
            return "Voices at " + String(Int(ui[self.voices].value)) + "%"
        return None
