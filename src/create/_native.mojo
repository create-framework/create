"""Passing values across a C boundary by address.

`core`'s `_Driver` calls a program's `create` and `update` through C
function pointers, so the program, the `Context` and the `Canvas` cross as
plain addresses: `address(value)` on one side, `at[T](address)` on the
other. Both sides are compiled from the same source, so the value at an
address has the layout its type says.

Two rules keep that sound:

- A local passed only by address is kept alive past the call by hand
  (`_ = value^`): a local is dropped after its last named use.
- A value the other side writes lives in a `Slot`, never in a plain local:
  the compiler sees the address only as an `Int`, so it may keep using the
  local's initial value after the call and miss what was written.

A leaf: it imports nothing from `create`, and nothing re-exports it.
"""

from std.memory import Allocation, Layout, alloc, dealloc


def address[T: AnyType](ref value: T) -> Int:
    """`value`'s address, to pass across the boundary."""
    return Int(Pointer(to=value))


def at[T: AnyType](address: Int) -> ref[MutUntrackedOrigin] T:
    """The value at `address`, passed across the boundary."""
    return Pointer[T, MutUntrackedOrigin](unsafe_from_address=address)[]


struct Slot[T: Deinitable & Movable](Movable):
    """A value the other side of the boundary writes, kept on the heap.

    A local passed by address alone looks unchanged to the compiler, which
    sees the address only as an `Int`: it may keep using the value the local
    was initialised with, so an error message written into an empty `String`
    reads back empty. A slot's value lives in heap memory whose address has
    escaped, so the compiler reads it again after the call.
    """

    var _address: Int

    def __init__(out self, var value: Self.T):
        var allocation = alloc(Layout[Self.T](count=1))
        allocation.unsafe_ptr().unsafe_write(value^)
        self._address = Int(allocation^.unsafe_leak())

    def address(self) -> Int:
        """Where the other side reads or writes the value."""
        return self._address

    def take(deinit self) -> Self.T:
        """The value, as the other side left it."""
        return _take[Self.T](self._address)

    def __deinit__(deinit self):
        _ = _take[Self.T](self._address)


def _take[T: Deinitable & Movable](address: Int) -> T:
    """Move the value out of the heap cell at `address`, and free it."""
    var pointer = Pointer[T, MutUntrackedOrigin](unsafe_from_address=address)
    var value = pointer.unsafe_take_pointee()
    dealloc(Allocation(unsafe_owned_ptr=pointer, layout=Layout[T](count=1)))
    return value^


def check(ok: Bool, var error: Slot[String]) raises:
    """Raise the message in `error` when a callback reported failure."""
    if not ok:
        raise Error(error^.take())
