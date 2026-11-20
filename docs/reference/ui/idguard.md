# IDGuard

```mojo
struct IDGuard[origin: MutOrigin]
```

Takes the key `ui.id` added off the widget IDs again, on scope exit. Only `ui.id` builds one.

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
