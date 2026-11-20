from std.sys import argv


# A type of its own, like `WindowMode`: it keeps a backend constant from
# binding to a neighbouring `Int` parameter by position (`run_headless(w, h,
# RenderBackend.GPU)` once meant `frames=1` on the CPU, and compiled). The
# constructor is not `@implicit` for the same reason.
struct RenderBackend(
    Copyable, Equatable, ImplicitlyCopyable, Movable, Writable
):
    """Which renderer draws a run's frames: `run`'s and `run_headless`'s
    `backend` parameter.

    Fixed for the run. Both draw the same frame, apart from tiny differences
    along antialiased edges. Compare backends with `==`.
    """

    var value: Int

    comptime CPU = RenderBackend(0)
    """Create's own rasteriser, on the CPU. The default."""
    # replays onto a Surface through _raster.mojo
    comptime GPU = RenderBackend(1)
    """OpenGL 3.3."""
    # replays through GLRenderer — see _gl_backend.mojo

    def __init__(out self, value: Int):
        self.value = value

    @staticmethod
    def from_arguments() -> RenderBackend:
        """The backend named on the command line: `GPU` when the program was
        run with a `gpu` argument, `CPU` otherwise or with `cpu`, the last
        named winning. So one build runs on either, `./sketch gpu` or
        `pixi run example shadows gpu`. The backend is a parameter of `run`,
        so call `run` once for each, which compiles both:
        `if RenderBackend.from_arguments() == RenderBackend.GPU:
        run[P, backend=RenderBackend.GPU](...)`, `else: run[P](...)`. Other
        arguments are left for the program."""
        var arguments = List[String]()
        var raw = argv()
        for i in range(1, len(raw)):
            arguments.append(String(raw[i]))
        return RenderBackend._from_argument_list(arguments)

    @staticmethod
    def _from_argument_list(arguments: List[String]) -> RenderBackend:
        """`from_arguments` over a given list, so it can be tested without a
        command line."""
        var backend = RenderBackend.CPU
        for argument in arguments:
            if argument == "gpu":
                backend = RenderBackend.GPU
            elif argument == "cpu":
                backend = RenderBackend.CPU
        return backend

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
