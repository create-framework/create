from std.ffi import _Global, external_call
from std.os import abort
from std.sys import argv, exit


# A type of its own, like `WindowMode`: it keeps a backend constant from
# binding to a neighbouring `Int` parameter by position (`run_headless(w, h,
# RenderBackend.GPU)` once meant `frames=1` on the CPU, and compiled). The
# constructor is not `@implicit` for the same reason.
struct RenderBackend(
    Copyable, Equatable, ImplicitlyCopyable, Movable, Writable
):
    """Which renderer draws a run's frames: `run`'s and `run_headless`'s
    `backend`.

    Fixed for the run. Both draw the same frame, apart from tiny differences
    along antialiased edges. Compare backends with `==`.
    """

    var value: Int

    comptime CPU = RenderBackend(0)
    """Create's own rasteriser, on the CPU. The default."""
    # replays onto a Surface through _raster.mojo
    comptime GPU = RenderBackend(1)
    """OpenGL 3.3."""
    # replays through GLRenderer: see _gl_backend.mojo

    def __init__(out self, value: Int):
        self.value = value

    @staticmethod
    def from_arguments() -> RenderBackend:
        """The backend named on the command line, `gpu` or `cpu`, or asked for
        in the terminal when neither is named.

        So one build runs on either, `./sketch gpu` or `pixi run example
        shadows gpu`, passed as `run(..., backend=RenderBackend.from_arguments())`.
        When both are named, the last one wins; other arguments are left for
        the program. With neither, it asks in the terminal, and asks again
        until the answer is `gpu` or `cpu`. A program not started from a
        terminal can't be asked, so it prints what to add to the command and
        exits. Calls after the first return the backend chosen first, without
        asking again."""
        var arguments = List[String]()
        var raw = argv()
        for i in range(1, len(raw)):
            arguments.append(String(raw[i]))
        var named = RenderBackend._from_argument_list(arguments)
        if named:
            return named.value()
        var chosen = _chosen_backend()
        if chosen[].value < 0:
            chosen[].value = _ask_for_backend().value
        return RenderBackend(chosen[].value)

    @staticmethod
    def _from_argument_list(
        arguments: List[String],
    ) -> Optional[RenderBackend]:
        """The backend the last `gpu` or `cpu` in `arguments` names, or
        nothing when neither is there: `from_arguments` over a given list, so
        it can be tested without a command line."""
        var backend = Optional[RenderBackend]()
        for argument in arguments:
            if argument == "gpu":
                backend = RenderBackend.GPU
            elif argument == "cpu":
                backend = RenderBackend.CPU
        return backend

    @staticmethod
    def _from_answer(answer: String) -> Optional[RenderBackend]:
        """The backend an answer typed at the prompt names, ignoring case and
        the spaces around it, or nothing when it names neither."""
        var word = String(answer.strip()).lower()
        if word == "gpu":
            return RenderBackend.GPU
        if word == "cpu":
            return RenderBackend.CPU
        return None

    def __eq__(self, other: RenderBackend) -> Bool:
        return self.value == other.value

    def __ne__(self, other: RenderBackend) -> Bool:
        return self.value != other.value

    def write_to[W: Writer](self, mut writer: W):
        if self == RenderBackend.CPU:
            writer.write("RenderBackend.CPU")
        elif self == RenderBackend.GPU:
            writer.write("RenderBackend.GPU")
        else:
            writer.write("RenderBackend(", self.value, ")")


comptime _PROMPT = (
    "Select a rendering backend. Type `gpu` or `cpu` and hit ENTER: "
)


def _ask_for_backend() -> RenderBackend:
    """Ask in the terminal until the answer names a backend, or exit when
    nobody can answer."""
    if external_call["isatty", Int32](Int32(0)) == 0:
        print(
            "This program draws on the CPU or the GPU: add `cpu` or `gpu` to"
            " the command that runs it."
        )
        exit(2)
    while True:
        var answer: String
        try:
            answer = input(_PROMPT)
        except:
            print()  # end the prompt's line when the input ends
            exit(2)
            return RenderBackend.CPU
        var backend = RenderBackend._from_answer(answer)
        if backend:
            var word = "gpu" if backend.value() == RenderBackend.GPU else "cpu"
            print(
                "Next time, add `"
                + word
                + "` to the command to skip this question."
            )
            return backend.value()


struct _ChosenBackend(Movable):
    """The backend `from_arguments` asked for, process-wide, so that a second
    call doesn't ask again."""

    var value: Int
    """The chosen backend's `value`, or -1 before anything is chosen."""

    def __init__(out self):
        self.value = -1


def _new_chosen_backend() -> _ChosenBackend:
    return _ChosenBackend()


comptime _CHOSEN_BACKEND = _Global["create_chosen_backend", _new_chosen_backend]


def _chosen_backend() -> Pointer[_ChosenBackend, MutUntrackedOrigin]:
    try:
        return _CHOSEN_BACKEND.get_or_create_ptr()
    except e:
        # Only fails if the runtime cannot allocate the global at all.
        abort(String("create: the chosen backend is unavailable: ", e))
