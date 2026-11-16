# StyleGuard

```mojo
struct StyleGuard[origin: MutOrigin]
```

Restores the style the frame had when the scope was entered.

`Style` is a plain value, so the guard carries its own snapshot and no
stack is needed — nesting works because each guard restores what it saw.
Only `canvas.style` builds one.

Implements `Deinitable`, `Movable`.

## Special methods

### `__enter__`

```mojo
def __enter__(mut self)
```

### `__exit__`

```mojo
def __exit__(mut self)
```
