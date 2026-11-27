"""The Lists page: a dropdown, and a list of levels in a scroll area."""

from create import *
from line import line

# How much of the list of levels shows at once: three and a half buttons,
# so the one cut in half says there are more.
comptime LEVELS_HEIGHT = 3.5 * 40

# How far inside its surface the list of levels sits.
comptime LEVELS_PADDING = 4


def resolutions() -> List[String]:
    """The screen sizes the dropdown offers."""
    return [
        "1280 × 720",
        "1600 × 900",
        "1920 × 1080",
        "2560 × 1440",
        "3840 × 2160",
    ]


def level_names() -> List[String]:
    """The levels to pick from: more than fit in their scroll area."""
    return ["Forest", "Caves", "River", "Castle", "Tower", "Sky", "Moon"]


struct ListsPage(Movable):
    """One of many options, in a dropdown, and a list too long to show
    whole, in a scroll area on a surface of its own."""

    var resolution: WidgetHandle[Dropdown]
    var surface: WidgetHandle[Panel]
    var levels: List[WidgetHandle[Button]]

    def __init__(out self, mut ui: UI, page: WidgetHandle[Column]):
        self.resolution = ui.add(
            Dropdown(resolutions(), selected=2),
            line(ui, page, "Resolution"),
            width=0,
            grow=3,
        )
        ui.tooltip(self.resolution, "The size of the game's window")

        # The levels: a column of buttons, in a scroll area that shows a few,
        # on a surface of its own so it stands out from the panel.
        var pick = line(ui, page, "Level")
        self.surface = ui.add(
            Panel(
                padding=LEVELS_PADDING,
                style=Style(fill=ColorRole.SURFACE_CONTAINER_HIGHEST),
            ),
            pick,
            width=0,
            grow=3,
        )
        var inside = ui.add(Column(), self.surface)
        var window = ui.add(ScrollArea(max_height=LEVELS_HEIGHT), inside)
        var list = ui.add(Column(gap=0), window)

        self.levels = []
        for level in level_names():
            self.levels.append(ui.add(Button(level, style=Button.TEXT), list))

    def update(self, ui: UI) -> Optional[String]:
        """What the player did on this page this frame, to show them."""
        if ui[self.resolution].changed():
            return "Resolution: " + ui[self.resolution].selected_text()
        for level in self.levels:
            if ui[level].released():
                return "Level: " + ui[level].text
        return None
