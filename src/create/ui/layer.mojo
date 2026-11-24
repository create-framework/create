"""`UILayer`: the handle a `ui.screen` block draws widgets with."""

from std.reflection import SourceLocation, call_location

from create.color import Color
from create.core import Context
from create.geometry import Circle, Drawable, Line, Rectangle
from create.input import GamepadButton, Key
from create.image import Image
from create.math import Point, Transform, Vector, ceil, clamp, floor
from create.text import FontWeight
from create._optional import _OptionalFloat64
from create.render import (
    Align,
    Canvas,
    StrokeAlign,
    StrokeCap,
    StrokeDash,
    Style,
)
from create.render.style import _ResolvedStyle
from create.render.canvas import _View, _ViewGuard
from ._id import _mix
from ._key import _WidgetKey
from ._layout import _Layout, _COLUMN, _PANEL, _ROW
from .button import ButtonVariant
from ._text_buffer import _TextBuffer
from .text_field import TextEditor
from .colors import ColorScheme, FocusRing, _readable_on
from .ui import UI, _Hit, _Styles


comptime _PRESSED_SHADOW = Color(0, 0, 0, 45)
"""The inset shadow a pressed filled or tonal button is drawn with."""


def _body_text() -> Style:
    """The text of labels, checkboxes and text fields, unless styled."""
    return Style(font_size=16, font_weight=FontWeight.REGULAR)


def _label_text() -> Style:
    """The text on buttons, unless styled."""
    return Style(font_size=14, font_weight=FontWeight.MEDIUM)


@fieldwise_init
struct _Interaction(Copyable, ImplicitlyCopyable, Movable):
    """What the pointer did to a widget this frame."""

    var hovered: Bool
    var pressed: Bool
    """Held down with the pointer still over it: drawn pressed."""
    var clicked: Bool
    """Released over it, after being pressed on it."""
    var held: Bool
    """Held with the pointer, wherever it is, in the frames from the press
    to the release, both included."""
    var focused: Bool
    var activated: Bool
    """Enter or Space pressed while it has focus from the keyboard."""


struct UILayer[
    ui_origin: Origin[mut=True],
    context_origin: Origin[mut=True],
    canvas_origin: Origin[mut=True],
](ImplicitlyCopyable):
    """The handle a `with self.ui.screen(context, canvas) as ui:` or
    `ui.world` block gets: every widget is a method on it.

    It points at the `UI`, the context and the canvas, so a widget needs none
    of them passed, and the block can still use them, and the program's other
    fields, directly. A helper takes it as `ui: UILayer`, its parameters left
    to be inferred. Everything drawn through it is drawn when the block ends,
    in the order it was called.

    Every widget takes the rectangle it fills as `rect`. Called without
    one, inside a `ui.column` or `ui.row` block, it takes the next slot of
    the column or row instead; anywhere else, it raises.

    Every widget that reacts to the pointer takes the same three keywords:

    - `take_focus=True` gives it focus in the frame it is passed, as a click
      would; if several widgets ask in one frame, the last one called gets
      it.
    - `disabled=True` draws it faded and stops it reacting, as a
      `ui.disabled` block around it would.
    - `id=` adds a key to its ID, as a `ui.id` block around it would.
    """

    var _ui: Pointer[UI, Self.ui_origin]
    var _context: Pointer[Context, Self.context_origin]
    var _canvas: Pointer[Canvas, Self.canvas_origin]
    var _frame: Int
    var _to_local: Transform
    """Takes a screen point into the layer's space."""
    var _view: Optional[_View]
    """For a `world` layer, the camera and transform it draws through; a
    `screen` layer has none and draws in screen space."""

    def __init__(
        out self,
        *,
        ref[Self.ui_origin] _ui: UI,
        ref[Self.context_origin] _context: Context,
        ref[Self.canvas_origin] _canvas: Canvas,
        _frame: Int,
        _view: Optional[_View] = None,
    ):
        self._ui = Pointer(to=_ui)
        self._context = Pointer(to=_context)
        self._canvas = Pointer(to=_canvas)
        self._frame = _frame
        self._view = _view
        self._to_local = _view.value().to_local() if _view else Transform()

    def __enter__(self) -> Self:
        return self

    def __exit__(self) raises:
        ref ui = self._ui[]
        ui._layer_open = False
        for ref command in ui._rings.commands:
            ui._recorder.commands.append(command.copy())
        ui._rings.commands.clear()
        if self._view:
            with _ViewGuard(_canvas=self._canvas[], _view=self._view.value()):
                self._ui[]._recorder.replay(self._canvas[])
        else:
            with self._canvas[].overlay():
                self._ui[]._recorder.replay(self._canvas[])

    def draw[D: Drawable](self, shape: D, style: Style) raises:
        """Draw `shape` in `style`, in order with the layer's widgets: above
        what was drawn through the layer before it, and below what comes
        after. A plain `canvas` call inside the block draws at once, beneath
        the whole layer.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.draw(Circle((0, 0), 20), Style(fill=Color.ORANGE))
        ```
        """
        self._check_frame()
        ref recorder = self._ui[]._recorder
        recorder.style = style._resolved()
        recorder.draw(shape)

    def colors(self) -> ColorScheme:
        """The colours the widgets are drawn in here: the innermost
        `ui.colors` block's, or the layer's. A program's own widget draws in
        them to match."""
        return self._ui[]._current_colors()

    def colors(self, colors: ColorScheme) raises -> ColorsGuard[Self.ui_origin]:
        """Draw the widgets inside a `with` block in `colors`, such as one
        panel in the dark scheme on a light screen.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.colors(ColorScheme.dark()):
            if ui.button("Night mode", Rectangle((0, 0), 160, 48)):
                ...
        ```
        """
        self._check_frame()
        return ColorsGuard(_ui=self._ui[], _colors=colors)

    def style(
        self,
        *,
        button: Style = Style(),
        label: Style = Style(),
        panel: Style = Style(),
        slider_track: Style = Style(),
        slider_active_track: Style = Style(),
        slider_handle: Style = Style(),
        slider_handle_outline: Style = Style(),
        checkbox_box: Style = Style(),
        checkbox_checked_box: Style = Style(),
        checkbox_tick: Style = Style(),
        checkbox_label: Style = Style(),
        text_field_container: Style = Style(),
        text_field_focused: Style = Style(),
        text_field_text: Style = Style(),
        text_field_placeholder: Style = Style(),
        text_field_caret: Style = Style(),
        text_field_selection: Style = Style(),
    ) raises -> WidgetStyleGuard[Self.ui_origin]:
        """Style every widget of a kind inside a `with` block. The styles
        given sit under each call's own style and over any block outside
        this one, field by field: a field a call sets wins, and a field
        nothing sets comes from the widget's defaults.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.style(button=Style(corner_radius=4)):
            if ui.button("Square", Rectangle((0, 0), 120, 40)):
                ...
            if ui.button(
                "Round",
                Rectangle((0, -50), 120, 40),
                style=Style(corner_radius=20),
            ):
                ...
        ```
        """
        self._check_frame()
        return WidgetStyleGuard(
            _ui=self._ui[],
            _styles=_Styles(
                button,
                label,
                panel,
                slider_track,
                slider_active_track,
                slider_handle,
                slider_handle_outline,
                checkbox_box,
                checkbox_checked_box,
                checkbox_tick,
                checkbox_label,
                text_field_container,
                text_field_focused,
                text_field_text,
                text_field_placeholder,
                text_field_caret,
                text_field_selection,
            ),
        )

    def content_color(self) -> Color:
        """The colour for text here: the innermost panel's content colour, or
        the colours' `on_surface`. A program's own widget draws its text in it
        to match the built-in ones."""
        return self._ui[]._content_color()

    @always_inline
    def panel(
        self,
        rect: Rectangle,
        *,
        style: Style = Style(),
        id: _WidgetKey = None,
    ) raises -> PanelGuard[Self.ui_origin]:
        """A surface filling `rect`, drawn beneath everything called inside
        its `with` block. Text on it takes its content colour, so a label on
        a dark panel turns light without being told, and it covers what is
        beneath it from the pointer. It doesn't place what is inside it.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.panel(Rectangle((0, 0), 320, 120)):
            ui.label("Volume", Rectangle((0, 30), 280, 24))
            ui.slider(self.volume, 0, 1, Rectangle((0, -15), 280, 32))
        ```
        """
        return self._panel(
            self._widget_id(call_location(), id._hash), rect, style
        )

    def _panel(
        self, id: UInt64, rect: Rectangle, style: Style
    ) raises -> PanelGuard[Self.ui_origin]:
        ref ui = self._ui[]
        var colors = ui._current_colors()
        # a surface the pointer can't reach through, nor focus
        ui._hits.append(_Hit(id, rect, self._to_local, False, False, False))
        var look = style.over(ui._current_styles().panel).over(
            Style(
                fill=colors.surface_container,
                stroke_enabled=False,
                corner_radius=self._ui[]._corner_radius,
            )
        )
        var resolved = _ResolvedStyle()
        resolved.apply(look)
        var surface = (
            resolved.fill_color if resolved.fill_enabled else colors.surface
        )
        var content = look.text_color.or_else(_content_on(colors, surface))
        ui._recorder.style = resolved
        ui._recorder.draw(
            Rectangle(
                rect.position,
                rect.width,
                rect.height,
                corner_radius=resolved.corner_radius,
            )
        )
        ui._called(changed=False)
        return PanelGuard(_ui=ui, _content=content, _rect=rect)

    def id[K: Hashable](self, key: K) raises -> IDGuard[Self.ui_origin]:
        """Add `key` to the ID of every widget inside a `with` block, so a
        widget keeps its state when the items around it are reordered or
        removed.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        for player in self.players:
            with ui.id(player.name):
                ...
        ```
        """
        self._check_frame()
        return IDGuard(_ui=self._ui[], _key=UInt64(hash(key)))

    # ------------------------------------------------------------- layout

    def column(
        self,
        rect: Optional[Rectangle] = None,
        *,
        gap: _OptionalFloat64 = None,
    ) raises -> LayoutGuard[Self.ui_origin]:
        """A column filling `rect`: every widget called inside its `with`
        block without a rect of its own is placed in it, one under the
        other, from the top down, each across the column's whole width.
        `gap`, the UI's `spacing` unless given, is left between each
        and the next.

        A widget's height is the UI's `control_height`, or for a label,
        one and a half times its text's size. Without a `rect`, the column
        fills what is around it: a panel, inset by twice the UI's `spacing`,
        the rest of a column, or the next slot of a row.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.panel(Rectangle((0, 0), 320, 200)):
            with ui.column():
                ui.label("Volume")
                ui.slider(self.volume, 0, 1)
                if ui.button("Done"):
                    self.close_settings()
        ```
        """
        self._check_frame()
        var area: Rectangle
        if rect:
            area = rect.value()
        else:
            ref layouts = self._ui[]._layouts
            if not layouts:
                raise Error(
                    "ui.column: give it a rect, or open it inside a"
                    + " ui.panel, ui.column or ui.row"
                )
            ref around = layouts[len(layouts) - 1]
            if around.kind == _PANEL:
                area = around.rect.inset(2 * self._ui[]._spacing)
            else:
                area = around.take_rest("ui.column")
        return LayoutGuard(
            _ui=self._ui[],
            _layout=_Layout(_COLUMN, area, gap.or_else(self._ui[]._spacing)),
        )

    def row(
        self,
        *weights: Float64,
        columns: Optional[Int] = None,
        rect: Optional[Rectangle] = None,
        gap: _OptionalFloat64 = None,
        height: _OptionalFloat64 = None,
    ) raises -> LayoutGuard[Self.ui_origin]:
        """A row cut into slots side by side, one for each weight, or
        `columns` equal ones: every widget called inside its `with` block
        without a rect of its own takes the next slot, from the left. The
        slots share the row's width in proportion to their weights, so
        `ui.row(1, 3)` gives the first a quarter of it and the second three
        quarters. `gap`, the UI's `spacing` unless given, is left
        between each slot and the next. A widget called once every slot is
        taken raises.

        The row fills `rect`. Without one, it is the next strip of the column
        around it, `height` tall (the UI's `control_height` unless given),
        the next slot of a row, or the inside of a panel.

        ```mojo
        # In `update`, inside a `ui.column` block:
        with ui.row(1, 3):
            ui.label("Volume", alignment=Align.LEFT)
            ui.slider(self.volume, 0, 1)
        with ui.row(columns=2):
            if ui.button("OK"):
                ...
            if ui.button("Cancel"):
                ...
        ```
        """
        self._check_frame()
        var shares = List[Float64]()
        for weight in weights:
            shares.append(weight)
        if columns:
            if shares:
                raise Error("ui.row: give it weights or columns=, not both")
            for _ in range(columns.value()):
                shares.append(1.0)
        elif not shares:
            raise Error(
                "ui.row: give it the weights of its slots, as in"
                + " ui.row(1, 3), or how many equal ones, as in"
                + " ui.row(columns=4)"
            )
        var area: Rectangle
        if rect:
            area = rect.value()
        else:
            ref layouts = self._ui[]._layouts
            if not layouts:
                raise Error(
                    "ui.row: give it a rect, or open it inside a ui.panel,"
                    + " ui.column or ui.row"
                )
            ref around = layouts[len(layouts) - 1]
            if around.kind == _PANEL:
                area = around.rect.inset(2 * self._ui[]._spacing)
            else:
                area = around.take(
                    height.or_else(self._ui[]._control_height), "ui.row"
                )
        var spacing = gap.or_else(self._ui[]._spacing)
        return LayoutGuard(
            _ui=self._ui[],
            _layout=_Layout(
                _ROW,
                area,
                spacing,
                area.columns(weights=shares, gap=spacing),
            ),
        )

    def space(self, amount: _OptionalFloat64 = None) raises:
        """Leave `amount` of the column around it empty, twice the UI's
        `spacing` unless given, such as to set one group of widgets apart from
        the next. It raises outside a `ui.column`."""
        self._check_frame()
        ref layouts = self._ui[]._layouts
        if not layouts:
            raise Error("ui.space: call it inside a ui.column")
        layouts[len(layouts) - 1].space(amount.or_else(2 * self._ui[]._spacing))

    def _place(
        self, rect: Optional[Rectangle], height: Float64, what: String
    ) raises -> Rectangle:
        """Where a widget named `what` goes: `rect` when it is given, or the
        next slot of the column or row around it, `height` tall in a
        column."""
        if rect:
            return rect.value()
        ref layouts = self._ui[]._layouts
        if not layouts:
            raise Error(
                what
                + ": give it a rect, or call it inside a ui.column or ui.row"
            )
        return layouts[len(layouts) - 1].take(height, what)

    def _place_control(
        self, rect: Optional[Rectangle], what: String
    ) raises -> Rectangle:
        """`_place` for a control: `control_height` tall in a column."""
        return self._place(rect, self._ui[]._control_height, what)

    # ------------------------------------------------------------ widgets

    @always_inline
    def button(
        self,
        text: String,
        rect: Optional[Rectangle] = None,
        *,
        variant: ButtonVariant = ButtonVariant.FILLED,
        style: Style = Style(),
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises -> Bool:
        """A button showing `text`, filling `rect`. Returns whether it was
        clicked this frame: pressed and released with the pointer over it.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        if ui.button("Play", Rectangle((0, 0), 160, 48)):
            self.start()
        ```
        """
        return self._button(
            self._widget_id(call_location(), id._hash),
            text,
            self._place_control(rect, "ui.button"),
            variant,
            style,
            take_focus,
            disabled,
        )

    def label(
        self,
        text: String,
        rect: Optional[Rectangle] = None,
        *,
        alignment: Align = Align.CENTER,
        style: Style = Style(),
    ) raises:
        """Text placed in `rect`, by `alignment`: in its centre unless given,
        against its left edge with `Align.LEFT`, and so on. It reacts to
        nothing, so the pointer passes through it to what is beneath.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.label("Volume", Rectangle((0, 40), 240, 24), alignment=Align.LEFT)
        ```
        """
        self._check_frame()
        var look = style.over(self._ui[]._current_styles().label).over(
            Style(text_color=self._ui[]._content_color()).over(_body_text())
        )
        var place = self._place(rect, _size(look) * 1.5, "ui.label")
        var resolved = _ResolvedStyle()
        resolved.apply(look)
        resolved.text_alignment = alignment
        self._ui[]._recorder.text(text, _anchor(place, alignment), resolved)
        self._ui[]._called(changed=False)

    def image(self, image: Image, rect: Optional[Rectangle] = None) raises:
        """`image` stretched to fill `rect`. Like a label, it reacts to
        nothing."""
        self._check_frame()
        var place = self._place_control(rect, "ui.image")
        self._ui[]._recorder.image(
            image, place.position, place.width, place.height, _ResolvedStyle()
        )
        self._ui[]._called(changed=False)

    @always_inline
    def slider(
        self,
        mut value: Float64,
        min: Float64,
        max: Float64,
        rect: Optional[Rectangle] = None,
        *,
        step: _OptionalFloat64 = None,
        track: Style = Style(),
        active_track: Style = Style(),
        handle: Style = Style(),
        handle_outline: Style = Style(),
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises:
        """A slider across `rect` that sets `value` between `min` and `max`.
        `ui.changed()`, right after it, says whether it changed `value` this
        frame.

        Pressing anywhere in `rect` moves the handle there, and dragging
        moves it on, even once the pointer leaves `rect`. `step` rounds the
        value to multiples of it from `min`, and must be more than 0. A
        `value` outside `min` to `max` is drawn at the nearer end, and left
        as it is until dragged.

        Each part is a shape drawn in its own `Style`: `track` is a line, so
        its `stroke` and `stroke_thickness` are the track's colour and
        thickness; `active_track` is the line from the start to the handle,
        drawn over `track` and taking what it leaves unset from it; `handle`
        is a point, so its `stroke` is the handle's colour and its
        `stroke_thickness` its diameter (`StrokeCap.SQUARE` makes it square);
        and `handle_outline` is a circle round the handle, drawn on top when
        it sets a stroke or a fill.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.slider(self.volume, 0, 1, Rectangle((0, 0), 240, 32))
        if ui.changed():
            self.audio.volume(self.volume)
        ```
        """
        self._slider(
            self._widget_id(call_location(), id._hash),
            value,
            min,
            max,
            self._place_control(rect, "ui.slider"),
            step._value,
            track,
            active_track,
            handle,
            handle_outline,
            take_focus,
            disabled,
        )

    @always_inline
    def checkbox(
        self,
        label: String,
        mut checked: Bool,
        rect: Optional[Rectangle] = None,
        *,
        box: Style = Style(),
        checked_box: Style = Style(),
        tick: Style = Style(),
        label_style: Style = Style(),
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises:
        """A box against the left edge of `rect`, ticked while `checked` is
        `True`, with `label` beside it. A click anywhere in `rect` switches
        `checked`. `ui.changed()`, right after it, says whether it changed
        `checked` this frame.

        Each part is a shape drawn in its own `Style`: `box` is the empty
        box, a rectangle, an outline unless its style fills it;
        `checked_box` is the ticked box, filled, taking what it leaves unset
        from `box`, such as its corner radius; `tick` is the lines of the
        tick, so its `stroke` and `stroke_thickness` are their colour and
        width; and `label_style` is the text beside the box.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.checkbox("Sound", self.sound_on, Rectangle((0, 0), 200, 32))
        if ui.changed():
            self.save_settings()
        ```
        """
        self._checkbox(
            self._widget_id(call_location(), id._hash),
            label,
            checked,
            self._place_control(rect, "ui.checkbox"),
            box,
            checked_box,
            tick,
            label_style,
            take_focus,
            disabled,
        )

    @always_inline
    def text_field(
        self,
        mut text: String,
        rect: Optional[Rectangle] = None,
        *,
        placeholder: String = "",
        max_length: Optional[Int] = None,
        container: Style = Style(),
        focused: Style = Style(),
        text_style: Style = Style(),
        placeholder_style: Style = Style(),
        caret: Style = Style(),
        selection: Style = Style(),
        padding: _OptionalFloat64 = None,
        take_focus: Bool = False,
        disabled: Bool = False,
        id: _WidgetKey = None,
    ) raises:
        """A field for typing into `text`, filling `rect`. Clicking it gives
        it focus and places the caret; while it has focus, typing and the
        editing keys change `text`, and Enter submits it.

        Right after it, `ui.changed()` says whether it changed `text` this
        frame, `ui.submitted()` whether Enter was pressed in it, and
        `ui.text_editor()` gives its caret and selection. `placeholder` is
        shown in a fainter colour while `text` is empty, and `max_length`
        caps how many characters typing and pasting can bring it to.

        Each part is drawn in its own `Style`: `container` is the field, a
        rectangle, and `focused` is layered over it while the field has
        focus (by default its outline turns `primary` and twice as thick);
        `text_style` is the typed text and `placeholder_style` the
        placeholder, which takes what it leaves unset from `text_style`;
        `caret` is a line, so its `stroke` and `stroke_thickness` are the
        caret's colour and width; and `selection` is the rectangle behind
        selected text. `padding`, 12 unless given, is the gap between the
        field's sides and its text.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`,
        # with a `name: String` field:
        ui.text_field(
            self.name, Rectangle((0, 0), 320, 40), placeholder="Your name"
        )
        if ui.submitted():
            self.start_game(self.name)
        ```
        """
        self._text_field(
            self._widget_id(call_location(), id._hash),
            text,
            self._place_control(rect, "ui.text_field"),
            placeholder,
            max_length,
            container,
            focused,
            text_style,
            placeholder_style,
            caret,
            selection,
            padding.or_else(12.0),
            take_focus,
            disabled,
        )

    # ---------------------------------------------- the widget called last

    def changed(self) -> Bool:
        """Whether the widget called last changed its value this frame: a
        slider its `value`, a checkbox its `checked`, a text field its
        `text`. It is `False` after a button, a label, an image or a panel,
        and before any widget is called.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.slider(self.volume, 0, 1, Rectangle((0, 0), 240, 32))
        if ui.changed():
            self.audio.volume(self.volume)
        ```
        """
        return self._ui[]._last_changed

    def submitted(self) -> Bool:
        """Whether Enter was pressed this frame in the widget called last,
        a text field. It is `False` after any other widget.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.text_field(self.name, Rectangle((0, 0), 320, 40))
        if ui.submitted():
            self.start_game(self.name)
        ```
        """
        return self._ui[]._last_submitted

    def text_editor(
        self,
    ) raises -> TextEditor[Self.ui_origin, Self.context_origin]:
        """The caret, the selection and the editing of the widget called
        last, which must be a text field. It raises after any other widget.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`,
        # with a `name: String` field:
        ui.text_field(self.name, Rectangle((0, 0), 320, 40))
        var editor = ui.text_editor()
        var caret = editor.before_caret()  # the text left of the caret
        ```
        """
        self._check_frame()
        ref ui = self._ui[]
        if not ui._last_text_field:
            raise Error(
                "ui.text_editor() needs a text field to be the widget called"
                " just before it"
            )
        return TextEditor(
            _ui=ui,
            _context=self._context[],
            _id=ui._last_text_field.value(),
        )

    # ----------------------------------------------------------- internals

    def _text_field(
        self,
        id: UInt64,
        mut text: String,
        rect: Rectangle,
        placeholder: String,
        max_length: Optional[Int],
        call_container: Style,
        call_focused: Style,
        call_text: Style,
        call_placeholder: Style,
        call_caret: Style,
        call_selection: Style,
        padding: Float64,
        take_focus: Bool,
        disabled: Bool,
    ) raises:
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus, takes_typing=True)
        ref ui = self._ui[]
        ui._sync_text_input(self._context[])
        var colors = ui._current_colors()
        if id not in ui._buffers:
            ui._buffers[id] = _TextBuffer(text)
        var changed = False
        var submitted = False
        ref buffer = ui._buffers[id]
        # an edit through `ui.text_editor` since the last call is handed to
        # `text` below; otherwise the program's text is what the field shows
        if buffer.edited:
            buffer.edited = False
        else:
            buffer.text = text
        buffer.max_length = max_length
        var now = self._context[].time.elapsed
        var block = ui._current_styles()
        var text_look = call_text.over(block.text_field_text).over(
            Style(text_color=colors.on_surface).over(_body_text())
        )
        var typed = _ResolvedStyle()
        typed.apply(text_look)
        var hint = _ResolvedStyle()
        hint.apply(
            call_placeholder.over(block.text_field_placeholder).over(
                Style(text_color=colors.on_surface_variant).over(text_look)
            )
        )
        var look = _text_look(typed, Align.LEFT)
        var left = rect.position.x - rect.width / 2 + padding
        var inner = rect.width - 2 * padding

        # a press places the caret under the pointer
        if state.hovered and self._context[].mouse.pressed():
            var typed = buffer.text  # a copy: measuring borrows the layer
            var pointer = self._to_local.apply(self._context[].mouse.position)
            buffer._place(
                self._offset_at(typed, pointer.x - left + buffer.scroll, look),
                select=False,
            )
            buffer.last_change = now
        if state.focused and self._keyboard_free():
            var before = buffer.text
            var caret = buffer.before_caret()
            buffer.update(self._context[])
            if buffer.text != before or buffer.before_caret() != caret:
                buffer.last_change = now
            submitted = self._context[].keyboard.pressed(Key.ENTER)
        if buffer.text != text:
            text = buffer.text
            changed = True

        # keep the caret inside the field while it has focus; without focus,
        # show the text from its start
        var caret_x = self._measure(buffer.before_caret(), look)
        if not state.focused:
            buffer.scroll = 0
        elif caret_x - buffer.scroll > inner:
            buffer.scroll = caret_x - inner
        elif caret_x - buffer.scroll < 0:
            buffer.scroll = caret_x
        var shown = buffer.text
        var whole = self._measure(shown, look)
        buffer.scroll = min(buffer.scroll, max(0.0, whole - inner))

        # the field
        var container_look = call_container.over(
            block.text_field_container
        ).over(
            Style(
                fill=colors.surface_container_highest,
                stroke=colors.outline,
                stroke_thickness=1,
                corner_radius=self._ui[]._corner_radius / 4,
            )
        )
        var field = _ResolvedStyle()
        field.apply(container_look)
        if state.focused and not off:
            # by default, the outline turns `primary` and twice as thick,
            # and a field with no outline stays without one
            var outlined = Style()
            if field.stroke_enabled:
                outlined = Style(
                    stroke=colors.primary,
                    stroke_thickness=field.stroke_thickness * 2,
                )
            field = _ResolvedStyle()
            field.apply(
                call_focused.over(block.text_field_focused)
                .over(outlined)
                .over(container_look)
            )
        if off:
            var states = self._ui[]._state_layers
            # the field's own colours, faded: the colours' text colour by
            # default, and a transparent one stays transparent
            typed.text_color = _faded(typed.text_color, states.disabled_content)
            hint.text_color = _faded(hint.text_color, states.disabled_content)
            if _fills(field):
                field.fill_color = _faded(
                    colors.on_surface, states.disabled_container
                )
                field.fill_gradient = None
            field.stroke_color = _faded(
                colors.on_surface, states.disabled_container
            )
        elif (
            state.hovered
            and not state.focused
            and _fills(field)
            and not field.fill_gradient
        ):
            field.fill_color = _stepped(
                field.fill_color,
                colors.on_surface,
                self._ui[]._state_layers.hovered,
            )
        var shape = Rectangle(
            rect.position,
            rect.width,
            rect.height,
            corner_radius=field.corner_radius,
        )
        ref recorder = ui._recorder
        if _fills(field) or (
            field.stroke_enabled and field.stroke_thickness > 0
        ):
            recorder.style = field
            recorder.draw(shape)

        # the text, clipped to the inside of the field
        recorder.clip(
            Rectangle(rect.position, rect.width - padding, rect.height)
        )
        var origin_x = left - buffer.scroll
        var y = rect.position.y
        if state.focused and buffer.selected_text():
            var start = self._measure(buffer.before_selection(), look)
            var width = self._measure(buffer.selected_text(), look)
            var highlight = _ResolvedStyle()
            highlight.apply(
                call_selection.over(block.text_field_selection).over(
                    Style(
                        fill=colors.primary.with_alpha(70), stroke_enabled=False
                    )
                )
            )
            recorder.style = highlight
            recorder.draw(
                Rectangle(
                    Point(origin_x + start + width / 2, y),
                    width,
                    typed.font_size * 1.3,
                )
            )
        if buffer.text:
            recorder.text(
                buffer.text,
                Point(origin_x, y),
                _text_look(typed, Align.LEFT),
            )
        elif placeholder:
            recorder.text(
                placeholder,
                Point(left, y),
                _text_look(hint, Align.LEFT),
            )
        # the caret: steady for a moment after a change, then blinking
        var since = now - buffer.last_change
        if (
            state.focused
            and not off
            and (since < 0.5 or Int(since * 2) % 2 == 1)
        ):
            var x = origin_x + caret_x
            var bar = _ResolvedStyle()
            bar.apply(
                call_caret.over(block.text_field_caret).over(
                    Style(stroke=colors.primary, stroke_thickness=2)
                )
            )
            recorder.style = bar
            recorder.draw(
                Line(
                    Point(x, y - typed.font_size * 0.65),
                    Point(x, y + typed.font_size * 0.65),
                )
            )
        recorder.end_clip()
        ui._called(changed=changed, submitted=submitted, text_field=id)

    def _ring_around(
        self,
        shape: Rectangle,
        state: _Interaction,
        disabled: Bool,
    ):
        """Draw the focus ring around `shape`, its corners rounded by the
        shape's own radius grown by the gap, while the widget has focus from
        the keyboard or code."""
        if not self._shows_ring(state, disabled):
            return
        var look = self._ui[]._focus_ring
        var gap = look.gap
        self._record_ring(
            Rectangle(
                shape.position,
                shape.width + 2 * gap,
                shape.height + 2 * gap,
                corner_radius=shape.corner_radius + gap,
            ),
            look,
        )

    def _ring_around(
        self,
        shape: Circle,
        state: _Interaction,
        disabled: Bool,
    ):
        if not self._shows_ring(state, disabled):
            return
        var look = self._ui[]._focus_ring
        self._record_ring(Circle(shape.position, shape.radius + look.gap), look)

    def _shows_ring(self, state: _Interaction, disabled: Bool) -> Bool:
        return state.focused and self._ui[]._focus_visible and not disabled

    def _record_ring[S: Drawable](self, shape: S, look: FocusRing):
        ref ui = self._ui[]
        ui._rings.style = _ResolvedStyle(
            fill_enabled=False,
            stroke=look.color.or_else(ui._current_colors().secondary),
            stroke_thickness=look.thickness,
            stroke_alignment=StrokeAlign.OUTSIDE,
        )
        ui._rings.draw(shape)

    def _measure(self, text: String, look: _ResolvedStyle) raises -> Float64:
        """How wide `text` is drawn in `look`'s font, size and weight."""
        if not text:
            return 0
        with self._canvas[]._with_style(look):
            return self._canvas[].text_width(text)

    def _offset_at(
        self, text: String, x: Float64, look: _ResolvedStyle
    ) raises -> Int:
        """The byte offset of the character boundary in `text` nearest to
        `x` units from its start."""
        var best = 0
        var best_distance = abs(x)
        var prefix = String()
        var offset = 0
        for character in text.codepoint_slices():
            prefix += character
            offset += character.byte_length()
            var distance = abs(x - self._measure(prefix, look))
            if distance < best_distance:
                best = offset
                best_distance = distance
        return best

    def _button(
        self,
        id: UInt64,
        text: String,
        rect: Rectangle,
        variant: ButtonVariant,
        call_style: Style,
        take_focus: Bool,
        disabled: Bool,
    ) raises -> Bool:
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus)
        var colors = self._ui[]._current_colors()
        var look = call_style.over(self._ui[]._current_styles().button).over(
            _variant_look(variant, colors).over(_label_text())
        )
        var resolved = _ResolvedStyle()
        resolved.apply(look)
        if off:
            # Material's disabled look: everything in the text colour,
            # faded, whatever the variant
            var states = self._ui[]._state_layers
            resolved.text_color = _faded(
                colors.on_surface, states.disabled_content
            )
            if _fills(resolved):
                resolved.fill_color = _faded(
                    colors.on_surface, states.disabled_container
                )
                resolved.fill_gradient = None
            if resolved.stroke_enabled:
                resolved.stroke_color = _faded(
                    colors.on_surface, states.disabled_container
                )
        var radius = look.corner_radius.or_else(rect.height / 2)
        var shape = Rectangle(
            rect.position, rect.width, rect.height, corner_radius=radius
        )
        ref recorder = self._ui[]._recorder
        # a hovered or pressed button steps its fill's lightness towards its
        # text
        var step = 0.0
        if state.pressed:
            step = self._ui[]._state_layers.pressed
        elif state.hovered:
            step = self._ui[]._state_layers.hovered
        var solid = _fills(resolved) and not resolved.fill_gradient
        if step > 0 and solid:
            resolved.fill_color = _stepped(
                resolved.fill_color, resolved.text_color, step
            )
        if _fills(resolved) or resolved.stroke_enabled:
            recorder.style = resolved
            if state.pressed and _fills(resolved):
                # pressed in: a soft shadow along the inside of the top edge
                recorder.style.shadow_color = _PRESSED_SHADOW
                recorder.style.shadow_offset = Vector(0, -2)
                recorder.style.shadow_blur = 4
                recorder.style.shadow_spread = 0
                recorder.style.shadow_inset = True
                recorder.style.shadow_enabled = True
            recorder.draw(shape)
        if step > 0 and not solid:
            # no solid fill to step: a layer of the text colour, as strong as
            # the step would be over the surface beneath
            var opacity = _layer_opacity(
                colors.surface, resolved.text_color, step
            )
            recorder.style = _ResolvedStyle(
                fill=resolved.text_color.with_alpha(UInt8(opacity * 255 + 0.5)),
                stroke_enabled=False,
            )
            recorder.draw(shape)
        self._ring_around(shape, state, off)
        recorder.text(text, rect.position, _text_look(resolved, Align.CENTER))
        self._ui[]._called(changed=False)
        return state.clicked or state.activated

    def _slider(
        self,
        id: UInt64,
        mut value: Float64,
        min: Float64,
        max: Float64,
        rect: Rectangle,
        step: Optional[Float64],
        call_track: Style,
        call_active_track: Style,
        call_handle: Style,
        call_handle_outline: Style,
        take_focus: Bool,
        disabled: Bool,
    ) raises:
        if step and not step.value() > 0:  # NaN included
            raise Error(
                "ui.slider: step must be more than 0, not "
                + String(step.value())
            )
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus, adjusts=True)
        ref ui = self._ui[]
        var colors = ui._current_colors()
        var block = ui._current_styles()
        var track_look = call_track.over(block.slider_track).over(
            Style(
                stroke=colors.secondary_container,
                stroke_thickness=4,
                stroke_cap=StrokeCap.ROUND,
            )
        )
        var track = _ResolvedStyle()
        track.apply(track_look)
        var active = _ResolvedStyle()
        active.apply(
            call_active_track.over(block.slider_active_track).over(
                Style(stroke=colors.primary).over(track_look)
            )
        )
        var handle = _ResolvedStyle()
        handle.apply(
            call_handle.over(block.slider_handle).over(
                Style(stroke=colors.primary, stroke_thickness=20)
            )
        )
        var outline = _ResolvedStyle()
        outline.apply(
            call_handle_outline.over(block.slider_handle_outline).over(
                Style(fill_enabled=False, stroke_enabled=False)
            )
        )
        var knob_radius = handle.stroke_thickness / 2
        var left = rect.position.x - rect.width / 2 + knob_radius
        var right = rect.position.x + rect.width / 2 - knob_radius
        var y = rect.position.y
        var dragging = state.held  # the frame it is let go of included
        var changed = False
        if dragging and right > left and max != min:
            var pointer = self._to_local.apply(self._context[].mouse.position)
            var t = clamp((pointer.x - left) / (right - left), 0.0, 1.0)
            var new_value = min + t * (max - min)
            if step:
                var size = step.value()
                new_value = (
                    min + Float64(round((new_value - min) / size)) * size
                )
                if (max - min) * (new_value - max) > 0:
                    # a step past `max` comes back inside, towards `min`
                    new_value -= size if max > min else -size
            if new_value != value:
                value = new_value
                changed = True
        var keys = self._keys_act(state.focused)
        var pad = state.focused and ui._focus_visible and ui._pad_move.x != 0
        if (keys or pad) and max != min:
            ref keyboard = self._context[].keyboard
            # a step, or a twentieth of the range
            var size = step.value() if step else abs(max - min) / 20
            if max < min:
                size = -size  # steps count from `min` towards `max`
            var low = min if min < max else max
            var high = max if min < max else min
            # Steps land on the grid of steps counted from `min`, so they
            # don't gather floating-point error: 1.0 stepped down by 0.05
            # twice is 0.9, not 0.8999999999999999.
            var steps_from_min = (value - min) / size
            var moved = value
            var towards_max = 0
            if pad:
                towards_max = 1 if ui._pad_move.x > 0 else -1
            elif keyboard.typed(Key.RIGHT) or keyboard.typed(Key.UP):
                towards_max = 1
            elif keyboard.typed(Key.LEFT) or keyboard.typed(Key.DOWN):
                towards_max = -1
            if towards_max != 0:
                # the next step along, so a value between two steps moves to
                # the one ahead of it rather than past it
                var nearest = Float64(round(steps_from_min))
                if abs(steps_from_min - nearest) < 1e-9:
                    steps_from_min = nearest  # on a step, give or take error
                var next: Float64
                if towards_max > 0:
                    next = floor(steps_from_min) + 1
                else:
                    next = ceil(steps_from_min) - 1
                moved = min + next * size
            elif keyboard.pressed(Key.HOME):
                moved = min
            elif keyboard.pressed(Key.END):
                moved = max
            if moved != value:
                if keys:
                    self._ui[]._key_used = True
                moved = low if moved < low else (
                    high if moved > high else moved
                )
                if moved != value:
                    value = moved
                    changed = True
        var t = 0.0
        if max != min:
            t = clamp((value - min) / (max - min), 0.0, 1.0)
        var handle_x = left + t * (right - left)
        if off:
            var states = self._ui[]._state_layers
            active.stroke_color = _faded(
                colors.on_surface, states.disabled_content
            )
            track.stroke_color = _faded(
                colors.on_surface, states.disabled_container
            )
            # solid, so the track doesn't show through it
            handle.stroke_color = colors.surface.lerp(
                colors.on_surface, states.disabled_content
            )
        ref recorder = ui._recorder
        recorder.style = track
        recorder.draw(Line(Point(left, y), Point(right, y)))
        if handle_x > left:
            recorder.style = active
            recorder.draw(Line(Point(left, y), Point(handle_x, y)))
        # a hovered or dragged handle is tinted, as a button is
        var tint = _readable_on(handle.stroke_color)
        if dragging:
            handle.stroke_color = _stepped(
                handle.stroke_color, tint, self._ui[]._state_layers.dragged
            )
        elif state.hovered:
            handle.stroke_color = _stepped(
                handle.stroke_color, tint, self._ui[]._state_layers.hovered
            )
        # a point, as `canvas.point` draws one: round unless square, and
        # never dashed
        if handle.stroke_cap != StrokeCap.SQUARE:
            handle.stroke_cap = StrokeCap.ROUND
        handle.stroke_dash = StrokeDash.SOLID
        var centre = Point(handle_x, y)
        recorder.style = handle
        recorder.draw(Line(centre, centre))
        var knob = Circle(centre, knob_radius)
        if outline.fill_enabled or outline.stroke_enabled:
            recorder.style = outline
            recorder.draw(knob)
        self._ring_around(knob, state, off)
        self._ui[]._called(changed=changed)

    def _checkbox(
        self,
        id: UInt64,
        label: String,
        mut checked: Bool,
        rect: Rectangle,
        call_box: Style,
        call_checked_box: Style,
        call_tick: Style,
        call_label: Style,
        take_focus: Bool,
        disabled: Bool,
    ) raises:
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus)
        if state.clicked or state.activated:
            checked = not checked
        var colors = self._ui[]._current_colors()
        var block = self._ui[]._current_styles()
        var box_look = call_box.over(block.checkbox_box).over(
            Style(
                fill_enabled=False,
                stroke=colors.on_surface_variant,
                stroke_thickness=2,
                corner_radius=self._ui[]._corner_radius / 8,
            )
        )
        var look = _ResolvedStyle()
        if checked:
            look.apply(
                call_checked_box.over(block.checkbox_checked_box).over(
                    Style(fill=colors.primary, stroke_enabled=False).over(
                        box_look
                    )
                )
            )
        else:
            look.apply(box_look)
        var tick = _ResolvedStyle()
        tick.apply(
            call_tick.over(block.checkbox_tick).over(
                Style(
                    stroke=colors.on_primary,
                    stroke_thickness=2,
                    stroke_cap=StrokeCap.ROUND,
                )
            )
        )
        var text = _ResolvedStyle()
        text.apply(
            call_label.over(block.checkbox_label).over(
                Style(text_color=self._ui[]._content_color()).over(_body_text())
            )
        )
        comptime size = 18.0
        var left = rect.position.x - rect.width / 2
        # the box against the left edge, the label a gap after it
        var centre = Point(left + size / 2, rect.position.y)
        var box = Rectangle(
            centre, size, size, corner_radius=look.corner_radius
        )
        if off:
            var faded = _faded(
                colors.on_surface, self._ui[]._state_layers.disabled_content
            )
            if _fills(look):
                look.fill_color = faded
                look.fill_gradient = None
            look.stroke_color = faded
            tick.stroke_color = colors.surface
            text.text_color = faded
        # a hovered or pressed box is tinted, as a button is: a filled one
        # towards its tick, an empty one with the text colour inside it
        var step = 0.0
        if state.pressed:
            step = self._ui[]._state_layers.pressed
        elif state.hovered:
            step = self._ui[]._state_layers.hovered
        if step > 0:
            if _fills(look) and not look.fill_gradient:
                look.fill_color = _stepped(
                    look.fill_color, tick.stroke_color, step
                )
            elif not _fills(look):
                var layer = _layer_opacity(
                    colors.surface, colors.on_surface, step
                )
                look.fill_color = colors.on_surface.with_alpha(
                    UInt8(layer * 255 + 0.5)
                )
                look.fill_gradient = None
                look.fill_enabled = True
        ref recorder = self._ui[]._recorder
        recorder.style = look
        recorder.draw(box)
        if checked:
            recorder.style = tick
            var corner = centre + Vector(-1.5, -4.0)
            recorder.draw(Line(centre + Vector(-5.0, 0.5), corner))
            recorder.draw(Line(corner, centre + Vector(5.0, 5.0)))
        self._ring_around(box, state, off)
        var text_left = Point(left + size + 12, rect.position.y)
        recorder.text(label, text_left, _text_look(text, Align.LEFT))
        self._ui[]._called(changed=state.clicked or state.activated)

    def _interact(
        self,
        id: UInt64,
        rect: Rectangle,
        disabled: Bool,
        take_focus: Bool,
        takes_typing: Bool = False,
        adjusts: Bool = False,
    ) -> _Interaction:
        """Record that the widget `id` can be pointed at in `rect`, and work
        out what the pointer did to it. A disabled widget still covers what
        is beneath it, but nothing it does counts."""
        ref ui = self._ui[]
        ref mouse = self._context[].mouse
        ui._hits.append(
            _Hit(id, rect, self._to_local, not disabled, takes_typing, adjusts)
        )
        if disabled:
            if ui._held and ui._held.value() == id:
                ui._held = None  # disabled while held: let go of it
            if ui._focused and ui._focused.value() == id:
                ui._clear_focus()  # a disabled widget can't keep focus
            if ui._hot and ui._hot.value() == id and mouse.pressed():
                ui._clear_focus()  # a click on it is a click on no widget
            return _Interaction(False, False, False, False, False, False)
        if take_focus:
            ui._focus(id, visible=True, takes_typing=takes_typing)
        # while another widget is held, in this UI or another, this one
        # doesn't react to the pointer
        var free = (not ui._held or ui._held.value() == id) and not (
            mouse._claim.held_by_other(
                ui._claimant, self._context[].frame_count()
            )
        )
        var hovered = Bool(ui._hot) and ui._hot.value() == id and free
        if hovered and mouse.pressed():
            ui._held = id
            ui._focus(id, visible=False, takes_typing=takes_typing)
        var held = Bool(ui._held) and ui._held.value() == id
        var clicked = False
        if held and mouse.released():
            clicked = hovered
            ui._held = None
        ui._sync_claims(self._context[])
        var focused = Bool(ui._focused) and ui._focused.value() == id
        var activated = False
        if self._keys_act(focused):
            ref keyboard = self._context[].keyboard
            if keyboard.pressed(Key.ENTER) or keyboard.pressed(Key.SPACE):
                activated = True
                ui._key_used = True
        if (
            focused
            and ui._focus_visible
            and ui._pad_pressed(self._context[], GamepadButton.SOUTH)
        ):
            activated = True
        return _Interaction(
            hovered,
            held and hovered and not clicked,
            clicked,
            held,
            focused,
            activated,
        )

    def _keys_act(self, focused: Bool) -> Bool:
        """Whether keys act on a widget: it has focus from the keyboard or
        code, not a click or a gamepad, so a game's own keys still work after
        a button is clicked or reached with a pad."""
        ref ui = self._ui[]
        return (
            focused
            and ui._focus_visible
            and not ui._focus_from_gamepad
            and self._keyboard_free()
        )

    def _keyboard_free(self) -> Bool:
        """Whether no other UI holds the keyboard."""
        return not self._context[].keyboard._claim.held_by_other(
            self._ui[]._claimant, self._context[].frame_count()
        )

    def _disabled(self, disabled: Bool) -> Bool:
        """Whether a widget given `disabled` is disabled: by its own keyword,
        or by a `ui.disabled` block around it."""
        return disabled or self._ui[]._disabled_depth > 0

    def disabled(
        self, condition: Bool = True
    ) raises -> DisabledGuard[Self.ui_origin]:
        """Disable every widget inside a `with` block while `condition` is
        true: they are drawn faded, don't react to the pointer, and return
        `False`. With `condition` false, the block's widgets work as usual,
        so a section can be switched on and off without an `if` around each
        widget.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.disabled(not self.online):
            if ui.button("Find a game", Rectangle((0, 0), 200, 48)):
                ...
        ```
        """
        self._check_frame()
        return DisabledGuard(_ui=self._ui[], _active=condition)

    def _check_frame(self) raises:
        """Raise when the handle is used after the frame it was opened in."""
        if self._context[].frame_count() != self._frame:
            raise Error(
                "UILayer: used in frame "
                + String(self._context[].frame_count())
                + ", but opened in frame "
                + String(self._frame)
                + "; open a new layer with `ui.screen` or `ui.world` every"
                + " frame"
            )

    def _widget_id(
        self, location: SourceLocation, key: Optional[UInt64] = None
    ) raises -> UInt64:
        """The ID of a widget called from `location`; see `UI._widget_id`."""
        self._check_frame()
        return self._ui[]._widget_id(location, key)


struct IDGuard[origin: Origin[mut=True]](Movable):
    """Takes the key `ui.id` added off the widget IDs again, on scope exit.
    Only `ui.id` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, _key: UInt64):
        var parent = _ui._keys[len(_ui._keys) - 1] if _ui._keys else 0
        _ui._keys.append(_mix(parent, _key))
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._keys.pop()


def _anchor(rect: Rectangle, alignment: Align) -> Point:
    """The point of `rect` that text placed by `alignment` is anchored to:
    its centre, or the middle of the edge or the corner `alignment` names."""
    var x = rect.position.x
    var y = rect.position.y
    if (
        alignment == Align.LEFT
        or alignment == Align.TOP_LEFT
        or alignment == Align.BOTTOM_LEFT
    ):
        x -= rect.width / 2
    elif (
        alignment == Align.RIGHT
        or alignment == Align.TOP_RIGHT
        or alignment == Align.BOTTOM_RIGHT
    ):
        x += rect.width / 2
    if (
        alignment == Align.TOP
        or alignment == Align.TOP_LEFT
        or alignment == Align.TOP_RIGHT
    ):
        y += rect.height / 2
    elif (
        alignment == Align.BOTTOM
        or alignment == Align.BOTTOM_LEFT
        or alignment == Align.BOTTOM_RIGHT
    ):
        y -= rect.height / 2
    return Point(x, y)


def _text_style(type: Style, color: Color, alignment: Align) -> _ResolvedStyle:
    """A style that draws text in `type`'s font, size, weight and slant, in
    `color`, placed by `alignment`."""
    var resolved = _ResolvedStyle()
    resolved.apply(type)
    resolved.text_color = color
    return _text_look(resolved, alignment)


def _text_look(style: _ResolvedStyle, alignment: Align) -> _ResolvedStyle:
    """Only the text parts of `style`, placed by `alignment`: the text drawn
    on a widget, which leaves the widget's fill, stroke and shadow to the
    shape beneath it."""
    var look = _ResolvedStyle()
    look.text_color = style.text_color
    look.font = style.font
    look.font_size = style.font_size
    look.font_weight = style.font_weight
    look.font_italic = style.font_italic
    look.tint = style.tint
    look.opacity = style.opacity
    look.blend_mode = style.blend_mode
    look.text_alignment = alignment
    return look^


def _fills(style: _ResolvedStyle) -> Bool:
    """Whether `style` paints a fill that shows: switched on, and either a
    gradient or a colour that isn't transparent."""
    return style.fill_enabled and (
        Bool(style.fill_gradient) or style.fill_color.a > 0
    )


def _variant_look(variant: ButtonVariant, colors: ColorScheme) -> Style:
    """How a button of `variant` looks in `colors`, before its own style:
    the fill behind it, its outline and its text's colour. Each carries the
    outline's colour, so a style that gives only a thickness gets it."""
    if variant == ButtonVariant.TONAL:
        return Style(
            fill=colors.secondary_container,
            stroke=colors.outline,
            stroke_enabled=False,
            text_color=colors.on_secondary_container,
        )
    if variant == ButtonVariant.OUTLINED:
        return Style(
            fill_enabled=False,
            stroke=colors.outline,
            stroke_thickness=1,
            text_color=colors.primary,
        )
    if variant == ButtonVariant.TEXT:
        return Style(
            fill_enabled=False,
            stroke=colors.outline,
            stroke_enabled=False,
            text_color=colors.primary,
        )
    return Style(
        fill=colors.primary,
        stroke=colors.outline,
        stroke_enabled=False,
        text_color=colors.on_primary,
    )


def _over(style: Optional[Style], base: Style) -> Style:
    """`style` layered over `base`, or `base` when there is none: a
    widget's text style over its default text."""
    if style:
        return style.value().over(base)
    return base


def _size(type: Style) -> Float64:
    """The size `type` sets its text in: a fresh frame's when unset."""
    return type.font_size.or_else(16.0)


def _stepped(base: Color, toward: Color, step: Float64) -> Color:
    """`base` with its OKLCH lightness moved `step` towards `toward`'s,
    keeping its chroma and hue: a hovered or pressed widget's colour. A step
    of lightness looks like the same change on any colour, so every widget
    shows its state about as clearly, a pale fill as much as a dark one."""
    var at = base.to_oklch()
    var target = toward.to_oklch()[0]
    var lightness = at[0] + step if target > at[0] else at[0] - step
    return Color.oklch(lightness, at[1], at[2]).with_alpha(base.a)


def _layer_opacity(base: Color, layer: Color, step: Float64) -> Float64:
    """The opacity at which `layer`, drawn over `base`, moves its OKLCH
    lightness by `step`: for a widget with no fill of its own, such as an
    outlined button, whose state is a translucent layer over the surface."""
    var start = base.to_oklch()[0]
    var reach = abs(layer.to_oklch()[0] - start)
    if reach <= step:
        return 1.0
    var low = 0.0
    var high = 1.0
    for _ in range(16):
        var middle = (low + high) / 2
        if abs(base.lerp(layer, middle).to_oklch()[0] - start) >= step:
            high = middle
        else:
            low = middle
    return high


def _faded(color: Color, opacity: Float64) -> Color:
    """`color` at `opacity` of its own alpha."""
    return color.with_alpha(UInt8(Float64(color.a) * opacity + 0.5))


struct DisabledGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.disabled` block it was made for, on scope exit. Only
    `ui.disabled` builds one."""

    var _ui: Pointer[UI, Self.origin]
    var _active: Bool

    def __init__(out self, *, ref[Self.origin] _ui: UI, _active: Bool):
        if _active:
            _ui._disabled_depth += 1
        self._ui = Pointer(to=_ui)
        self._active = _active

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        if self._active:
            self._ui[]._disabled_depth -= 1


def _content_on(colors: ColorScheme, color: Color) -> Color:
    """The colour for text on `color`: its `on_` partner when it is one of
    the scheme's roles, otherwise black or white, whichever reads better."""
    if color == colors.primary:
        return colors.on_primary
    if color == colors.primary_container:
        return colors.on_primary_container
    if color == colors.secondary:
        return colors.on_secondary
    if color == colors.secondary_container:
        return colors.on_secondary_container
    if color == colors.tertiary:
        return colors.on_tertiary
    if color == colors.tertiary_container:
        return colors.on_tertiary_container
    if color == colors.error:
        return colors.on_error
    if color == colors.error_container:
        return colors.on_error_container
    if color == colors.background:
        return colors.on_background
    if (
        color == colors.surface
        or color == colors.surface_dim
        or color == colors.surface_bright
        or color == colors.surface_container_lowest
        or color == colors.surface_container_low
        or color == colors.surface_container
        or color == colors.surface_container_high
        or color == colors.surface_container_highest
    ):
        return colors.on_surface
    return _readable_on(color)


struct ColorsGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.colors` block it was made for, on scope exit. Only
    `ui.colors` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, _colors: ColorScheme):
        _ui._color_blocks.append(_colors)
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._color_blocks.pop()


struct WidgetStyleGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.style` block it was made for, on scope exit. Only
    `ui.style` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, _styles: _Styles):
        _ui._styles.append(_styles._over(_ui._current_styles()))
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._styles.pop()


struct PanelGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.panel` block it was made for, on scope exit. Only
    `ui.panel` builds one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(
        out self,
        *,
        ref[Self.origin] _ui: UI,
        _content: Color,
        _rect: Rectangle,
    ):
        _ui._contents.append(_content)
        _ui._layouts.append(_Layout(_PANEL, _rect, 0.0))
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._contents.pop()
        _ = self._ui[]._layouts.pop()


struct LayoutGuard[origin: Origin[mut=True]](Movable):
    """Ends the `ui.column` or `ui.row` block it was made for, on scope
    exit. Only `ui.column` and `ui.row` build one."""

    var _ui: Pointer[UI, Self.origin]

    def __init__(out self, *, ref[Self.origin] _ui: UI, var _layout: _Layout):
        _ui._layouts.append(_layout^)
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._layouts.pop()
