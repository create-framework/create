"""What a `UI` costs a frame: its `update` (layout, hit-testing, focus and every
widget's own update) and recording its drawing, headless.

    pixi run benchmark ui

Each case builds a panel with a column of rows, each row a label, a slider, a
checkbox and a button, and times the same frame over and over with the mouse
over one of the buttons. Times are ms/frame, the mean over `REPS` frames, with
the drawing recorded but not rasterised.

Recorded 2026-11-26 on a Ryzen 5 2600X:

    rows  widgets   update ms   draw ms
    3     12        0.11        0.02
    12    48        0.20        0.04
    48    192       0.63        0.16

Split by stage at 48 rows (242 nodes), the update is layout ~0.37 ms and the
widgets' own updates ~0.24 ms; hit-testing, focus and the device claims take
under 0.01 ms each. Layout's cost is measuring text, about 1 µs a measure, and
the widgets' is resolving each one's look from its styles. Walking the tree is
negligible: building the drawing order, describing every node and walking
every node's parents together take about 0.01 ms.
"""

from std.time import perf_counter_ns

from create import *

comptime REPS = 200


def build(rows: Int) -> UI:
    var ui = UI()
    var panel = ui.add(Panel())
    var column = ui.add(Column(), panel)
    for i in range(rows):
        var row = ui.add(Row(), column)
        _ = ui.add(Label(String("Setting ", i), alignment=Align.LEFT), row)
        _ = ui.add(Slider(0.5, 0, 1), row)
        _ = ui.add(Checkbox("On"), row)
        _ = ui.add(Button("Reset"), row)
    return ui^


def time_frames(rows: Int) raises -> Tuple[Float64, Float64]:
    """The mean ms of an update, and of recording the drawing."""
    var ui = build(rows)
    var context = Context()
    context.mouse._move((200, 0))
    # one canvas throughout, as the run loop keeps one backend, with its
    # text resources, from frame to frame: a fresh canvas each frame would
    # measure text cold
    var canvas = Canvas(1280, 720)
    var updating = 0
    var drawing = 0
    for _ in range(REPS):
        var start = perf_counter_ns()
        ui.update(context, canvas)
        var middle = perf_counter_ns()
        canvas.draw(ui)
        var end = perf_counter_ns()
        updating += Int(middle - start)
        drawing += Int(end - middle)
    return (
        Float64(updating) / REPS / 1e6,
        Float64(drawing) / REPS / 1e6,
    )


def main() raises:
    print("rows  widgets   update ms   draw ms")
    for rows in [3, 12, 48]:
        var times = time_frames(rows)
        print(
            rows,
            "   ",
            rows * 4,
            "      ",
            round(times[0], 3),
            "     ",
            round(times[1], 3),
        )
