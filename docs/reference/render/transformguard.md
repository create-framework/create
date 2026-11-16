# TransformGuard

```mojo
struct TransformGuard[origin: MutOrigin]
```

Pops the matrix `canvas.transform` pushed, on scope exit.

Only `canvas.transform` builds one: its constructor's `_`-keywords are
the library's own.

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
