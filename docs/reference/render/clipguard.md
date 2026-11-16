# ClipGuard

```mojo
struct ClipGuard[origin: MutOrigin]
```

Closes the clip `canvas.clip` opened, on scope exit. Only `canvas.clip` builds one.

Holds the clip that was current before it rather than popping a stack, so
nesting works the way `StyleGuard`'s does.

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
