"""`WidgetHandle`: how a program reaches a widget in a `UI`."""


@fieldwise_init
struct WidgetHandle[W: Copyable](
    Copyable, Equatable, ImplicitlyCopyable, Movable
):
    """Where a widget of type `W` is in a `UI`: what `ui.add` returns, and
    how the program reaches the widget again, as `ui[handle]`.

    Once `ui.remove` has removed the widget, its handle names nothing: using
    it stops the program with a message saying so, even after a new widget
    has taken the old one's place."""

    var _index: Int
    var _generation: Int
    """How many widgets had been at `_index` before this one: a handle to
    one of them is told apart from a handle to the widget there now."""

    def __eq__(self, other: Self) -> Bool:
        return (
            self._index == other._index
            and self._generation == other._generation
        )
