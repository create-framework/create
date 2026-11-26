"""A settings menu made with a `UI`, with every kind of widget, on three
tabs: General has a text field, a choice group, a dropdown and a switch;
Audio has a slider, a switch, a number field and a checkbox; and Levels has
a list of levels in a scroll area and a progress bar. Labels, a panel and
the four kinds of button sit around them.

The widgets are built once, in `create`, and the `UI` keeps them; each frame
it updates them all, then draws them, and the program asks them what
happened through the handles it kept.

Click the widgets, or Tab through them and use Enter, Space and the arrows;
a gamepad's d-pad and A button work too. Left and right switch the tabs,
and up and down move a choice group's choice and step the number field.
Enter opens the dropdown, and Escape closes it, as it leaves the text field.
Rest the pointer on the difficulty, the resolution or the voice volume, or
give them focus from the keyboard, to see a tooltip. Turn the mouse wheel
over the levels, or drag their scroll bar, to see the rest; Tab through the
levels and the list scrolls to keep the focused one in view.
"""

from create import *

# the settings panel, tall enough for the tallest page and the buttons
comptime PANEL = Rectangle((0, 0), 480, 540)
# how much of the list of levels shows at once: four and a half buttons,
# so the one cut in half says there are more
comptime LEVELS_HEIGHT = 4.5 * 40
# how far inside its surface the list of levels sits
comptime LEVELS_PADDING = 4
# how many of the levels the player has finished
comptime FINISHED = 3
# a soft shadow, lifting the panel off the background
comptime SHADOW = Style(
    shadow=Color(0, 0, 0, 60), shadow_offset=Vector(0, -3), shadow_blur=12
)


def level_names() -> List[String]:
    """The levels to pick from: more than fit in their scroll area."""
    return ["Forest", "Caves", "River", "Castle", "Tower", "Sky", "Moon"]


def resolutions() -> List[String]:
    """The screen sizes the dropdown offers."""
    return [
        "1280 × 720",
        "1600 × 900",
        "1920 × 1080",
        "2560 × 1440",
        "3840 × 2160",
    ]


def line(
    mut ui: UI, page: WidgetHandle[Column], name: String
) -> WidgetHandle[Row]:
    """A line of a page: `name` on the left, in a quarter of it, leaving the
    rest for the widget the caller adds to it with `width=0, grow=3`."""
    var row = ui.add(Row(), page)
    _ = ui.add(Label(name, alignment=Align.LEFT), row, width=0, grow=1)
    return row


@fieldwise_init
struct Menu(Program):
    var ui: UI
    var tabs: WidgetHandle[Tabs]
    var pages: List[WidgetHandle[Column]]
    var name: WidgetHandle[TextField]
    var difficulty: WidgetHandle[ChoiceGroup]
    var resolution: WidgetHandle[Dropdown]
    var dark: WidgetHandle[Switch]
    var music: WidgetHandle[Switch]
    var levels_surface: WidgetHandle[Panel]
    var levels: List[WidgetHandle[Button]]
    var buttons: List[WidgetHandle[Button]]
    var message: WidgetHandle[Label]

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Menu:
        var ui = UI()
        var panel = ui.add(Panel(PANEL, style=SHADOW))
        # Each widget below takes the next place down the column.
        var column = ui.add(Column(), panel)
        _ = ui.add(Label("Settings", style=Style(font_size=22)), column)
        var tabs = ui.add(Tabs(["General", "Audio", "Levels"]), column)
        # one column per tab, in the same place: only the selected one shows
        var pages = List[WidgetHandle[Column]]()
        for _ in range(3):
            pages.append(ui.add(Column(), column))

        # General
        var general = pages[0]
        var name = ui.add(
            TextField(placeholder="Your name", max_length=16), general
        )
        var difficulty = ui.add(
            ChoiceGroup(["Easy", "Normal", "Hard"], selected=1),
            line(ui, general, "Difficulty"),
            width=0,
            grow=3,
        )
        ui.tooltip(difficulty, "How hard the enemies hit")
        var resolution = ui.add(
            Dropdown(resolutions(), selected=2),
            line(ui, general, "Resolution"),
            width=0,
            grow=3,
        )
        ui.tooltip(resolution, "The size of the game's window")
        var dark = ui.add(Switch("Dark theme", on=True), general)

        # Audio
        var audio = pages[1]
        _ = ui.add(
            Slider(0.6, 0, 1, step=0.1),
            line(ui, audio, "Volume"),
            width=0,
            grow=3,
        )
        var music = ui.add(Switch("Music", on=True), audio)
        var voice = ui.add(
            NumberField(80, 0, 100, step=5),
            line(ui, audio, "Voices"),
            align=Align.LEFT,
        )
        ui.tooltip(voice, "How loud the characters speak, in percent")
        _ = ui.add(Checkbox("Subtitles"), audio)

        # Levels: a column of buttons, in a window that shows a few, on a
        # surface of its own so it stands out from the panel
        var levels_page = pages[2]
        var levels_surface = ui.add(Panel(padding=LEVELS_PADDING), levels_page)
        var inside = ui.add(Column(), levels_surface)
        var window = ui.add(ScrollArea(max_height=LEVELS_HEIGHT), inside)
        var list = ui.add(Column(gap=0), window)
        var levels = List[WidgetHandle[Button]]()
        for level in level_names():
            levels.append(
                ui.add(Button(level, variant=ButtonVariant.TEXT), list)
            )
        var count = len(level_names())
        _ = ui.add(
            ProgressBar(Float64(FINISHED) / Float64(count)),
            line(ui, levels_page, String(FINISHED, " of ", count, " done")),
            width=0,
            grow=3,
        )
        ui.visible(pages[1], False)
        ui.visible(pages[2], False)

        # the buttons, pushed to the foot of the panel whatever the page
        _ = ui.add(Space(), column, grow=1)
        var row = ui.add(Row(), column)
        var buttons = List[WidgetHandle[Button]]()
        # four equal slots: each starts from nothing and grows alike
        buttons.append(ui.add(Button("Play"), row, width=0, grow=1))
        buttons.append(
            ui.add(
                Button("Load", variant=ButtonVariant.TONAL),
                row,
                width=0,
                grow=1,
            )
        )
        buttons.append(
            ui.add(
                Button("Credits", variant=ButtonVariant.OUTLINED),
                row,
                width=0,
                grow=1,
            )
        )
        buttons.append(
            ui.add(
                Button("Quit", variant=ButtonVariant.TEXT),
                row,
                width=0,
                grow=1,
            )
        )
        var message = ui.add(Label(""), column)
        return Menu(
            ui^,
            tabs,
            pages^,
            name,
            difficulty,
            resolution,
            dark,
            music,
            levels_surface,
            levels^,
            buttons^,
            message,
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var dark = self.ui[self.dark].on
        var colors = ColorScheme.dark() if dark else ColorScheme.light()
        self.ui.colors(colors)
        self.ui[self.levels_surface].style = Style(
            fill=colors.surface_container_highest
        )
        self.ui[self.message].style = Style(
            text_color=colors.on_surface_variant
        )
        canvas.background(colors.background)

        self.ui.update(context, canvas)
        canvas.draw(self.ui)

        # show the selected tab's page
        if self.ui[self.tabs].changed():
            var selected = self.ui[self.tabs].selected
            for i in range(len(self.pages)):
                self.ui.visible(self.pages[i], i == selected)
        if self.ui[self.name].submitted():
            var name = self.ui[self.name].text()
            self.ui[self.message].text = "Hello, " + name
        if self.ui[self.difficulty].changed():
            var chosen = self.ui[self.difficulty].selected_text()
            self.ui[self.message].text = "Difficulty: " + chosen
        if self.ui[self.resolution].changed():
            var chosen = self.ui[self.resolution].selected_text()
            self.ui[self.message].text = "Resolution: " + chosen
        if self.ui[self.music].changed():
            var on = self.ui[self.music].on
            self.ui[self.message].text = "Music " + ("on" if on else "off")
        for level in self.levels:
            if self.ui[level].released():
                self.ui[self.message].text = "Level: " + self.ui[level].text
        for i in range(len(self.buttons)):
            if self.ui[self.buttons[i]].released():
                if i == len(self.buttons) - 1:
                    context.quit()
                var pressed = self.ui[self.buttons[i]].text
                self.ui[self.message].text = "Pressed " + pressed


def main() raises:
    run[Menu]("UI", width=800, height=600)
