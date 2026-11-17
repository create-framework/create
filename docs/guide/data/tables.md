# Tables

A table is data in rows and columns, like a spreadsheet: a high-score list, a level's enemy
spawns, the stats of every item in a shop. Tables are usually kept in CSV files (comma-separated
values) or TSV files (tab-separated values), plain text files that every spreadsheet program can
open and save. This page explains how to read, change and save them. Structured data with nesting,
such as a settings file, is better kept as [JSON](json.md).

## Reading a table

A `Table` holds the rows of a CSV or TSV file, each made of cells of text, like Processing's
`Table`. A high-score list, read from a string and sorted from the highest score down:

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

## Loading, changing and saving a file

A file is loaded, changed and saved again like this:

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

- **Loading:** `Table.load(path)` reads a file, `Table.parse(text)` reads a string, and
  `Table(columns)` builds an empty table with the given column names. The first line of a file
  names the columns, unless you pass `header=False`. Cells are separated by tabs in a `.tsv` or
  `.tab` file and by commas otherwise, unless `separator=` names another separator.
- **Changing rows:** `table.row(i)` and `for ref row in table.rows()` give the rows themselves,
  not copies, so setting a cell through them changes the table. `ref row = table.add_row()` adds
  an empty row at the end and gives it back to fill in.
- **Cells are text until you read them** as something else: `row.string`, `row.float`,
  `row.int` and `row.bool` read a cell, by its column's name or its position, and convert the text
  each time. Reading a cell as a type it can't be, such as `"Ada"` as a number, raises an error
  naming the column and the cell.
- **`sort(column, descending=)`** sorts the rows by one column, and keeps rows with equal values in
  the order they were in. It sorts by number only when every cell in the column is a number, so a
  single blank cell makes it sort the whole column alphabetically, as text.
- **`save`** writes the table back to a file. It puts a cell in quotes only when it has to, such as
  when the cell contains a comma.
