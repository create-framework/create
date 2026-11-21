"""The compiled half of the library, `libcreate`, and how a program reaches it.

Most of Create is machinery a program never names: the run loops, the
window, both replays, text layout and the capture encoders. Compiled from
source into every program, it took most of each build, and the compiler's
cache could not help, since a cache entry is per program and any edit to the
program misses it. So that machinery is compiled once, into a shared library
(`src/native/libcreate.mojo`, built by `pixi run native`), and a program
calls into it through the few entry points this module wraps. What a program
does name, such as the value types and `Canvas`'s recording calls, stays Mojo
source, so the compiler inlines and specialises it as before.

**Both halves are built from the same source,** so a struct has the same
layout in each, and a value crosses the boundary as a plain address: the
program passes `Int(Pointer(to=canvas))`, and the library reads the `Canvas`
there. Both allocate through the Mojo runtime's shared allocator, and its
named globals (`_Global`) are process-wide, so a value allocated on one side
may be freed on the other and the run clock is one clock. The library
refuses a program whose `Context`, `Canvas` or `Backend` has another size,
the sign of a library built from other source.

**A call site picks its half at compile time.** The library is built with
`-D CREATE_LIBRARY_BUILD`, so `IN_LIBRARY` is true there: a call site that
reaches the machinery calls it directly inside the library, and through
`entry` everywhere else. Only the library's own build elaborates the
machinery.

The library is found, in order:

1. at the path in the environment variable `CREATE_LIBRARY`, which the pixi
   tasks and the test scripts set to the copy they built;
2. in the environment's `lib` directory, from `CONDA_PREFIX`, where the
   conda package installs it;
3. on macOS, as `@rpath/libcreate.dylib`: a built program run outside the
   environment, through the run path `mojo build` gave it. macOS applies an
   executable's run path only to `@rpath/` names, so the bare name below
   would miss it (as `_library.mojo` explains for the other libraries);
4. by its bare name, through the platform's own search, which on Linux covers
   a built program's run path.

A leaf: it imports nothing from `create`, and nothing re-exports it.
"""

from std.ffi import _DLHandle, _Global
from std.memory import Allocation, Layout, alloc, dealloc
from std.os import abort, getenv
from std.os.path import exists
from std.sys import is_defined, size_of
from std.sys.info import CompilationTarget

comptime IN_LIBRARY = is_defined["CREATE_LIBRARY_BUILD"]()
"""Whether this is the library's own build, where call sites call the
machinery directly rather than through `entry`."""


def _file_name() -> String:
    comptime if CompilationTarget.is_macos():
        return "libcreate.dylib"
    else:
        return "libcreate.so"


struct _Library(Movable):
    """The opened library, or why it could not be opened."""

    var handle: Optional[_DLHandle]
    var error: String

    def __init__(out self):
        self.handle = None
        self.error = ""
        var candidates = List[String]()
        var explicit = getenv("CREATE_LIBRARY")
        if explicit:
            candidates.append(explicit)
        var prefix = getenv("CONDA_PREFIX")
        if prefix:
            candidates.append(prefix + "/lib/" + _file_name())
        comptime if CompilationTarget.is_macos():
            candidates.append("@rpath/" + _file_name())
        candidates.append(_file_name())
        for candidate in candidates:
            # An absolute path is opened only where it exists, so the error
            # names the last place looked rather than a missing file earlier
            # on.
            if candidate.startswith("/") and not exists(candidate):
                self.error = String(candidate, " does not exist")
                continue
            try:
                self.handle = _DLHandle(candidate)
                return
            except e:
                self.error = String(e)


def _open_library() -> _Library:
    return _Library()


comptime _LIBRARY = _Global["create_native_library", _open_library]


def _library() raises -> _DLHandle:
    var library: Pointer[_Library, MutUntrackedOrigin]
    try:
        library = _LIBRARY.get_or_create_ptr()
    except e:
        abort(String("create: no memory for the library handle: ", e))
    if not library[].handle:
        raise Error(
            "create: could not load its compiled library, ",
            _file_name(),
            " (",
            library[].error,
            (
                "). Run the program through pixi, or set CREATE_LIBRARY to the"
                " library's path."
            ),
        )
    return library[].handle.value()


def entry[T: TrivialRegisterPassable](name: StaticString) raises -> T:
    """The library's exported function `name`, as the function type `T`."""
    return _library().get_function[T](String(name))


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
    """Raise the message in `error` when an entry point reported failure."""
    if not ok:
        raise Error(error^.take())
