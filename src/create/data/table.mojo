from std.memory import ArcPointer

from create._path import _caller_relative

from ._header import _Header
from .table_row import TableRow


struct Table(Copyable, Movable):
    """Rows of text cells read from CSV or TSV, like Processing's `Table`.

    The first line names the columns unless loaded with `header=False`.
    Rows are handed out by reference, so reading a cell copies nothing:

    ```mojo
    var scores = Table.load("scores.csv")
    var best = scores.row(0).string("name")
    for ref row in scores.rows():
        total += row.int("score")
    ```
    """

    var _header: ArcPointer[_Header]
    var _rows: List[TableRow]

    def __init__(
        out self, *, var _records: List[List[String]], _has_header: Bool
    ):
        var records = _records^
        var header = _has_header
        var names: List[String]
        var start = 0
        if header and len(records) > 0:
            names = records[0].copy()
            start = 1
        else:
            var width = 0
            for record in records:
                width = max(width, len(record))
            names = List[String](length=width, fill="")
        self._header = ArcPointer(_Header(names^, header))
        self._rows = List[TableRow](capacity=len(records) - start)
        for i in range(start, len(records)):
            self._rows.append(
                TableRow(_cells=records[i].copy(), _header=self._header)
            )

    def __init__(out self, var columns: List[String]):
        """An empty table with these column names, to fill with `add_row`."""
        self._header = ArcPointer(_Header(columns^, True))
        self._rows = []

    @staticmethod
    @always_inline
    def load(
        path: String,
        header: Bool = True,
        separator: Optional[String] = None,
    ) raises -> Table:
        """Load a CSV or TSV file.

        The separator is a tab for a `.tsv` file and a comma otherwise,
        unless `separator` names one. Quoted fields may hold separators,
        newlines and doubled quotes, as RFC 4180 has it.

        A relative `path` is resolved against the directory of the calling
        source file, not the working directory, as `Image.load`'s is.
        """
        return Table._load(_caller_relative(path), header, separator)

    @staticmethod
    def _load(
        path: String, header: Bool, separator: Optional[String]
    ) raises -> Table:
        """`load`, from a path already resolved."""
        var text: String
        with open(path, "r") as f:
            text = f.read()
        return Table(
            _records=_parse_delimited(
                text, _separator_for(path, separator), path
            ),
            _has_header=header,
        )

    @staticmethod
    def parse(
        text: String, header: Bool = True, separator: String = ","
    ) raises -> Table:
        """Parse CSV or TSV text already in memory."""
        return Table(
            _records=_parse_delimited(text, separator, "<input>"),
            _has_header=header,
        )

    def row_count(self) -> Int:
        """The number of rows, the header line not counted."""
        return len(self._rows)

    def column_count(self) -> Int:
        """The number of columns: the header's, or the widest row's."""
        return len(self._header[].names)

    def columns(self) -> List[String]:
        """The column names, or an empty list for a table with no header."""
        if not self._header[].named:
            return []
        return self._header[].names.copy()

    def has_column(self, name: String) -> Bool:
        """Whether a column has this name."""
        return self._header[].named and name in self._header[].names

    def row(ref self, index: Int) -> ref[self._rows[0]] TableRow:
        """Row `index`, from 0 to `row_count() - 1`, by reference."""
        return self._rows[index]

    def rows(ref self) -> Span[TableRow, origin_of(self._rows)]:
        """Every row, in order, by reference: `for ref row in t.rows()`.

        Rows can be edited through it but not added or removed; that is
        `add_row` and `remove_row`.
        """
        return Span(self._rows)

    def add_row(mut self) -> ref[self._rows[0]] TableRow:
        """Append an empty row and return it, to fill with `set`.

        ```mojo
        ref row = scores.add_row()
        row.set("name", "Ada")
        row.set("score", 120)
        ```
        """
        self._rows.append(TableRow(_cells=[], _header=self._header))
        return self._rows[len(self._rows) - 1]

    def add_row(mut self, var cells: List[String]) raises:
        """Append a row of cells, one per column in order.

        A table with a header takes exactly one cell per column; one without
        grows to fit a longer row.
        """
        var header = self._header[].copy()
        if header.named and len(cells) != len(header.names):
            raise Error(
                "a row of "
                + String(len(cells))
                + " cells for "
                + String(len(header.names))
                + " columns"
            )
        if len(cells) > len(header.names):
            header.names.resize(len(cells), "")
            self._replace_header(header^)
        self._rows.append(TableRow(_cells=cells^, _header=self._header))

    def add_column(mut self, name: String) raises:
        """Append a column, empty in every row."""
        var header = self._header[].copy()
        if not header.named:
            raise Error(
                'cannot add column "'
                + name
                + '": the table has no header to name it in'
            )
        if name in header.names:
            raise Error('column "' + name + '" already exists')
        header.names.append(name)
        self._replace_header(header^)

    def remove_column(mut self, name: String) raises:
        """Remove the named column from the header and every row; the
        columns after it move left by one."""
        self._remove_column(self._header[].index(name))

    def remove_column(mut self, index: Int) raises:
        """Remove column `index`, from 0, as the named form."""
        self._remove_column(self._header[].checked(index))

    def _remove_column(mut self, index: Int):
        var header = self._header[].copy()
        _ = header.names.pop(index)
        self._replace_header(header^)
        for ref row in self._rows:
            if index < len(row._cells):
                _ = row._cells.pop(index)

    def remove_row(mut self, index: Int) raises:
        """Remove row `index`; the rows after it move up by one."""
        if index < 0 or index >= len(self._rows):
            raise Error(
                "no row "
                + String(index)
                + ": the table has "
                + String(len(self._rows))
            )
        _ = self._rows.pop(index)

    def find_row_index(
        self, column: String, value: String
    ) raises -> Optional[Int]:
        """The index of the first row whose cell in the named column is
        exactly `value`, or `None`; `row(index)` reaches it by reference.

        An index rather than the row, since there is no optional reference:
        `ref row = t.row(t.find_row_index("name", "Ada").value())`."""
        return self._find_row_index(self._header[].index(column), value)

    def find_row_index(
        self, column: Int, value: String
    ) raises -> Optional[Int]:
        """The index of the first row whose cell in column `column` is
        exactly `value`, or `None`."""
        return self._find_row_index(self._header[].checked(column), value)

    def find_row_indices(
        self, column: String, value: String
    ) raises -> List[Int]:
        """The indices of every row whose cell in the named column is
        exactly `value`, in order."""
        return self._find_row_indices(self._header[].index(column), value)

    def find_row_indices(self, column: Int, value: String) raises -> List[Int]:
        """The indices of every row whose cell in column `column` is
        exactly `value`, in order."""
        return self._find_row_indices(self._header[].checked(column), value)

    def sort(mut self, column: String, descending: Bool = False) raises:
        """Order the rows by the named column, smallest first.

        By number when every cell in the column is one, so `"10"` follows
        `"9"`; by text otherwise. Stable: rows that tie keep their order.
        """
        self._sort(self._header[].index(column), descending)

    def sort(mut self, column: Int, descending: Bool = False) raises:
        """Order the rows by column `column`, from 0, as the named form."""
        self._sort(self._header[].checked(column), descending)

    def _find_row_index(self, index: Int, value: String) -> Optional[Int]:
        for i in range(len(self._rows)):
            if self._rows[i]._cell(index) == value:
                return i
        return None

    def _find_row_indices(self, index: Int, value: String) -> List[Int]:
        var found = List[Int]()
        for i in range(len(self._rows)):
            if self._rows[i]._cell(index) == value:
                found.append(i)
        return found^

    def _sort(mut self, index: Int, descending: Bool):
        var numbers = List[Float64](capacity=len(self._rows))
        var texts = List[String](capacity=len(self._rows))
        var numeric = True
        for ref row in self._rows:
            var text = row._cell(index)
            if numeric:
                try:
                    numbers.append(atof(text.strip()))
                except:
                    numeric = False
            texts.append(text^)
        var order = _stable_order(
            numbers, descending
        ) if numeric else _stable_order(texts, descending)
        var sorted = List[TableRow](capacity=len(self._rows))
        for i in order:
            sorted.append(self._rows[i].copy())
        self._rows = sorted^

    @always_inline
    def save(self, path: String, separator: Optional[String] = None) raises:
        """Write the table as CSV or TSV, the header line first.

        The separator follows `load`'s rule. A field is quoted only when it
        holds the separator, a quote or a line break, so a file `load` read
        is written back as it was. A relative `path` is resolved against the
        directory of the calling source file, as `load`'s is.
        """
        self._save(_caller_relative(path), separator)

    def _save(self, path: String, separator: Optional[String]) raises:
        """`save`, to a path already resolved."""
        var text = self._format(_separator_for(path, separator))
        with open(path, "w") as f:
            f.write(text)

    def _format(self, separator: String) raises -> String:
        if separator.byte_length() != 1:
            raise Error(
                'separator must be a single character, not "' + separator + '"'
            )
        var out = String()
        var width = len(self._header[].names)
        if self._header[].named:
            _write_record(out, self._header[].names, width, separator)
        for ref row in self._rows:
            _write_record(out, row._cells, width, separator)
        return out^

    def _replace_header(mut self, var header: _Header):
        """Point the table and every row at a new header.

        A header is never edited in place: a copied table shares it.
        """
        self._header = ArcPointer(header^)
        for ref row in self._rows:
            row._header = self._header


def _stable_order[
    T: Copyable & Comparable
](keys: List[T], descending: Bool) -> List[Int]:
    """The indices of `keys` in sorted order, ties in their original order.

    A bottom-up merge sort: a merge takes from the left run unless the right
    one is strictly first, which is what keeps ties in place either way.
    """
    var n = len(keys)
    var order = List[Int](capacity=n)
    for i in range(n):
        order.append(i)
    var scratch = order.copy()
    var width = 1
    while width < n:
        var start = 0
        while start < n:
            var middle = min(start + width, n)
            var end = min(start + 2 * width, n)
            var left = start
            var right = middle
            for slot in range(start, end):
                var take_right = right < end and (
                    left >= middle
                    or _precedes(
                        keys[order[right]], keys[order[left]], descending
                    )
                )
                if take_right:
                    scratch[slot] = order[right]
                    right += 1
                else:
                    scratch[slot] = order[left]
                    left += 1
            start = end
        swap(order, scratch)
        width *= 2
    return order^


def _precedes[T: Comparable](a: T, b: T, descending: Bool) -> Bool:
    """Whether `a` sorts strictly before `b`."""
    return a > b if descending else a < b


def _write_record(
    mut out: String, cells: List[String], width: Int, separator: String
):
    """Append one record, padded to `width` cells, and a line break.

    A lone empty field is quoted, or the line would read back as blank and
    be skipped.
    """
    var count = max(width, len(cells))
    if count == 1 and (len(cells) == 0 or cells[0] == ""):
        out += '""\n'
        return
    for i in range(count):
        if i > 0:
            out += separator
        if i < len(cells):
            out += _quoted_if_needed(cells[i], separator)
    out += "\n"


def _quoted_if_needed(field: String, separator: String) -> String:
    if separator in field or '"' in field or "\n" in field or "\r" in field:
        return '"' + field.replace('"', '""') + '"'
    return field


def _separator_for(path: String, separator: Optional[String]) -> String:
    """`separator` if given, else a tab for a `.tsv` or `.tab` path and a
    comma otherwise."""
    if separator:
        return separator.value()
    return "\t" if _is_tsv(path) else ","


def _is_tsv(path: String) -> Bool:
    var lowered = path.lower()
    return lowered.endswith(".tsv") or lowered.endswith(".tab")


def _parse_delimited(
    text: String, separator: String, source: String
) raises -> List[List[String]]:
    """Split delimited text into records of fields.

    Blank lines are skipped. A field opening with a quote runs to the
    matching quote, taking separators and newlines literally and `""` as
    one quote; a quote anywhere else is an ordinary character. Errors name
    `source:line:column`.
    """
    if separator.byte_length() != 1:
        raise Error(
            'separator must be a single character, not "' + separator + '"'
        )
    var sep = separator.as_bytes()[0]
    comptime QUOTE = UInt8(ord('"'))
    comptime NEWLINE = UInt8(ord("\n"))
    comptime RETURN = UInt8(ord("\r"))

    var bytes = text.as_bytes()
    var n = len(bytes)
    var i = 0
    if n >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
        i = 3

    var records = List[List[String]]()
    var record = List[String]()
    var field = List[UInt8]()
    var line = 1
    var line_start = i

    while i < n:
        var at_field_start = len(field) == 0
        var c = bytes[i]
        if c == QUOTE and at_field_start:
            var open_line = line
            var open_column = i - line_start + 1
            i += 1
            while True:
                if i >= n:
                    raise Error(
                        source
                        + ":"
                        + String(open_line)
                        + ":"
                        + String(open_column)
                        + ": unterminated quote"
                    )
                var q = bytes[i]
                if q == QUOTE:
                    if i + 1 < n and bytes[i + 1] == QUOTE:
                        field.append(QUOTE)
                        i += 2
                        continue
                    i += 1
                    break
                if q == NEWLINE:
                    line += 1
                    line_start = i + 1
                field.append(q)
                i += 1
            if (
                i < n
                and bytes[i] != sep
                and bytes[i] != NEWLINE
                and bytes[i] != RETURN
            ):
                raise Error(
                    source
                    + ":"
                    + String(line)
                    + ":"
                    + String(i - line_start + 1)
                    + ": expected a separator after the closing quote"
                )
            # A quoted empty field must still count as a field.
            record.append(String(unsafe_from_utf8=field))
            field.clear()
            if i < n and bytes[i] == sep:
                i += 1
                if i >= n or bytes[i] == NEWLINE or bytes[i] == RETURN:
                    record.append("")
            continue
        if c == sep:
            record.append(String(unsafe_from_utf8=field))
            field.clear()
            i += 1
            if i >= n or bytes[i] == NEWLINE or bytes[i] == RETURN:
                record.append("")
            continue
        if c == NEWLINE or c == RETURN:
            if len(field) > 0:
                record.append(String(unsafe_from_utf8=field))
                field.clear()
            if len(record) > 0:
                records.append(record^)
                record = List[String]()
            i += 1
            if c == RETURN and i < n and bytes[i] == NEWLINE:
                i += 1
            line += 1
            line_start = i
            continue
        field.append(c)
        i += 1

    if len(field) > 0:
        record.append(String(unsafe_from_utf8=field))
    if len(record) > 0:
        records.append(record^)
    return records^
