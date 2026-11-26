"""`TableRow`: one row of a `Table`."""

from std.memory import ArcPointer

from ._header import _Header


struct TableRow(Copyable, Movable):
    """One row of a `Table`, its cells reached by column name or index.

    Cells are kept as the text the file held and parsed on read, so a row
    loads and saves without losing anything. A row shorter than the table
    reads its missing cells as empty.

    ```mojo
    for ref row in scores.rows():
        canvas.text(row.string("name"), (0, y))
        var points = row.float("score")
    ```
    """

    var _cells: List[String]
    var _header: ArcPointer[_Header]

    def __init__(
        out self, *, var _cells: List[String], _header: ArcPointer[_Header]
    ):
        self._cells = _cells^
        self._header = _header

    def string(self, column: String) raises -> String:
        """The cell in the named column, as written."""
        return self._cell(self._column_index(column))

    def string(self, column: Int) raises -> String:
        """The cell in column `column`, from 0, as written."""
        return self._cell(self._checked_index(column))

    def float(self, column: String) raises -> Float64:
        """The cell in the named column, parsed as a number."""
        return self._float(self._column_index(column), column)

    def float(self, column: Int) raises -> Float64:
        """The cell in column `column`, from 0, parsed as a number."""
        return self._float(self._checked_index(column), String(column))

    def int(self, column: String) raises -> Int:
        """The cell in the named column, parsed as a whole number."""
        return self._int(self._column_index(column), column)

    def int(self, column: Int) raises -> Int:
        """The cell in column `column`, from 0, parsed as a whole number."""
        return self._int(self._checked_index(column), String(column))

    def bool(self, column: String) raises -> Bool:
        """The cell in the named column as a truth value: `true` or `1`,
        `false` or `0`, case folded."""
        return self._bool(self._column_index(column), column)

    def bool(self, column: Int) raises -> Bool:
        """The cell in column `column`, from 0, as a truth value."""
        return self._bool(self._checked_index(column), String(column))

    def set(mut self, column: String, var value: String) raises:
        """Set the cell in the named column."""
        self._set(self._column_index(column), value^)

    def set(mut self, column: Int, var value: String) raises:
        """Set the cell in column `column`, from 0."""
        self._set(self._header[].checked(column), value^)

    def set(mut self, column: String, value: Float64) raises:
        """Set the cell in the named column to a number."""
        self._set(self._column_index(column), String(value))

    def set(mut self, column: Int, value: Float64) raises:
        """Set the cell in column `column`, from 0, to a number."""
        self._set(self._header[].checked(column), String(value))

    def set(mut self, column: String, value: Int) raises:
        """Set the cell in the named column to a whole number."""
        self._set(self._column_index(column), String(value))

    def set(mut self, column: Int, value: Int) raises:
        """Set the cell in column `column`, from 0, to a whole number."""
        self._set(self._header[].checked(column), String(value))

    def set(mut self, column: String, value: Bool) raises:
        """Set the cell in the named column to `true` or `false`."""
        self._set(self._column_index(column), _bool_text(value))

    def set(mut self, column: Int, value: Bool) raises:
        """Set the cell in column `column`, from 0, to `true` or `false`."""
        self._set(self._header[].checked(column), _bool_text(value))

    def _set(mut self, index: Int, var value: String):
        while len(self._cells) <= index:
            self._cells.append("")
        self._cells[index] = value^

    def _cell(self, index: Int) -> String:
        if index < len(self._cells):
            return self._cells[index]
        return ""

    def _column_index(self, column: String) raises -> Int:
        return self._header[].index(column)

    def _checked_index(self, column: Int) raises -> Int:
        var count = max(len(self._header[].names), len(self._cells))
        if column < 0 or column >= count:
            raise Error(
                "no column "
                + String(column)
                + ": the table has "
                + String(count)
            )
        return column

    def _float(self, index: Int, column: String) raises -> Float64:
        var text = self._cell(index)
        try:
            return atof(text.strip())
        except:
            raise Error(
                'column "' + column + '" holds "' + text + '", not a number'
            )

    def _int(self, index: Int, column: String) raises -> Int:
        var text = self._cell(index)
        try:
            return Int(String(text.strip()))
        except:
            raise Error(
                'column "'
                + column
                + '" holds "'
                + text
                + '", not a whole number'
            )

    def _bool(self, index: Int, column: String) raises -> Bool:
        var text = self._cell(index)
        var folded = String(text.strip()).lower()
        if folded == "true" or folded == "1":
            return True
        if folded == "false" or folded == "0":
            return False
        raise Error(
            'column "' + column + '" holds "' + text + '", not true or false'
        )


def _bool_text(value: Bool) -> String:
    return "true" if value else "false"
