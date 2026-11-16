# Table

```mojo
struct Table
```

Rows of text cells read from CSV or TSV, like Processing's `Table`.

The first line names the columns unless loaded with `header=False`.
Rows are handed out by reference, so reading a cell copies nothing:

```mojo
var scores = Table.load("scores.csv")
var best = scores.row(0).string("name")
for ref row in scores.rows():
    total += row.int("score")
```

Implements `Copyable`, `Deinitable`, `Movable`.

## Constructors

```mojo
@staticmethod
def __init__(out self, var columns: List[String])
```

An empty table with these column names, to fill with `add_row`.

### `load`

```mojo
@staticmethod
def load(
    path: String,
    header: Bool = True,
    separator: Optional[String] = None,
) raises -> Self
```

Load a CSV or TSV file.

The separator is a tab for a `.tsv` file and a comma otherwise,
unless `separator` names one. Quoted fields may hold separators,
newlines and doubled quotes, as RFC 4180 has it.

A relative `path` is resolved against the directory of the calling
source file, not the working directory, as `Image.load`'s is.

### `parse`

```mojo
@staticmethod
def parse(text: String, header: Bool = True, separator: String = ",") raises -> Self
```

Parse CSV or TSV text already in memory.

## Methods

### `row_count`

```mojo
def row_count(self) -> Int
```

The number of rows, the header line not counted.

### `column_count`

```mojo
def column_count(self) -> Int
```

The number of columns: the header's, or the widest row's.

### `columns`

```mojo
def columns(self) -> List[String]
```

The column names, or an empty list for a table with no header.

### `has_column`

```mojo
def has_column(self, name: String) -> Bool
```

Whether a column has this name.

### `row`

```mojo
def row(ref self, index: Int) -> ref[self._rows["element"]] TableRow
```

Row `index`, from 0 to `row_count() - 1`, by reference.

### `rows`

```mojo
def rows(ref self) -> Span[TableRow, origin_of(self._rows)]
```

Every row, in order, by reference: `for ref row in t.rows()`.

Rows can be edited through it but not added or removed; that is
`add_row` and `remove_row`.

### `add_row`

```mojo
def add_row(mut self) -> ref[self._rows["element"]] TableRow
```

Append an empty row and return it, to fill with `set`.

```mojo
ref row = scores.add_row()
row.set("name", "Ada")
row.set("score", 120)
```

```mojo
def add_row(mut self, var cells: List[String]) raises
```

Append a row of cells, one per column in order.

A table with a header takes exactly one cell per column; one without
grows to fit a longer row.

### `add_column`

```mojo
def add_column(mut self, name: String) raises
```

Append a column, empty in every row.

### `remove_column`

```mojo
def remove_column(mut self, name: String) raises
```

Remove the named column from the header and every row; the columns after it move left by one.

```mojo
def remove_column(mut self, index: Int) raises
```

Remove column `index`, from 0, as the named form.

### `remove_row`

```mojo
def remove_row(mut self, index: Int) raises
```

Remove row `index`; the rows after it move up by one.

### `find_row_index`

```mojo
def find_row_index(self, column: String, value: String) raises -> Optional[Int]
```

The index of the first row whose cell in the named column is exactly `value`, or `None`; `row(index)` reaches it by reference.

An index rather than the row, since there is no optional reference:
`ref row = t.row(t.find_row_index("name", "Ada").value())`.

```mojo
def find_row_index(self, column: Int, value: String) raises -> Optional[Int]
```

The index of the first row whose cell in column `column` is exactly `value`, or `None`.

### `find_row_indices`

```mojo
def find_row_indices(self, column: String, value: String) raises -> List[Int]
```

The indices of every row whose cell in the named column is exactly `value`, in order.

```mojo
def find_row_indices(self, column: Int, value: String) raises -> List[Int]
```

The indices of every row whose cell in column `column` is exactly `value`, in order.

### `sort`

```mojo
def sort(mut self, column: String, descending: Bool = False) raises
```

Order the rows by the named column, smallest first.

By number when every cell in the column is one, so `"10"` follows
`"9"`; by text otherwise. Stable: rows that tie keep their order.

```mojo
def sort(mut self, column: Int, descending: Bool = False) raises
```

Order the rows by column `column`, from 0, as the named form.

### `save`

```mojo
def save(self, path: String, separator: Optional[String] = None) raises
```

Write the table as CSV or TSV, the header line first.

The separator follows `load`'s rule. A field is quoted only when it
holds the separator, a quote or a line break, so a file `load` read
is written back as it was. A relative `path` is resolved against the
directory of the calling source file, as `load`'s is.
