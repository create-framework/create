# JSON

```mojo
struct JSON
```

A JSON value: an object, array, string, number, bool or null.

Loaded or parsed, a document is read through `[]` by key or index, and
each step hands back a handle into the same document, so reading a
nested value copies nothing:

```mojo
var config = JSON.load("config.json")
var speed = config["player"]["speed"].float()
for enemy in config["enemies"].values():
    canvas.text(enemy["name"].string(), (0, y))
```

A handle edits the document it points into, nested assignment and
loops included, so a value read from a document **aliases** it, as in
Processing, JavaScript and Python. `copy()` gives an independent one:

```mojo
config["player"]["speed"] = 3.0
for enemy in config["enemies"].values():
    enemy["hp"] = enemy["hp"].int() - 1
var player = config["player"]          # still part of config
var snapshot = config.copy()           # a document of its own
```

Assigning a value copies it in, so a value set under two keys is two
values. Replacing a value leaves the old one in the document, unread,
until `copy()` or `save` drops it: a document rewritten every frame for
a long run stays small with `doc = doc.copy()` now and then. Prints as
compact JSON text.

Implements `Copyable`, `Deinitable`, `Movable`, `Sized`, `Writable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, value: Float64)
```

A number.

```mojo
@staticmethod
def __init__(out self, value: Int)
```

A whole number, kept exact.

```mojo
@staticmethod
def __init__(out self, value: String)
```

A string.

```mojo
@staticmethod
def __init__(out self, value: Bool)
```

A bool.

```mojo
@staticmethod
def __init__(out self, *, copy: Self)
```

A deep copy: a document of its own holding only this value.

### `object`

```mojo
@staticmethod
def object() -> Self
```

An empty object, to fill with `json[key] = value`.

### `array`

```mojo
@staticmethod
def array() -> Self
```

An empty array, to fill with `append`.

### `null`

```mojo
@staticmethod
def null() -> Self
```

`null`.

### `load`

```mojo
@staticmethod
def load(path: String) raises -> Self
```

Load a JSON file. Errors name `path:line:column`.

A relative `path` is resolved against the directory of the calling
source file, not the working directory, as `Image.load`'s is.

### `parse`

```mojo
@staticmethod
def parse(text: String) raises -> Self
```

Parse JSON text already in memory.

## Methods

### `kind`

```mojo
def kind(self) -> JSONKind
```

Which kind of value this is.

### `is_null`

```mojo
def is_null(self) -> Bool
```

Whether this is `null`.

### `get`

```mojo
def get(self, key: String, default: Self) raises -> Self
```

The value under `key` in an object, or `default` if it has none.

### `append`

```mojo
def append(self, value: Self) raises
```

Add a copy of `value` to the end of an array.

### `remove`

```mojo
def remove(self, key: String) raises
```

Remove `key` from an object; raises if it has none.

```mojo
def remove(self, index: Int) raises
```

Remove item `index` from an array; later items move up by one.

### `keys`

```mojo
def keys(self) raises -> List[String]
```

An object's keys, in the order the document has them.

### `values`

```mojo
def values(self) raises -> List[Self]
```

An array's items, or an object's values, in order.

Each is a handle into this document, like `[]`'s.

### `items`

```mojo
def items(self) raises -> List[Tuple[String, Self]]
```

An object's keys, each with its value, in the order the document has them, as Python's `dict.items()`: `for name, value in doc.items()`.

Each value is a handle into this document, like `[]`'s.

### `float`

```mojo
def float(self) raises -> Float64
```

A number, as a float.

### `int`

```mojo
def int(self) raises -> Int
```

A whole number. Raises for one with a fraction, like `1.5`.

A number written without a fraction or exponent is read exactly,
all 64 bits; `3.0` and `3e2` are whole too.

### `string`

```mojo
def string(self) raises -> String
```

A string's text.

### `bool`

```mojo
def bool(self) raises -> Bool
```

A bool's value.

### `save`

```mojo
def save(self, path: String, indent: Int = Int(2)) raises
```

Write the value to a JSON file, keys in their order.

Indented `indent` spaces a level, one item per line; 0 writes it
compact, as it prints. Raises for an infinite or NaN number, which
JSON has no way to write. A relative `path` is resolved against the
directory of the calling source file, as `load`'s is.

## Special methods

### `__getitem__`

```mojo
def __getitem__(self, key: String) raises -> Self
```

The value under `key` in an object; raises if there is none.

```mojo
def __getitem__(self, index: Int) raises -> Self
```

Item `index` of an array, from 0; raises if out of range.

### `__setitem__`

```mojo
def __setitem__(self, key: String, value: Self) raises
```

Set `key` in an object to a copy of `value`, adding the key last if it is new.

```mojo
def __setitem__(self, index: Int, value: Self) raises
```

Set item `index` of an array to a copy of `value`.

### `__contains__`

```mojo
def __contains__(self, key: String) -> Bool
```

Whether this is an object with `key`.

### `__len__`

```mojo
def __len__(self) -> Int
```

The number of an object's keys or an array's items; 0 otherwise.
