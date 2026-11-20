# Typography

```mojo
struct Typography
```

The theme's kinds of text: `title` for headings, `body` for running text and `label` for the text on widgets, such as a button's.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`, `Writable`.

## Fields

- `title: TypeStyle`
- `body: TypeStyle`
- `label: TypeStyle`

## Constructors

```mojo
@staticmethod
def __init__(out self)
```
