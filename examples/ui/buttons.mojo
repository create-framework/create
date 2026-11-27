"""The Buttons page: the four kinds of button, and a disabled one."""

from create import *


struct ButtonsPage(Movable):
    """A button of each kind, from the most prominent to the quietest, and a
    disabled one that reacts to nothing."""

    var buttons: List[WidgetHandle[Button]]

    def __init__(out self, mut ui: UI, page: WidgetHandle[Column]):
        _ = ui.add(
            Label("Four kinds, for actions of four weights"),
            page,
        )

        self.buttons = []
        var row = ui.add(Row(), page)
        # Four equal slots: each starts from nothing and grows alike.
        self.buttons.append(ui.add(Button("Play"), row, width=0, grow=1))
        self.buttons.append(
            ui.add(
                Button("Load", style=Button.TONAL),
                row,
                width=0,
                grow=1,
            )
        )
        self.buttons.append(
            ui.add(
                Button("Credits", style=Button.OUTLINED),
                row,
                width=0,
                grow=1,
            )
        )
        self.buttons.append(
            ui.add(
                Button("Quit", style=Button.TEXT),
                row,
                width=0,
                grow=1,
            )
        )
        ui.tooltip(self.buttons[3], "Close the menu")

        _ = ui.add(Space(), page)
        _ = ui.add(Label("Disabled"), page)
        _ = ui.add(Button("Continue", enabled=False), page, align=Align.LEFT)

    def update(self, ui: UI) -> Optional[String]:
        """What the player did on this page this frame, to show them."""
        for button in self.buttons:
            if ui[button].released():
                return "Pressed " + ui[button].text
        return None

    def quit(self, ui: UI) -> Bool:
        """Whether the Quit button was clicked this frame."""
        return ui[self.buttons[3]].released()
