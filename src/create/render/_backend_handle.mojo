"""`BackendHandle`, the `Backend` a canvas records into, owned on the heap.

A `Backend` holds both replays, the text renderer and the capture encoders,
so a canvas that held one by value compiled all of that into every program
that builds or drops a canvas. The handle keeps the `Backend` behind an
address instead: `new_backend` builds it and `free_backend` drops it, and a
canvas reaches its fields, the command buffer above all, through `handle[]`,
which compiles no more than the fields it touches.
"""

from std.memory import Allocation, Layout, alloc, dealloc

from ._backend import Backend


def new_backend() raises -> Int:
    """A new `Backend` on the heap, by address."""
    var allocation = alloc(Layout[Backend](count=1))
    var pointer = allocation.unsafe_ptr()
    try:
        pointer.unsafe_write(Backend())
    except e:
        dealloc(allocation^)
        raise e^
    return Int(allocation^.unsafe_leak())


def free_backend(backend: Int):
    """Drop and free the `Backend` at `backend`."""
    var pointer = Pointer[Backend, MutUntrackedOrigin](
        unsafe_from_address=backend
    )
    _ = pointer.unsafe_take_pointee()
    dealloc(
        Allocation(unsafe_owned_ptr=pointer, layout=Layout[Backend](count=1))
    )


struct BackendHandle(Movable):
    """Owns one `Backend`, on the heap."""

    var _address: Int

    def __init__(out self) raises:
        self._address = new_backend()

    def __deinit__(deinit self):
        free_backend(self._address)

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
