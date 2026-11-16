# create.input

The input devices `Context` holds: `Keyboard`, `Mouse` and `Gamepad`, and the `Key`, `MouseButton` and `GamepadButton` they are read with.

## Types

| Type | Description |
|---|---|
| [`Keyboard`](keyboard.md) | The keyboard's state for one frame, read as `context.keyboard`. |
| [`Key`](key.md) | A key by its position on the keyboard, what the `Keyboard` queries take: `context.keyboard.down(Key.UP)`. |
| [`Mouse`](mouse.md) | The mouse's state for one frame, read as `context.mouse`. |
| [`MouseButton`](mousebutton.md) | A mouse button, for `Mouse.down`/`pressed`/`released`. |
| [`Gamepad`](gamepad.md) | One gamepad's state for one frame, read as `context.gamepad(player)`. |
| [`GamepadButton`](gamepadbutton.md) | A gamepad button, for `Gamepad.down`/`pressed`/`released`. |
