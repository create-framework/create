"""Internal: the `id=` keyword every widget takes."""


struct _WidgetKey(Copyable, ImplicitlyCopyable, Movable):
    """A widget's `id=`: a key added to its ID, or `None` when left unset.

    Not `Optional[...]`, which `id="ada"` or `id=3` cannot reach in the one
    implicit conversion Mojo makes. This takes any `Hashable` value, as
    `ui.id` does, or `None` directly, and keeps only the key's hash. Literals
    have their own constructors, since a literal isn't `Hashable` until it
    is materialised as a `String` or an `Int`."""

    var _hash: Optional[UInt64]

    @implicit
    def __init__[K: Hashable](out self, key: K):
        self._hash = UInt64(hash(key))

    @implicit
    def __init__(out self, key: StringLiteral):
        self._hash = UInt64(hash(String(key)))

    @implicit
    def __init__(out self, key: IntLiteral):
        self._hash = UInt64(hash(Int(key)))

    @implicit
    def __init__(out self, none: NoneType._mlir_type):
        self._hash = None
