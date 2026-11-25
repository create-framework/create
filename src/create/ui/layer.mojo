"""`UILayer`: the handle a `ui.screen` block draws widgets with."""

from std.reflection import SourceLocation, call_location

from create.color import Color
from create.core import Context
from create.geometry import Circle, Geometry, Line, Rectangle
from create.input import GamepadButton, Key
from create.image import Image
from create.math import Point, Transform, Vector, ceil, floor
from create._optional import _OptionalFloat64
from create.render import Align, Canvas, Style
from create.render.style import _ResolvedStyle
from create.render.canvas import _View, _ViewGuard
from ._id import _mix
from ._key import _WidgetKey
from ._layout import _Layout, _COLUMN, _PANEL, _ROW
from .button import ButtonVariant
from .label import _anchor
from .slider import (
    _arrow_direction,
    _check_step,
    _dragged_value,
    _handle_x,
    _keyed_value,
    _slider_ends,
)
from .checkbox import _checkbox_box, _checkbox_text_at, _tick_lines
from ._text_buffer import _TextBuffer
from .text_field import TextEditor, _measure, _offset_at
from .colors import ColorScheme, FocusRing
from .ui import UI, _Hit
from ._theme import _Styles, _fills, _text_look


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

    def draw[G: Geometry](self, shape: G, style: Style) raises:
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

    def colors(self) raises -> ColorScheme:
        """The colours the widgets are drawn in here: the innermost
        `ui.colors` block's, or the layer's. A program's own widget draws in
        them to match."""
        self._check_frame()
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
        checkbox_label_style: Style = Style(),
        text_field_container: Style = Style(),
        text_field_focused: Style = Style(),
        text_field_text_style: Style = Style(),
        text_field_placeholder_style: Style = Style(),
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
                checkbox_label_style,
                text_field_container,
                text_field_focused,
                text_field_text_style,
                text_field_placeholder_style,
                text_field_caret,
                text_field_selection,
            ),
        )

    def content_color(self) raises -> Color:
        """The colour for text here: the innermost panel's content colour, or
        the colours' `on_surface`. A program's own widget draws its text in it
        to match the built-in ones."""
        self._check_frame()
        return self._ui[]._content_color()

    @always_inline
    def panel(
        self,
        rect: Optional[Rectangle] = None,
        *,
        style: Style = Style(),
        id: _WidgetKey = None,
    ) raises -> PanelGuard[Self.ui_origin]:
        """A surface filling `rect`, drawn beneath everything called inside
        its `with` block. Text on it takes its content colour, so a label on
        a dark panel turns light without being told, and it covers what is
        beneath it from the pointer. It doesn't place what is inside it.
        Without a `rect`, it fills what is around it, as `ui.column` does.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        with ui.panel(Rectangle((0, 0), 320, 120)):
            ui.label("Volume", Rectangle((0, 30), 280, 24))
            ui.slider(self.volume, 0, 1, Rectangle((0, -15), 280, 32))
        ```
        """
        return self._panel(
            self._widget_id(call_location(), id._hash),
            self._fill(rect, "ui.panel"),
            style,
        )

    def _panel(
        self, id: UInt64, rect: Rectangle, style: Style
    ) raises -> PanelGuard[Self.ui_origin]:
        ref ui = self._ui[]
        # a surface the pointer can't reach through, nor focus
        ui._hits.append(_Hit(id, rect, self._to_local, False, False, False))
        var look = ui._theme().panel(style)
        var resolved = look.style
        var surface = look.surface
        var content = look.content
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
        return PanelGuard(
            _ui=ui, _surface=surface, _content=content, _rect=rect
        )

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
        var area = self._fill(rect, "ui.column")
        return LayoutGuard(
            _ui=self._ui[],
            _layout=_Layout(_COLUMN, area, gap.or_else(self._ui[]._spacing)),
        )

    def _fill(
        self, rect: Optional[Rectangle], what: String
    ) raises -> Rectangle:
        """Where a column or panel named `what` goes: `rect` when it is
        given, or all that is left around it: a panel's inside, inset by
        twice the UI's `spacing`, the rest of a column, or the next slot of
        a row."""
        if rect:
            return rect.value()
        ref layouts = self._ui[]._layouts
        if not layouts:
            raise Error(
                what
                + ": give it a rect, or open it inside a ui.panel, ui.column"
                + " or ui.row"
            )
        ref around = layouts[len(layouts) - 1]
        if around.kind == _PANEL:
            return around.rect.inset(2 * self._ui[]._spacing)
        return around.take_rest(what)

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
        alignment: Optional[Align] = None,
        style: Style = Style(),
    ) raises:
        """Text placed in `rect`, by `alignment`: in its centre unless given,
        here or as the style's `text_alignment`, against its left edge with
        `Align.LEFT`, and so on. It reacts to nothing, so the pointer passes
        through it to what is beneath. In a `ui.disabled` block it fades, as
        a disabled widget's text does.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.label("Volume", Rectangle((0, 40), 240, 24), alignment=Align.LEFT)
        ```
        """
        self._check_frame()
        var resolved = (
            self._ui[]
            ._theme()
            .label(style, alignment, disabled=self._disabled(False))
        )
        var place = self._place(rect, resolved.font_size * 1.5, "ui.label")
        var placed = resolved.text_alignment
        self._ui[]._recorder.text(text, _anchor(place, placed), resolved)
        self._ui[]._called(changed=False)

    def image(self, image: Image, rect: Optional[Rectangle] = None) raises:
        """`image` stretched to fill `rect`. Like a label, it reacts to
        nothing, and fades in a `ui.disabled` block."""
        self._check_frame()
        var place = self._place_control(rect, "ui.image")
        var look = _ResolvedStyle()
        if self._disabled(False):
            look.opacity = self._ui[]._state_layers.disabled_content
        self._ui[]._recorder.image(
            image, place.position, place.width, place.height, look
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

    def changed(self) raises -> Bool:
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
        self._check_frame()
        return self._ui[]._last_changed

    def submitted(self) raises -> Bool:
        """Whether Enter was pressed this frame in the widget called last,
        a text field. It is `False` after any other widget.

        ```mojo
        # In `update`, inside `with self.ui.screen(context, canvas) as ui:`:
        ui.text_field(self.name, Rectangle((0, 0), 320, 40))
        if ui.submitted():
            self.start_game(self.name)
        ```
        """
        self._check_frame()
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
        var parts = ui._theme().text_field(
            call_container,
            call_focused,
            call_text,
            call_placeholder,
            call_caret,
            call_selection,
            hovered=state.hovered,
            focused=state.focused,
            disabled=off,
        )
        var typed = parts.typed
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
        var field = parts.container
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

        # the text, clipped half the padding in from each side: scrolled
        # text runs on into the padding, but stops short of the border
        recorder.clip(
            Rectangle(rect.position, rect.width - padding, rect.height)
        )
        var origin_x = left - buffer.scroll
        var y = rect.position.y
        if state.focused and buffer.selected_text():
            var start = self._measure(buffer.before_selection(), look)
            var width = self._measure(buffer.selected_text(), look)
            recorder.style = parts.selection
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
                _text_look(parts.hint, Align.LEFT),
            )
        # the caret: steady for a moment after a change, then blinking
        var since = now - buffer.last_change
        if (
            state.focused
            and not off
            and (since < 0.5 or Int(since * 2) % 2 == 1)
        ):
            var x = origin_x + caret_x
            recorder.style = parts.caret
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

    def _record_ring[S: Geometry](self, shape: S, look: FocusRing):
        ref ui = self._ui[]
        ui._rings.style = ui._theme().ring()
        ui._rings.draw(shape)

    def _measure(self, text: String, look: _ResolvedStyle) raises -> Float64:
        """How wide `text` is drawn in `look`'s font, size and weight."""
        return _measure(self._canvas[], text, look)

    def _offset_at(
        self, text: String, x: Float64, look: _ResolvedStyle
    ) raises -> Int:
        """The byte offset of the character boundary in `text` nearest to
        `x` units from its start."""
        return _offset_at(self._canvas[], text, x, look)

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
        var look = (
            self._ui[]
            ._theme()
            .button(
                call_style,
                variant,
                rect.height,
                hovered=state.hovered,
                pressed=state.pressed,
                disabled=off,
            )
        )
        var shape = Rectangle(
            rect.position,
            rect.width,
            rect.height,
            corner_radius=look.corner_radius,
        )
        ref recorder = self._ui[]._recorder
        if look.body:
            recorder.style = look.body.value()
            recorder.draw(shape)
        if look.layer:
            recorder.style = look.layer.value()
            recorder.draw(shape)
        self._ring_around(shape, state, off)
        recorder.text(text, rect.position, look.text)
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
        _check_step(step, "ui.slider")
        var off = self._disabled(disabled)
        var state = self._interact(id, rect, off, take_focus, adjusts=True)
        ref ui = self._ui[]
        var look = ui._theme().slider(
            call_track,
            call_active_track,
            call_handle,
            call_handle_outline,
            hovered=state.hovered,
            dragging=state.held,
            disabled=off,
        )
        var knob_radius = look.handle.stroke_thickness / 2
        var ends = _slider_ends(rect, knob_radius)
        var left = ends[0]
        var right = ends[1]
        var y = rect.position.y
        var dragging = state.held  # the frame it is let go of included
        var changed = False
        if dragging:
            var pointer = self._to_local.apply(self._context[].mouse.position)
            var moved = _dragged_value(pointer.x, left, right, min, max, step)
            if moved and moved.value() != value:
                value = moved.value()
                changed = True
        var keys = self._keys_act(state.focused)
        var pad = state.focused and ui._focus_visible and ui._pad_move.x != 0
        if keys or pad:
            ref keyboard = self._context[].keyboard
            var towards_max: Int
            if pad:
                towards_max = 1 if ui._pad_move.x > 0 else -1
            else:
                towards_max = _arrow_direction(keyboard)
            var keyed = _keyed_value(
                value,
                min,
                max,
                step,
                towards_max,
                home=not pad and keyboard.pressed(Key.HOME),
                end=not pad and keyboard.pressed(Key.END),
            )
            if keyed[0] and keys:
                self._ui[]._key_used = True
            if keyed[1] != value:
                value = keyed[1]
                changed = True
        var handle_x = _handle_x(value, min, max, left, right)
        ref recorder = ui._recorder
        recorder.style = look.track
        recorder.draw(Line(Point(left, y), Point(right, y)))
        if handle_x > left:
            recorder.style = look.active
            recorder.draw(Line(Point(left, y), Point(handle_x, y)))
        var centre = Point(handle_x, y)
        recorder.style = look.handle
        recorder.draw(Line(centre, centre))
        var knob = Circle(centre, knob_radius)
        if look.outline.fill_enabled or look.outline.stroke_enabled:
            recorder.style = look.outline
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
        var parts = (
            self._ui[]
            ._theme()
            .checkbox(
                call_box,
                call_checked_box,
                call_tick,
                call_label,
                checked=checked,
                hovered=state.hovered,
                pressed=state.pressed,
                disabled=off,
            )
        )
        var look = parts.box
        # the box against the left edge, the label a gap after it
        var box = _checkbox_box(rect, look.corner_radius)
        ref recorder = self._ui[]._recorder
        recorder.style = look
        recorder.draw(box)
        if checked:
            recorder.style = parts.tick
            var lines = _tick_lines(box.position)
            recorder.draw(lines[0])
            recorder.draw(lines[1])
        self._ring_around(box, state, off)
        recorder.text(label, _checkbox_text_at(rect), parts.text)
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
                # a click on it is a click on no widget; `_begin_layer` saw
                # last frame's hits, where it may not have been disabled yet
                ui._clear_focus()
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
        _surface: Color,
        _content: Color,
        _rect: Rectangle,
    ):
        _ui._surfaces.append(_surface)
        _ui._contents.append(_content)
        _ui._layouts.append(_Layout(_PANEL, _rect, 0.0))
        self._ui = Pointer(to=_ui)

    def __enter__(mut self):
        pass

    def __exit__(mut self):
        _ = self._ui[]._surfaces.pop()
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
