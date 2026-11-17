# Input

A program learns what the player is doing from three kinds of device: the keyboard, the mouse and
gamepads. This page explains what they have in common; the [Keyboard](keyboard.md),
[Typing](typing.md), [Mouse](mouse.md) and [Gamepads](gamepads.md) pages go into each one.

## Asking the devices

The devices live on the `Context`: `context.keyboard`, `context.mouse` and
`context.gamepad(player)`. Before each `update`, the loop records in them everything that happened
since the last frame, and `update` asks them what it needs to know. Unlike Processing, Create has
no event callbacks such as `keyPressed()` or `mousePressed()`: a program reads the devices when it
is ready to, every frame, in the same place it uses the answers.

## Down, pressed and released

Every device answers the same three questions about a key or a button:

- **`down(button)`**: is it held right now? This is true in every frame it is held.
- **`pressed(button)`**: did it go down this frame? This is true only in that one frame.
- **`released(button)`**: did it come up this frame? This, too, is true only in that one frame.

Use `down` for what should keep happening while a key is held, such as walking, and `pressed` for
what should happen once each time it is pressed, such as jumping or opening a menu:

```mojo
from create import *


@fieldwise_init
struct Mover(Program):
    var position: Point2D
    var size: Float64

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Mover:
        return Mover((0, 0), 40)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        var step = 200 * context.time.delta
        if context.keyboard.down(Key.RIGHT):  # held: moves every frame
            self.position = self.position + Vector2D(step, 0)
        if context.keyboard.down(Key.LEFT):
            self.position = self.position - Vector2D(step, 0)
        if context.keyboard.pressed(Key.SPACE):  # once per press, however long held
            self.size = 80 if self.size == 40 else 40
        if context.mouse.pressed():  # the left button by default
            self.position = context.mouse.position
        canvas.fill(Color.PURPLE)
        canvas.rectangle(self.position, self.size, self.size)


def main() raises:
    run[Mover]("Mover")
```

- The mouse's methods ask about `MouseButton.LEFT` unless you name another button.
- *Pressed* never means held. Processing's `mousePressed` variable, which does, is
  `context.mouse.down()` in Create.
- When the player switches to another window, everything held is released, and `released` is true
  for each of them in that frame. The window can't see a key or button let go while another window
  is in front, so this keeps nothing stuck down. A gamepad that disconnects releases its buttons the
  same way.
- `keyboard.key`, `mouse.button` and `pad.button` hold each device's most recent press. Before
  anything has been pressed, they are `Key.NONE`, `MouseButton.NONE` and `GamepadButton.NONE`.

## Keys and buttons by name

Keys, mouse buttons and gamepad buttons are each a type of their own, `Key`, `MouseButton` and
`GamepadButton`, so a bare number, or a key where a button was meant, never passes by mistake.

Each type can also be looked up by name, which is how key bindings are kept in a settings file:
`Key.from_name("page_up")`, `MouseButton.from_name("right")`, `GamepadButton.from_name("south")`.
The names are those of the constants, in upper or lower case, and a name that matches none of
them gives `None`. `Cursor` has a `from_name` too.
