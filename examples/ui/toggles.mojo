"""The Toggles page: checkboxes, switches and a choice group."""

from create import *
from line import line


struct TogglesPage(Movable):
    """Settings that are on or off, as checkboxes and switches, and one of a
    few, as a choice group. The dark theme switch changes the menu's
    colours."""

    var hints: WidgetHandle[Checkbox]
    var dark: WidgetHandle[Switch]
    var music: WidgetHandle[Switch]
    var difficulty: WidgetHandle[ChoiceGroup]

    def __init__(out self, mut ui: UI, page: WidgetHandle[Column]):
        # a checkbox for a choice made before something else happens
        self.hints = ui.add(Checkbox("Show hints", checked=True), page)
        _ = ui.add(Checkbox("Hard mode", enabled=False), page)
        # a switch for a setting that applies the moment it is turned
        self.dark = ui.add(Switch("Dark theme", on=True), page)
        self.music = ui.add(Switch("Music", on=True), page)
        self.difficulty = ui.add(
            ChoiceGroup(["Easy", "Normal", "Hard"], selected=1),
            line(ui, page, "Difficulty"),
            width=0,
            grow=3,
        )
        ui.tooltip(self.difficulty, "How hard the enemies hit")

    def update(self, ui: UI) -> Optional[String]:
        """What the player did on this page this frame, to show them."""
        if ui[self.hints].changed():
            return "Hints " + ("on" if ui[self.hints].checked else "off")
        if ui[self.music].changed():
            return "Music " + ("on" if ui[self.music].on else "off")
        if ui[self.difficulty].changed():
            return "Difficulty: " + ui[self.difficulty].selected_text()
        return None

    def dark_theme(self, ui: UI) -> Bool:
        """Whether the dark theme switch is on."""
        return ui[self.dark].on
