# JSON

JSON is a text format for structured data: values such as numbers, strings and true or false,
gathered into lists (*arrays*) and into named fields (*objects*), which can be nested inside each
other. It is the usual format for settings, save games and level descriptions, and most tools and
languages read and write it. This page explains how to read, change and save it. Plain rows and
columns, such as a high-score list, are simpler as a [table](tables.md).

## Working with JSON

`JSON` is one type for every JSON value, whether a number, a string, an array or an object:

```mojo
# With config.json as {"player": {"speed": 2.5}, "enemies": [{"hp": 3}, {"hp": 5}]}:
var config = JSON.load("config.json")
var speed = config["player"]["speed"].float()
config["player"]["speed"] = 3.0  # edits the document
for enemy in config["enemies"].values():
    enemy["hp"] = enemy["hp"].int() + 1  # edits land in `config`
config.save("config.json")
```

- **Reading:** `[]` picks a field of an object by its name, or an item of an array by its
  position, and `float()`, `int()`, `string()` or `bool()` reads the value found. `kind()` says
  which kind of value it is, as a `JSONKind`. `values()` gives an array's items or an object's
  values, `keys()` an object's field names, and `items()` its fields as `(name, value)` pairs, as
  in Python.
- **A value is part of its document, not a copy of it.** `[]`, `values()` and `items()` copy
  nothing, so a change made through what they give, such as `config["player"]["speed"] = 3.0`,
  or `enemy["hp"] = ...` in a loop over `values()`, changes the document. So
  **`var p = config["player"]` doesn't copy**: a change made through `p` changes `config` too, as
  in Processing, JavaScript and Python. `.copy()` makes a separate copy, with everything inside it
  copied too.
- **Setting a value stores a copy of it**, so the same value set under two names becomes two
  separate values.
- `int()` reads a whole number exactly, as long as it fits in a 64-bit `Int`, and raises an error
  for a number with a fractional part.
- Replacing a value keeps the old one in memory until the document is copied or saved, so a
  document that is changed every frame for a long time should be tidied up now and then with
  `doc = doc.copy()`.
- **Saving:** `save(path, indent=2)` writes the document to a file, indented by 2 spaces per
  level, and `indent=0` writes it all on one line, as `print` shows it. A number that is infinite,
  or not a number at all (NaN), can't be written as JSON, so `save` raises an error for one, and
  `print` shows it as `null`.
