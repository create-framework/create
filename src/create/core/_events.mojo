"""The one translation from SDL events to the devices on `Context`.

Both run loops pump events and both have to fold them into the same place,
so the arms live here rather than once per loop — a keycode handled in
one and not the other would be a silent divergence between the CPU and GPU
paths.

The window itself is deliberately absent: the arms only ever need to say
*whether* the window should close, never to close it, so this is shared by
`Window` and `GLWindow` without being generic over either.
"""

from create._window.event import (
    Event,
    GamepadAdded,
    GamepadAxisMoved,
    GamepadButtonDown,
    GamepadButtonUp,
    GamepadRemoved,
    KeyDown,
    KeyUp,
    MouseButtonDown,
    MouseButtonUp,
    MouseMoved,
    MouseWheel,
    Quit,
    Resized,
    TextInput,
)

from create.math.point2d import Point2D
from create.math.vector2d import Vector2D

from create.core.context import Context
from create.input.gamepad_button import GamepadButton
from create.input.key import Key
from create.input.mouse_button import MouseButton
from create.render._viewport import Viewport


def apply_events(
    events: List[Event],
    view: Viewport,
    mut context: Context,
    px_per_point: Float64 = 1.0,
) -> Bool:
    """Fold a frame's events into `context`'s keyboard, mouse and gamepads;
    True means quit.

    Takes the viewport and the context rather than a `Canvas` because this
    runs *before* the canvas is built — pointer positions have to be mapped with
    this frame's mapping, which the loop has just re-derived.

    `px_per_point` converts a pointer position from SDL's logical window
    coordinates into the framebuffer pixels the viewport was built from. It is
    1 whenever the two agree — every pixel-buffer `Window` — and the drawable
    over logical ratio on a scaled display, where the GL loop sizes its
    viewport from `drawable_size()`.
    """
    context._new_input_frame()
    var quit = False
    for event in events:
        if event.isa[Quit]():
            quit = True
        elif event.isa[KeyDown]():
            var key = Key(event[KeyDown].keycode)
            if key == Key.ESCAPE and context._quit_on_escape:
                quit = True
            context.keyboard._key_down(key)
        elif event.isa[KeyUp]():
            context.keyboard._key_up(Key(event[KeyUp].keycode))
        elif event.isa[TextInput]():
            context.keyboard._type_text(event[TextInput].text)
        elif event.isa[MouseMoved]():
            var e = event[MouseMoved]
            # Pointer positions reach the program in screen space — the same
            # camera-independent space `canvas.left`/`right`/`bottom`/`top` use.
            context.mouse._move(_to_screen(view, e.x, e.y, px_per_point))
        elif event.isa[MouseButtonDown]():
            var e = event[MouseButtonDown]
            context.mouse._button_down(
                MouseButton(e.button), _to_screen(view, e.x, e.y, px_per_point)
            )
        elif event.isa[MouseButtonUp]():
            var e = event[MouseButtonUp]
            context.mouse._button_up(
                MouseButton(e.button), _to_screen(view, e.x, e.y, px_per_point)
            )
        elif event.isa[MouseWheel]():
            var e = event[MouseWheel]
            context.mouse._scroll(Vector2D(Float64(e.x), Float64(e.y)))
        elif event.isa[GamepadAdded]():
            ref added = event[GamepadAdded]
            context._gamepads._connect(added.id, added.name)
        elif event.isa[GamepadRemoved]():
            context._gamepads._disconnect(event[GamepadRemoved].id)
        elif event.isa[GamepadAxisMoved]():
            var e = event[GamepadAxisMoved]
            context._gamepads._axis_moved(e.id, e.axis, e.value)
        elif event.isa[GamepadButtonDown]():
            var e = event[GamepadButtonDown]
            context._gamepads._button_down(e.id, GamepadButton(e.button))
        elif event.isa[GamepadButtonUp]():
            var e = event[GamepadButtonUp]
            context._gamepads._button_up(e.id, GamepadButton(e.button))
        elif event.isa[Resized]():
            pass  # The viewport is re-derived every frame regardless.
    return quit


def _to_screen(
    view: Viewport, x: Int, y: Int, px_per_point: Float64
) -> Point2D:
    """A pointer position from SDL's window coordinates into screen space."""
    return view.pixel_to_screen(
        Point2D(Float64(x) * px_per_point, Float64(y) * px_per_point)
    )
