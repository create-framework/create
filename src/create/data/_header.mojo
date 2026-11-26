"""`_Header`: a table's column names, shared by a `Table` and its rows."""


@fieldwise_init
struct _Header(Copyable, Movable):
    """A table's column names, shared by the table and every row.

    `named` is False for a table loaded with `header=False`: its columns are
    reached by index only, and `names` holds one empty string per column.
    """

    var names: List[String]
    var named: Bool

    def index(self, column: String) raises -> Int:
        """The index of the named column; raises if there is none."""
        if not self.named:
            raise Error(
                'no column "'
                + column
                + '": the table has no header, reach columns by index'
            )
        for i in range(len(self.names)):
            if self.names[i] == column:
                return i
        raise Error('no column "' + column + '"')

    def checked(self, column: Int) raises -> Int:
        """`column` itself if the header has it; raises otherwise."""
        if column < 0 or column >= len(self.names):
            raise Error(
                "no column "
                + String(column)
                + ": the table has "
                + String(len(self.names))
            )
        return column
