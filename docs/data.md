# Data

Reading and writing data files: tables of rows and columns (CSV and TSV), and JSON.

## Tables

A `Table` is rows of text cells from CSV or TSV, like Processing's. A high-score list, read from
text and sorted:

```mojo
from create import *


@fieldwise_init
struct Scores(Program):
    var table: Table

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Scores:
        var table = Table.parse("name,score\nAda,120\nGrace,95\nAlan,140")
        table.sort("score", descending=True)
        return Scores(table^)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        var y = 100.0
        for ref row in self.table.rows():
            canvas.text(row.string("name") + ": " + String(row.int("score")), (0, y))
            y -= 40


def main() raises:
    run[Scores]("Scores")
```

Loading, editing and saving a file:

```mojo
# With scores.csv's header line "name,score":
var table = Table.load("scores.csv")
for ref row in table.rows():
    print(row.string("name"), row.int("score"))

ref row = table.add_row()
row.set("name", "Ada")
row.set("score", 120)
table.sort("score", descending=True)
table.save("scores.csv")
```

- **Loading:** `Table.load(path)` reads a file, `Table.parse(text)` a string, and
  `Table(columns)` builds an empty one. The first line names the columns unless `header=False`.
  The separator is a tab for `.tsv`/`.tab` and a comma otherwise, unless `separator=` names one.
- **Rows by reference:** `t.row(i)` and `for ref row in t.rows()` edit in place, and
  `ref row = t.add_row()` returns the new row.
- **Cells stay text until read:** `row.string`, `float`, `int` and `bool`, by column name or index,
  read the text on each call, and raise an error naming the column and cell when it isn't that type.
- **`sort(column, descending=)`** is stable, and numeric only when every cell in the column is a
  number, so one blank sorts the column as text.
- **`save`** quotes a field only when it must.

## JSON

`JSON` is one type for every JSON value:

```mojo
# With config.json as {"player": {"speed": 2.5}, "enemies": [{"hp": 3}, {"hp": 5}]}:
var config = JSON.load("config.json")
var speed = config["player"]["speed"].float()
config["player"]["speed"] = 3.0  # edits the document
for enemy in config["enemies"].values():
    enemy["hp"] = enemy["hp"].int() + 1  # edits land in `config`
config.save("config.json")
```

- **Reading:** `[]` by key or index, then `float`, `int`, `string` or `bool`; `kind()` is a
  `JSONKind`. `values()` is an array's items or an object's values, `keys()` an object's keys and
  `items()` its `(key, value)` pairs, as in Python.
- **A value is a handle into a shared document:** `[]`, `values()` and `items()` copy nothing, and
  edits land in the document (`config["player"]["speed"] = 3.0`, or `enemy["hp"] = ...` in a loop
  over `values()`). So **`var p = config["player"]` doesn't copy**: a change made through `p`
  changes `config` too, as in Processing, JavaScript and Python. `.copy()` makes a deep,
  independent copy.
- **Assigning stores a copy**, so the same value set under two keys becomes two independent
  values.
- `int()` is exact to 64 bits for a number written whole, and raises on a fraction.
- Replacing a value leaves the old node behind until `copy()` or `save` drops it, so a document
  rewritten every frame for a long time is kept small with `doc = doc.copy()`.
- **Saving:** `save(path, indent=2)`; `indent=0` writes it all on one line, as `print` shows it.
  Infinite and NaN numbers raise from `save`, and print as `null`.
