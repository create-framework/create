"""Widget IDs: a call site and how many times it has run this frame, inside
the keys of the open `ui.id` blocks."""
from std.reflection import call_location
from std.testing import TestSuite, assert_equal, assert_raises, assert_true

from create import *
from create.ui._key import _WidgetKey


@always_inline
def _probe(ui: UILayer, key: Optional[UInt64] = None) raises -> UInt64:
    """The ID a widget called where `_probe` is called would get."""
    return ui._widget_id(call_location(), key)


def _next_frame(mut context: Context):
    context._frame_count += 1


def _after_optional(
    mut ui: UI, mut context: Context, mut canvas: Canvas, show: Bool
) raises -> UInt64:
    with ui.screen(context, canvas) as layer:
        if show:
            _ = _probe(layer)
        return _probe(layer)


def test_a_widget_shown_earlier_doesnt_shift_a_later_id() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    var without = _after_optional(ui, context, canvas, False)
    _next_frame(context)
    var with_it = _after_optional(ui, context, canvas, True)
    assert_equal(without, with_it)


def test_an_id_is_the_same_every_frame() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    var first = _after_optional(ui, context, canvas, False)
    _next_frame(context)
    var second = _after_optional(ui, context, canvas, False)
    assert_equal(first, second)


def test_each_run_of_a_loop_gets_its_own_id() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    var ids = List[UInt64]()
    with ui.screen(context, canvas) as layer:
        for _ in range(3):
            ids.append(_probe(layer))
    assert_true(ids[0] != ids[1])
    assert_true(ids[1] != ids[2])
    assert_true(ids[0] != ids[2])


def _keyed(
    mut ui: UI, mut context: Context, mut canvas: Canvas, names: List[String]
) raises -> Dict[String, UInt64]:
    var ids = Dict[String, UInt64]()
    with ui.screen(context, canvas) as layer:
        for name in names:
            with layer.id(name):
                ids[name] = _probe(layer)
    return ids^


def test_a_keyed_widget_keeps_its_id_when_the_list_is_reordered() raises -> (
    None
):
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    var before = _keyed(ui, context, canvas, ["ada", "bo", "cy"])
    _next_frame(context)
    var after = _keyed(ui, context, canvas, ["cy", "ada"])
    assert_equal(before["ada"], after["ada"])
    assert_equal(before["cy"], after["cy"])
    assert_true(before["ada"] != before["bo"])


def _keyed_calls(
    mut ui: UI, mut context: Context, mut canvas: Canvas, keys: List[UInt64]
) raises -> Dict[UInt64, UInt64]:
    var ids = Dict[UInt64, UInt64]()
    with ui.screen(context, canvas) as layer:
        for key in keys:
            ids[key] = _probe(layer, key)
    return ids^


def test_an_id_key_on_one_call_keeps_it_apart() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    var before = _keyed_calls(ui, context, canvas, [7, 8])
    _next_frame(context)
    var after = _keyed_calls(ui, context, canvas, [8, 7])
    assert_equal(before[7], after[7])
    assert_equal(before[8], after[8])
    assert_true(before[7] != before[8])


def _button_ids[K: Hashable & Copyable](keys: List[K]) raises -> List[UInt64]:
    """The IDs of buttons called in a loop, each given the next key as its
    `id=`."""
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    with ui.screen(context, canvas) as layer:
        for key in keys:
            _ = layer.button("", Rectangle((0, 0), 10, 10), id=key)
    var ids = List[UInt64]()
    for hit in ui._hits:
        ids.append(hit.id)
    return ids^


def test_id_takes_any_hashable_key() raises -> None:
    var small = _button_ids[UInt8]([UInt8(1), UInt8(2)])
    var named = _button_ids[String](["ada", "bob"])
    assert_true(small[0] != small[1])
    assert_true(named[0] != named[1])
    # a literal keys as its String or Int does
    var name = String("ada")
    var number = 3
    assert_equal(
        _WidgetKey("ada")._hash.value(), _WidgetKey(name)._hash.value()
    )
    assert_equal(_WidgetKey(3)._hash.value(), _WidgetKey(number)._hash.value())


def test_two_layers_in_one_frame_share_the_counts() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    var ids = List[UInt64]()
    for _ in range(2):
        with ui.screen(context, canvas) as layer:
            ids.append(_probe(layer))
    assert_true(ids[0] != ids[1])


def test_a_layer_used_in_a_later_frame_raises() raises -> None:
    var ui = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    var kept = ui.screen(context, canvas)
    _next_frame(context)
    with assert_raises(contains="open a new layer"):
        kept.draw(Circle((0, 0), 5), Style(fill=Color.RED))
    with assert_raises(contains="open a new layer"):
        _ = kept.changed()
    with assert_raises(contains="open a new layer"):
        _ = kept.submitted()
    with assert_raises(contains="open a new layer"):
        _ = kept.colors()
    with assert_raises(contains="open a new layer"):
        _ = kept.content_color()


def test_a_layer_inside_another_of_the_same_ui_raises() raises -> None:
    var ui = UI()
    var other = UI()
    var context = Context()
    var canvas = Canvas(64, 64)
    with ui.screen(context, canvas):
        with other.screen(context, canvas):  # another UI's layer is fine
            pass
        with assert_raises(contains="inside another layer"):
            with ui.screen(context, canvas):
                pass
    with ui.screen(context, canvas):  # after the first ends, it opens
        pass


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
