"""`Switch`: turned over by a click or a key, drawn on and off."""
from std.testing import TestSuite, assert_equal, assert_false, assert_true

from create import *
from _input import next_frame, point_at, press, press_key, release

comptime _RECT = Rectangle((0, 0), 200, 32)
"""The track runs from 100 left of the middle to 56 left of it."""


def _click(mut switch: Switch, mut context: Context, at: Point) raises:
    """Press and let go of the mouse at `at`, a frame each."""
    var canvas = Canvas(400, 300)
    next_frame(context)
    point_at(context, at)
    press(context, at)
    switch.update(context, canvas)
    next_frame(context)
    release(context, at)
    switch.update(context, canvas)


def test_a_click_turns_it_over_and_reports_the_change() raises -> None:
    var switch = Switch("Music", _RECT)
    var context = Context()
    _click(switch, context, (40, 0))  # on its text: anywhere in it
    assert_true(switch.on)
    assert_true(switch.changed())
    _click(switch, context, (-80, 0))
    assert_false(switch.on)


def test_setting_it_from_the_program_is_no_change() raises -> None:
    var switch = Switch("Music", _RECT)
    var context = Context()
    point_at(context, (300, 300))
    switch.on = True
    var canvas = Canvas(400, 300)
    switch.update(context, canvas)
    assert_true(switch.on)
    assert_false(switch.changed())


def test_a_disabled_switch_ignores_a_click() raises -> None:
    var switch = Switch("Music", _RECT, enabled=False)
    var context = Context()
    _click(switch, context, (-80, 0))
    assert_false(switch.on)
    assert_false(switch.changed())


def test_enter_turns_it_over_with_focus_in_a_ui() raises -> None:
    var ui = UI()
    var music = ui.add(Switch("Music", _RECT))
    ui.focus(music)
    var context = Context()
    point_at(context, (300, 300))
    press_key(context, Key.ENTER)
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    assert_true(ui[music].on)
    assert_true(ui[music].changed())


def test_it_is_drawn_on_and_off() raises -> None:
    var colors = ColorScheme.light()
    var context = Context()
    point_at(context, (300, 300))
    var off = Switch("Music", _RECT)
    var on = Switch("Music", _RECT, on=True)
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    off.update(context, canvas)
    canvas.draw(off)
    assert_equal(canvas.color_at((-88, 0)), colors.outline)  # the handle
    assert_equal(canvas.color_at((-70, 0)), colors.surface_container_highest)
    # the text starts after the track, never over it
    assert_equal(canvas.color_at((-60, 0)), colors.surface_container_highest)
    var lit = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    on.update(context, lit)
    lit.draw(on)
    assert_equal(lit.color_at((-68, 0)), colors.on_primary)  # at the right
    assert_equal(lit.color_at((-90, 0)), colors.primary)


def test_its_handle_is_rounded_inside_its_track() raises -> None:
    var colors = ColorScheme.light()
    var context = Context()
    point_at(context, (300, 300))
    var corner = Point(-68 + 7.5, 7.5)  # inside the handle's square
    var square = Switch("Music", _RECT, on=True)
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    square.update(context, canvas)
    canvas.draw(square)
    assert_equal(canvas.color_at(corner), colors.on_primary)
    # A pill of a track holds a round handle.
    var pill = Switch("Music", _RECT, on=True, track=Style(corner_radius=12))
    var round = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    pill.update(context, round)
    round.draw(pill)
    assert_equal(round.color_at(corner), colors.primary)
    assert_equal(round.color_at((-68, 0)), colors.on_primary)


def test_a_hovered_switch_steps_its_track_and_keeps_its_handle() raises -> None:
    var colors = ColorScheme.light()
    var context = Context()
    point_at(context, (-90, 0))  # over the track
    var on = Switch("Music", _RECT, on=True)
    var canvas = Canvas(400, 300, antialiasing=Antialiasing.OFF)
    on.update(context, canvas)
    canvas.draw(on)
    assert_true(on.hovered())
    assert_true(canvas.color_at((-90, 0)) != colors.primary)
    assert_equal(canvas.color_at((-68, 0)), colors.on_primary)


def test_a_ui_measures_it_and_rings_its_track() raises -> None:
    var ui = UI()
    var music = ui.add(Switch("Music"))
    var context = Context()
    point_at(context, (300, 300))
    var canvas = Canvas(400, 300)
    ui.update(context, canvas)
    assert_equal(ui[music].rect.height, 40.0)
    assert_true(ui[music].rect.width > 44 + 12)
    assert_equal(ui[music]._ring().width, 44.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
