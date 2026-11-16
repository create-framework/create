# Drawable

```mojo
trait Drawable
```

Something a `DrawTarget` can draw: a shape, a curve, or a program's own type made of them.

## Methods

### `draw_to`

```mojo
def draw_to[T: DrawTarget](self, mut target: T)
```

Draw this onto `target`, through its `draw` or, for a shape, the primitive for its kind.
