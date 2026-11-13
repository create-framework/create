# Data

Reading and writing data files: tables of rows and columns (CSV and TSV), and JSON.

## Tables

A `Table` is rows of text cells from CSV or TSV, like Processing's:

```mojo
# A fragment: scores.csv has a header line, "name,score".
var table = Table.load(source_path("scores.csv"))
for ref row in table.rows():
    print(row.string("name"), row.int("score"))

ref row = table.add_row()
row.set("name", "Ada")
row.set("score", 120)
table.sort("score", descending=True)
table.save(source_path("scores.csv"))
```

- **Loading:** `Table.load(path)` reads a file, `Table.parse(text)` a string, and
  `Table(columns)` builds an empty one. The first line names the columns unless `header=False`.
  The separator is a tab for `.tsv`/`.tab` and a comma otherwise, unless `separator=` names one.
- **Rows by reference:** `t.row(i)` and `for ref row in t.rows()` edit in place, and
  `ref row = t.add_row()` returns the new row.
- **Cells stay text until read:** `row.string`, `float`, `int` and `bool`, by column name or
  index, parse on each call and raise naming the column and cell.
- **`sort(column, descending=)`** is stable, and numeric only when every cell in the column is a
  number, so one blank sorts the column as text.
- **`save`** quotes a field only when it must.

## JSON

`JSON` is one type for every JSON value:

```mojo
# A fragment: config.json is {"player": {"speed": 2.5}, "enemies": [{"hp": 3}, {"hp": 5}]}.
var config = JSON.load(source_path("config.json"))
var speed = config["player"]["speed"].float()
config["player"]["speed"] = 3.0  # edits the document
for enemy in config["enemies"].values():
    enemy["hp"] = enemy["hp"].int() + 1  # edits land in `config`
config.save(source_path("config.json"))
```

- **Reading:** `[]` by key or index, then `float`, `int`, `string` or `bool`; `kind()` is a
  `JSONKind`. `values()` is an array's items or an object's values, `keys()` an object's keys and
  `items()` its `(key, value)` pairs, as in Python.
- **A value is a handle into a shared document:** `[]`, `values()` and `items()` copy nothing, and
  edits land in the document (`config["player"]["speed"] = 3.0`, or `enemy["hp"] = ...` in a loop
  over `values()`). So **`var p = config["player"]` aliases `config`**, as in Processing,
  JavaScript and Python; `.copy()` is a deep, independent one.
- **Assigning copies a value in**, so one value set under two keys is two values.
- `int()` is exact to 64 bits for a number written whole, and raises on a fraction.
- Replacing a value leaves the old node behind until `copy()` or `save` drops it, so a document
  rewritten every frame for a long time is kept small with `doc = doc.copy()`.
- **Saving:** `save(path, indent=2)`; `indent=0` is the printed form. Infinite and NaN numbers
  raise from `save`, and print as `null`.
