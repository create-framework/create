"""`BackendHandle`, the `Backend` a canvas records into, owned on the heap
by the compiled library.

A `Backend` holds both replays, the text renderer and the capture encoders,
so building or dropping one in a program would compile all of that into it.
The handle keeps the `Backend` behind an address instead: the library builds
it and drops it (`new_backend`, `free_backend`), and a program reaches its
fields, the command buffer above all, through `handle[]`, which compiles no
more than the fields it touches. See `create/_native.mojo`.
"""

from std.memory import Allocation, Layout, alloc, dealloc
from std.sys import size_of

from create._native import IN_LIBRARY, Slot, check, entry
from ._backend import Backend


def new_backend() raises -> Int:
    """A new `Backend` on the heap, by address: the library's half of
    `BackendHandle()`."""
    var allocation = alloc(Layout[Backend](count=1))
    var pointer = allocation.unsafe_ptr()
    try:
        pointer.unsafe_write(Backend())
    except e:
        dealloc(allocation^)
        raise e^
    return Int(allocation^.unsafe_leak())


def free_backend(backend: Int):
    """Drop and free the `Backend` at `backend`: the library's half of a
    `BackendHandle`'s destructor."""
    var pointer = Pointer[Backend, MutUntrackedOrigin](
        unsafe_from_address=backend
    )
    _ = pointer.unsafe_take_pointee()
    dealloc(
        Allocation(unsafe_owned_ptr=pointer, layout=Layout[Backend](count=1))
    )


comptime _NewBackend = def(Int, Int) thin abi("C") -> Int
comptime _FreeBackend = def(Int) thin abi("C") -> None


struct BackendHandle(Movable):
    """Owns one `Backend`, built and dropped by the library."""

    var _address: Int

    def __init__(out self) raises:
        comptime if IN_LIBRARY:
            self._address = new_backend()
        else:
            var error = Slot(String())
            # The size doubles as a check that the library was built from
            # this source: a `Backend` of another layout would be misread.
            self._address = entry[_NewBackend]("create_backend_new")(
                size_of[Backend](), error.address()
            )
            check(self._address != 0, error^)

    def __deinit__(deinit self):
        comptime if IN_LIBRARY:
            free_backend(self._address)
        else:
            try:
                entry[_FreeBackend]("create_backend_free")(self._address)
            except:
                pass  # unreachable: the library built this backend

    def __getitem__(ref self) -> ref[self] Backend:
        """The `Backend`, to record into or read.

        The reference's origin is the handle's, not an untracked one: the
        `Backend` lives as long as the handle, and an untracked reference
        would let the handle, and so the `Backend`, be dropped after its
        last named use while the reference is still being used.
        """
        return Pointer[Backend, origin_of(self)](
            unsafe_from_address=self._address
        )[]
