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

A library built from a checkout is refused once any of the checkout's
source is newer than it (`stale_source`): it would run the code from before
the edit. `pixi run native` rebuilds it, or, when the source is the same,
only touches it.

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
from std.os import abort, getenv, listdir, stat
from std.os.path import exists, isdir
from std.reflection import source_location
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
    """Why the library could not be opened, or why it is not to be used:
    empty when `handle` is good to call."""

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
            except e:
                self.error = String(e)
                continue
            if candidate.startswith("/"):
                self.error = _check_source(self.handle.value(), candidate)
            return


comptime _CheckSource = def(Int, Int, Int) thin abi("C") -> Bool
"""`create_check_source`: the library's path, the source file's and an
error `String`'s addresses; `False`, with the error written, if stale."""


def _check_source(handle: _DLHandle, library: String) -> String:
    """`stale_source` for the library just opened at `library`, run by the
    library itself, so that a program doesn't compile the walk: why it would
    run old code, or empty."""
    # As the program was compiled: `<src>/create/_native.mojo`.
    var source = String(source_location().file_name())
    var error = Slot(String())
    if not handle.check_symbol("create_check_source"):
        return String(
            "create: ",
            library,
            (
                " has no create_check_source, so it is older than this program."
                " Rebuild it with `pixi run native`."
            ),
        )
    var check = handle.get_function[_CheckSource]("create_check_source")
    var fresh = check(address(library), address(source), error.address())
    _ = source^  # passed by address only: kept alive past the call
    if not fresh:
        return error^.take()
    return ""


def stale_source(library: String, source: String) -> String:
    """Why the library at `library` would run old code, or empty, for a
    program compiled from `source`, the path of its `_native.mojo`.

    In a checkout of Create, the source a program was compiled from is
    still on disk, and a library built before the last edit to it would run
    the code from before the edit, with nothing to say so. So where that
    source is found, every `.mojo` file of the library's is compared with
    the library's own time, and a newer one makes the library unusable.
    `scripts/build_native.sh` touches a library it finds already built from
    the same source, so a checkout that only changes the files' times is
    cleared by running it. An installed package keeps no source, and is not
    checked.
    """
    var create_dir = String(source[byte = : source.rfind("/")])
    var src = String(create_dir[byte = : create_dir.rfind("/")])
    if not exists(src + "/native/libcreate.mojo"):
        return ""
    try:
        var built = _modified(library)
        var newest = String()
        var newest_time = built
        for directory in [create_dir, src + "/native"]:
            _newest_source(directory, newest, newest_time)
        if newest:
            return String(
                "create: ",
                library,
                " is older than ",
                newest,
                (
                    ", so it would run the code from before that file's last"
                    " change. Rebuild it with `pixi run native`."
                ),
            )
    except:
        pass  # a file that vanished while being read: nothing to compare
    return ""


def _modified(path: String) raises -> Tuple[Int, Int]:
    """`path`'s modification time, as seconds and nanoseconds."""
    var times = stat(path).st_mtimespec
    return (Int(times.tv_sec), Int(times.tv_nsec))


def _newest_source(
    directory: String, mut newest: String, mut newest_time: Tuple[Int, Int]
) raises:
    """Note in `newest` any `.mojo` file under `directory` modified after
    `newest_time`, and move `newest_time` up to it."""
    for name in listdir(directory):
        var path = directory + "/" + name
        if isdir(path):
            _newest_source(path, newest, newest_time)
        elif name.endswith(".mojo"):
            var time = _modified(path)
            if time[0] > newest_time[0] or (
                time[0] == newest_time[0] and time[1] > newest_time[1]
            ):
                newest = path
                newest_time = time


def _open_library() -> _Library:
    return _Library()


comptime _LIBRARY = _Global["create_native_library", _open_library]


def _library() raises -> _DLHandle:
    var library: Pointer[_Library, MutUntrackedOrigin]
    try:
        library = _LIBRARY.get_or_create_ptr()
    except e:
        abort(String("create: no memory for the library handle: ", e))
    if library[].handle and library[].error:
        raise Error(library[].error)
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


struct _Entry(Movable):
    """An entry point's address, or why it could not be found."""

    var address: Int
    var error: String

    def __init__(out self, address: Int, var error: String):
        self.address = address
        self.error = error^


comptime _AnyFunction = def() thin abi("C") -> None
"""What an entry point is looked up as, before `entry` gives it its type."""


def _find[name: StaticString]() -> _Entry:
    try:
        var function = _library().get_function[_AnyFunction](String(name))
        return _Entry(Pointer(to=function).unsafe_bitcast[Int]()[], "")
    except e:
        return _Entry(0, String(e))


@always_inline
def entry[T: TrivialRegisterPassable, name: StaticString]() raises -> T:
    """The library's exported function `name`, as the function type `T`.

    Looked up once, on the first call, and kept in a process-wide global of
    its own: a lookup by name costs a symbol search and a `String`, about
    65 ns, where the global costs about 10, and `canvas.image` makes one
    call per image drawn.
    """
    ref found = _Global[name, _find[name]].get_or_create_ptr()[]
    if found.address == 0:
        raise Error(found.error)
    var opaque = Pointer[NoneType, MutUntrackedOrigin](
        unsafe_from_address=found.address
    )
    return Pointer(to=opaque).unsafe_bitcast[T]()[]


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
