# User interface

Buttons, sliders, checkboxes and text fields for menus, settings screens and tools. Each widget is a
value the program keeps, updates and draws with `canvas.draw`, on its own or kept together with
others in a `UI`. Start with Widgets, which explains both.

- [Widgets](widgets.md): a widget as a value, updating and drawing it, each widget, keeping widgets
  together in a `UI`, laying them out with `Column`, `Row` and `Space`, drawing your own things
  among them, and disabled widgets.
- [Focus and navigation](focus.md): which widget has focus, Tab and the keys, gamepads, focus rings,
  and keeping the game's own keys and clicks apart from the UI's.
- [Themes and styling](themes.md): the colours widgets are drawn in, colours from one colour, the
  sizes the `UI` keeps, styling one widget or every widget of a kind, and panels.

Text fields are explained with typed text, in [Typing](../interaction/typing.md#text-fields).

[examples/ui](../../../examples/ui/main.mojo) puts it together: a settings menu with every kind of
widget.
