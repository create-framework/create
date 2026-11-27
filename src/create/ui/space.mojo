"""`Space`: room left empty in a column or a row of a `UI`."""

from create.math import OptionalNumber


struct Space(Copyable, Movable):
    """Room left empty in a column, or a row, such as to set one group of
    widgets apart from the next: twice the `UI`'s `spacing` unless given an
    `amount`."""

    var amount: OptionalNumber

    def __init__(out self, amount: OptionalNumber = None):
        self.amount = amount._value
