# TableRow

```mojo
struct TableRow
```

One row of a `Table`, its cells reached by column name or index.

Cells are kept as the text the file held and parsed on read, so a row
loads and saves without losing anything. A row shorter than the table
reads its missing cells as empty.

```mojo
for ref row in scores.rows():
    canvas.text(row.string("name"), (0, y))
    var points = row.float("score")
```

Implements `Copyable`, `Deinitable`, `Movable`.

## Methods

### `string`

```mojo
def string(self, column: String) raises -> String
```

The cell in the named column, as written.

```mojo
def string(self, column: Int) raises -> String
```

The cell in column `column`, from 0, as written.

### `float`

```mojo
def float(self, column: String) raises -> Float64
```

The cell in the named column, parsed as a number.

```mojo
def float(self, column: Int) raises -> Float64
```

The cell in column `column`, from 0, parsed as a number.

### `int`

```mojo
def int(self, column: String) raises -> Int
```

The cell in the named column, parsed as a whole number.

```mojo
def int(self, column: Int) raises -> Int
```

The cell in column `column`, from 0, parsed as a whole number.

### `bool`

```mojo
def bool(self, column: String) raises -> Bool
```

The cell in the named column as a truth value: `true` or `1`, `false` or `0`, case folded.

```mojo
def bool(self, column: Int) raises -> Bool
```

The cell in column `column`, from 0, as a truth value.

### `set`

```mojo
def set(mut self, column: String, var value: String) raises
```

Set the cell in the named column.

```mojo
def set(mut self, column: Int, var value: String) raises
```

Set the cell in column `column`, from 0.

```mojo
def set(mut self, column: String, value: Float64) raises
```

Set the cell in the named column to a number.

```mojo
def set(mut self, column: Int, value: Float64) raises
```

Set the cell in column `column`, from 0, to a number.

```mojo
def set(mut self, column: String, value: Int) raises
```

Set the cell in the named column to a whole number.

```mojo
def set(mut self, column: Int, value: Int) raises
```

Set the cell in column `column`, from 0, to a whole number.

```mojo
def set(mut self, column: String, value: Bool) raises
```

Set the cell in the named column to `true` or `false`.

```mojo
def set(mut self, column: Int, value: Bool) raises
```

Set the cell in column `column`, from 0, to `true` or `false`.
