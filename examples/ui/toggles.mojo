"""The Toggles page: checkboxes, a switch and a choice group."""

from create import *


struct TogglesPage(Movable):
    """Settings that are on or off, as checkboxes and a switch, and one of a
    few, as a choice group. The dark theme switch changes the menu's
    colours."""

    var hints: WidgetHandle[Checkbox]
    var dark: WidgetHandle[Switch]
    var difficulty: WidgetHandle[ChoiceGroup]

    def __init__(out self, mut ui: UI, page: WidgetHandle[Column]):
        # A checkbox, for a choice made before something else happens.
        self.hints = ui.add(Checkbox("Show hints", checked=True), page)
        _ = ui.add(Checkbox("Hard mode", enabled=False), page)
        _ = ui.add(Space(), page)

        # A switch, for a setting that applies the moment it is turned.
        self.dark = ui.add(Switch("Dark theme", on=True), page)
        _ = ui.add(Space(), page)

        # A choice group, for one of a few options shown together, beneath
        # the name of what it chooses.
        _ = ui.add(Label("Difficulty"), page)
        self.difficulty = ui.add(
            ChoiceGroup(["Easy", "Normal", "Hard"], selected=1), page
        )
        ui.tooltip(self.difficulty, "How hard the enemies hit")

    def update(self, ui: UI) -> Optional[String]:
        """What the player did on this page this frame, to show them."""
        if ui[self.hints].changed():
            return "Hints " + ("on" if ui[self.hints].checked else "off")
        if ui[self.difficulty].changed():
            return "Difficulty: " + ui[self.difficulty].selected_text()
        return None

    def dark_theme(self, ui: UI) -> Bool:
        """Whether the dark theme switch is on."""
        return ui[self.dark].on
