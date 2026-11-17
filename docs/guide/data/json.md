# JSON

JSON is a text format for structured data: values such as numbers, strings and true or false,
gathered into lists (*arrays*) and into named fields (*objects*), which can be nested inside each
other. It is the usual format for settings, save games and level descriptions, and most tools and
languages read and write it. This page explains how to read, change and save it, how to build a
document from nothing, and how to cope with a field that is missing. Plain rows and columns, such as
a high-score list, are simpler as a [table](tables.md).

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

## Building a document

A save game or a settings file has to be written before it can be loaded, so a program often
builds a document from nothing. `JSON.object()` is an empty object and `JSON.array()` an empty
array; fill an object by setting its fields, and an array with `append`:

```mojo
# Saving the game:
var save = JSON.object()
save["level"] = 3
save["name"] = "Ada"
save["sound"] = True
save["player"] = JSON.object()  # an empty object, filled in next
save["player"]["x"] = 120.5
save["player"]["y"] = -40.0
save["inventory"] = JSON.array()
save["inventory"].append("sword")
save["inventory"].append("rope")
save.save("save.json")
```

`save.json` then holds:

```json
{
  "level": 3,
  "name": "Ada",
  "sound": true,
  "player": {
    "x": 120.5,
    "y": -40.0
  },
  "inventory": [
    "sword",
    "rope"
  ]
}
```

- **Numbers, strings and `True` or `False` become JSON values by themselves**, so they can be
  set and appended as they are. `JSON.null()` is JSON's `null`, the value that stands for
  "nothing here".
- **A new field is added after the others**, and fields stay in the order they were added, so
  the file reads in the order the program built it. Setting a field that already exists replaces
  its value where it is.
- **To nest an object or array, set an empty one first and then fill it in** through the
  document, as `player` and `inventory` are above. Since setting a value stores a copy of it, an
  object filled in separately and set afterwards works too, but changing it after setting it
  doesn't change the document.
- `JSON.parse(text)` reads JSON from a string rather than a file, and `print(save)` shows a
  document as compact JSON, on one line.

## Missing values

A file written by an older version of the program, or edited by hand, may lack a field the
program expects. Reading a field that isn't there raises an error, so check first, or give a
default:

- **`"name" in doc`** is whether an object has a field of that name.
- **`doc.get(name, default)`** is the field's value, or `default` when there is none:
  `settings.get("volume", 0.8).float()` is the saved volume, or 0.8 in a file that has none.
- **`doc.is_null()`** is whether a value is `null`, and **`len(doc)`** how many fields an object
  has, or items an array has.
- **`doc.remove(name)`** removes a field from an object, and **`doc.remove(index)`** an item from
  an array, moving the items after it up by one.

The very first time a game runs, there is no save file at all, and `JSON.load` raises an error
for a file it can't find. Catch the error, and start from an empty document instead (`try` and
`except` are explained in [Errors](../basics/mojo.md#errors)):

```mojo
# In `create`:
var save: JSON
try:
    save = JSON.load("save.json")
except:
    save = JSON.object()  # the first run: no save yet
```
