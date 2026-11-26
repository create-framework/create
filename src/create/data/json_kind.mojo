"""`JSONKind`: which of JSON's six kinds of value a `JSON` holds."""


struct JSONKind(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """Which of JSON's six kinds of value a `JSON` holds."""

    var value: Int

    comptime NULL = JSONKind(0)
    comptime BOOL = JSONKind(1)
    comptime NUMBER = JSONKind(2)
    comptime STRING = JSONKind(3)
    comptime ARRAY = JSONKind(4)
    comptime OBJECT = JSONKind(5)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: JSONKind) -> Bool:
        return self.value == other.value

    def __ne__(self, other: JSONKind) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        if self == JSONKind.NULL:
            writer.write("JSONKind.NULL")
        elif self == JSONKind.BOOL:
            writer.write("JSONKind.BOOL")
        elif self == JSONKind.NUMBER:
            writer.write("JSONKind.NUMBER")
        elif self == JSONKind.STRING:
            writer.write("JSONKind.STRING")
        elif self == JSONKind.ARRAY:
            writer.write("JSONKind.ARRAY")
        elif self == JSONKind.OBJECT:
            writer.write("JSONKind.OBJECT")
        else:
            writer.write("JSONKind(", self.value, ")")

    def _name(self) -> String:
        """The kind as a sentence names it: "a number", "an object"."""
        if self == JSONKind.NULL:
            return "null"
        if self == JSONKind.BOOL:
            return "a bool"
        if self == JSONKind.NUMBER:
            return "a number"
        if self == JSONKind.STRING:
            return "a string"
        if self == JSONKind.ARRAY:
            return "an array"
        return "an object"
