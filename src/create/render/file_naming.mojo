from std.ffi import _Global
from std.os import abort, listdir

from create._native import IN_LIBRARY, Slot, address, check, entry


struct FileNaming(Copyable, Equatable, ImplicitlyCopyable, Movable, Writable):
    """How a capture's file is named from the path it is given.

    | Naming | File |
    |---|---|
    | `EXACT` | The path as given, replacing a file already there |
    | `NUMBERED` | A number added before the extension, `image-0001.png`, one more than the highest already in the folder |

    `canvas.save_image`, `save_screenshot` and `start_recording` take it as
    `naming=`. Given a path, they use it `EXACT` unless told otherwise; with
    no path, they save `NUMBERED`, as `image`, `screenshot` or `recording`,
    so a capture never replaces an earlier one:

    ```mojo
    # In `update`:
    canvas.save_image()  # image-0001.png, then image-0002.png, …
    canvas.save_image("poster.png")  # poster.png, replaced each time
    canvas.save_image("frames/frame.png", naming=FileNaming.NUMBERED)
    ```

    A number has four digits, and more once it passes 9999. The first
    numbered save to a name in a run looks in its folder for the highest
    number already there, so a new run carries on after the last one rather
    than starting again from 1. A type of its own, so a bare number never
    passes for one.
    """

    var value: Int

    comptime EXACT = FileNaming(0)
    comptime NUMBERED = FileNaming(1)

    def __init__(out self, value: Int):
        self.value = value

    def __eq__(self, other: FileNaming) -> Bool:
        return self.value == other.value

    def __ne__(self, other: FileNaming) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        if self == FileNaming.EXACT:
            writer.write("FileNaming.EXACT")
        elif self == FileNaming.NUMBERED:
            writer.write("FileNaming.NUMBERED")
        else:
            writer.write("FileNaming(", self.value, ")")


comptime _NumberedPath = def(Int, Int, Int) thin abi("C") -> Bool


def _capture_path(
    resolved: String, given: Bool, naming: Optional[FileNaming]
) raises -> String:
    """The file a capture writes: `resolved`, numbered when `naming` says so,
    or, left unset, when no path was `given`."""
    var default = FileNaming.EXACT if given else FileNaming.NUMBERED
    if naming.or_else(default) == FileNaming.NUMBERED:
        return _numbered_path(resolved)
    return resolved


def _numbered_path(path: String) raises -> String:
    """`path` with the run's next number for it added before the extension."""
    comptime if IN_LIBRARY:
        return _numbered_path_here(path)
    else:
        var result = Slot(String())
        var error = Slot(String())
        var ok = entry[_NumberedPath, "create_numbered_path"]()(
            address(path), result.address(), error.address()
        )
        check(ok, error^)
        return result^.take()


struct _FileNumbers(Movable):
    """The last number handed out for each numbered path, for the whole
    process, so two canvases saving to one name don't reuse a number."""

    var last: Dict[String, Int]

    def __init__(out self):
        self.last = Dict[String, Int]()


def _new_file_numbers() -> _FileNumbers:
    return _FileNumbers()


comptime _FILE_NUMBERS = _Global["create_file_numbers", _new_file_numbers]


def _numbered_path_here(path: String) raises -> String:
    """`_numbered_path`, in the library.

    The first time a path is numbered in a run, its folder is read for the
    highest number already used; after that the count is kept here, so a
    save every frame doesn't read the folder every frame.
    """
    var slash = path.rfind("/")
    var folder = String(path[byte = : slash + 1])
    var name = String(path[byte = slash + 1 :])
    var dot = name.rfind(".")
    var stem = name
    var extension = String()
    if dot > 0:
        stem = String(name[byte=:dot])
        extension = String(name[byte=dot:])
    var numbers: Pointer[_FileNumbers, MutUntrackedOrigin]
    try:
        numbers = _FILE_NUMBERS.get_or_create_ptr()
    except e:
        # Only fails if the runtime cannot allocate the global at all.
        abort(String("create: the file numbers are unavailable: ", e))
    var last: Int
    if path in numbers[].last:
        last = numbers[].last[path]
    else:
        last = _highest_number(folder, stem + "-", extension)
    var number = last + 1
    numbers[].last[path] = number
    return folder + stem + "-" + _padded(number) + extension


def _highest_number(folder: String, prefix: String, extension: String) -> Int:
    """The highest number in a file in `folder` named `prefix`, digits, then
    `extension`, or 0 when there is none or the folder can't be read."""
    var entries: List[String]
    try:
        entries = listdir(folder if folder else ".")
    except:
        return 0
    var highest = 0
    for file in entries:
        if not file.startswith(prefix) or not file.endswith(extension):
            continue
        var start = prefix.byte_length()
        var end = file.byte_length() - extension.byte_length()
        # Nine digits at most, so the number can't overflow.
        if end <= start or end - start > 9:
            continue
        var number = 0
        var all_digits = True
        for byte in file.as_bytes()[start:end]:
            var digit = Int(byte) - ord("0")
            if digit < 0 or digit > 9:
                all_digits = False
                break
            number = number * 10 + digit
        if all_digits:
            highest = max(highest, number)
    return highest


def _padded(number: Int) -> String:
    """`number` with zeros before it, to four digits at least."""
    var digits = String(number)
    while digits.byte_length() < 4:
        digits = "0" + digits
    return digits
