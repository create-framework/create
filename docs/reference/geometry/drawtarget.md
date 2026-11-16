# DrawTarget

```mojo
trait DrawTarget
```

Somewhere shapes are drawn: `Canvas`. Its primitives, one per kind of shape, are the library's own; a program draws through `draw`.

## Methods

### `draw`

```mojo
def draw[D: Drawable](mut self, shape: D)
```

Draw `shape` in the current style and transform.
