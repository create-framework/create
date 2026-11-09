"""`_SDLWindow` — what `Window` and `GLWindow` share: the native window, its
event pump, the clock and the gamepads. Each owns one and adds only its
surface — a pixel buffer, or a GL context."""

from ._sdl import (
    SDL,
    SDL_EVENT_SIZE,
    SDL_SYSTEM_CURSOR_COUNT,
    SDL_SYSTEM_CURSOR_CROSSHAIR,
    SDL_SYSTEM_CURSOR_DEFAULT,
    SDL_SYSTEM_CURSOR_EW_RESIZE,
    SDL_SYSTEM_CURSOR_MOVE,
    SDL_SYSTEM_CURSOR_NESW_RESIZE,
    SDL_SYSTEM_CURSOR_NOT_ALLOWED,
    SDL_SYSTEM_CURSOR_NS_RESIZE,
    SDL_SYSTEM_CURSOR_NWSE_RESIZE,
    SDL_SYSTEM_CURSOR_POINTER,
    SDL_SYSTEM_CURSOR_PROGRESS,
    SDL_SYSTEM_CURSOR_TEXT,
    SDL_SYSTEM_CURSOR_WAIT,
    SDL_EVENT_QUIT,
    SDL_EVENT_WINDOW_RESIZED,
    event_type,
    window_data1,
    window_data2,
)
from .event import (
    Event,
    Quit,
    Resized,
    translate_event,
    translate_gamepad_device,
)


# The system cursors `set_system_cursor` takes, named here so that no SDL
# name leaves the package. The resize ones are named by the line they run
# along, read left to right with y up: rising is `/`, falling `\`.
comptime SYSTEM_CURSOR_ARROW = SDL_SYSTEM_CURSOR_DEFAULT
comptime SYSTEM_CURSOR_CROSSHAIR = SDL_SYSTEM_CURSOR_CROSSHAIR
comptime SYSTEM_CURSOR_HAND = SDL_SYSTEM_CURSOR_POINTER
comptime SYSTEM_CURSOR_TEXT = SDL_SYSTEM_CURSOR_TEXT
comptime SYSTEM_CURSOR_WAIT = SDL_SYSTEM_CURSOR_WAIT
comptime SYSTEM_CURSOR_PROGRESS = SDL_SYSTEM_CURSOR_PROGRESS
comptime SYSTEM_CURSOR_MOVE = SDL_SYSTEM_CURSOR_MOVE
comptime SYSTEM_CURSOR_NOT_ALLOWED = SDL_SYSTEM_CURSOR_NOT_ALLOWED
comptime SYSTEM_CURSOR_RESIZE_HORIZONTAL = SDL_SYSTEM_CURSOR_EW_RESIZE
comptime SYSTEM_CURSOR_RESIZE_VERTICAL = SDL_SYSTEM_CURSOR_NS_RESIZE
comptime SYSTEM_CURSOR_RESIZE_DIAGONAL_RISING = SDL_SYSTEM_CURSOR_NESW_RESIZE
comptime SYSTEM_CURSOR_RESIZE_DIAGONAL_FALLING = SDL_SYSTEM_CURSOR_NWSE_RESIZE


trait NativeWindow:
    """What a run loop needs of a window, whatever it presents through."""

    def is_open(self) -> Bool:
        ...

    def close(mut self):
        ...

    def ticks(self) raises -> Int:
        """Milliseconds since SDL library init."""
        ...

    def rumble_gamepad(
        self,
        id: Int,
        low_frequency: Float64,
        high_frequency: Float64,
        seconds: Float64,
    ) raises:
        """Runs gamepad `id`'s motors (strengths 0..1) for `seconds`; see
        `SDL.rumble_gamepad`."""
        ...

    def events(mut self) raises -> List[Event]:
        """Drains all pending SDL events for this frame as translated
        `Event`s. A quit event also flips the window to closed."""
        ...

    def set_title(mut self, title: String) raises:
        ...

    def set_resizable(mut self, enabled: Bool) raises:
        """Whether the user can drag the window's edges to resize it."""
        ...

    def set_system_cursor(mut self, id: Int) raises:
        """Show the `SYSTEM_CURSOR_*` `id` over the window. A request:
        a video driver without cursors leaves the cursor as it is."""
        ...

    def show_cursor(mut self, visible: Bool) raises:
        """Show or hide the mouse cursor over the window; a request, like
        `set_system_cursor`."""
        ...

    def set_mode(
        mut self, fullscreen: Bool, borderless: Bool, maximized: Bool
    ) raises:
        """Switch how the window presents itself — at most one flag set,
        none for an ordinary decorated window. The size follows
        asynchronously on some compositors, so read it each frame rather
        than caching what this leaves behind."""
        ...


struct _SDLWindow:
    var sdl: SDL
    var handle: Int
    var open: Bool
    var width: Int
    """Logical size: what resize events report, not the backing pixels."""
    var height: Int
    var cursors: List[Int]
    """Each system cursor's handle by `SYSTEM_CURSOR_*` id, created on
    first use and kept: SDL holds no reference to the one it shows. 0 where
    not yet created, or where the driver had none."""

    def __init__(
        out self,
        title: String,
        width: Int,
        height: Int,
        resizable: Bool,
        fullscreen: Bool,
        borderless: Bool,
        maximized: Bool,
        opengl: Bool = False,
        gl_attributes: List[Tuple[Int32, Int32]] = [],
        offscreen: Bool = False,
    ) raises:
        """`gl_attributes` are `SDL_GL_*` pairs, set before the window is
        created because SDL reads them then. `offscreen` as for
        `SDL.init_subsystems`; its window is created hidden, which the
        offscreen driver never shows anyway and which is what keeps it off
        the screen on macOS."""
        self.sdl = SDL()
        self.cursors = List[Int](length=SDL_SYSTEM_CURSOR_COUNT, fill=0)
        self.sdl.init_subsystems(offscreen)
        var window_width = width
        var window_height = height
        try:
            # Where SDL sizes windows in pixels (X11, Windows), the requested
            # size is scaled by the display's content scale so it covers as
            # much of the screen as on Wayland and macOS, where SDL sizes in
            # logical units and the content scale is 1. Taken from the primary
            # display, since the window has none before it exists.
            if not offscreen:
                var scale = self.sdl.primary_display_content_scale()
                window_width = Int(round(Float64(width) * scale))
                window_height = Int(round(Float64(height) * scale))
            for attribute in gl_attributes:
                self.sdl.gl_set_attribute(attribute[0], attribute[1])
            self.handle = self.sdl.create_window(
                title,
                Int32(window_width),
                Int32(window_height),
                resizable,
                opengl=opengl,
                fullscreen=fullscreen,
                borderless=borderless,
                maximized=maximized,
                hidden=offscreen,
            )
        except e:
            self.sdl.quit_subsystems()
            raise e
        try:
            # Fullscreen and maximized make SDL ignore the requested size, so
            # the real one has to be queried before anything is sized from it.
            self.width = window_width
            self.height = window_height
            if fullscreen or maximized:
                self.width, self.height = self.sdl.get_window_size(self.handle)
            self.sdl.start_text_input(self.handle)
        except e:
            self.sdl.destroy_window(self.handle)
            self.sdl.quit_subsystems()
            raise e
        self.open = True

    def __deinit__(deinit self):
        for cursor in self.cursors:
            if cursor != 0:
                self.sdl.destroy_cursor(cursor)
        try:
            self.sdl.destroy_window(self.handle)
            self.sdl.quit_subsystems()
        except:
            pass

    def set_title(mut self, title: String) raises:
        self.sdl.set_window_title(self.handle, title)

    def set_resizable(mut self, enabled: Bool) raises:
        _ = self.sdl.set_window_resizable(self.handle, enabled)

    def set_system_cursor(mut self, id: Int) raises:
        """SDL's cursor is the process's, not this window's: with one window
        a run, the same thing."""
        if self.cursors[id] == 0:
            self.cursors[id] = self.sdl.create_system_cursor(id)
        if self.cursors[id] != 0:
            _ = self.sdl.set_cursor(self.cursors[id])

    def show_cursor(mut self, visible: Bool) raises:
        if visible:
            _ = self.sdl.show_cursor()
        else:
            _ = self.sdl.hide_cursor()

    def set_mode(
        mut self, fullscreen: Bool, borderless: Bool, maximized: Bool
    ) raises:
        """Leave whatever mode the window is in — windowed, bordered and
        restored — then enter the one asked for, so any mode can follow any
        other.

        Restoring and maximizing are requests a window manager may ignore,
        so a refusal leaves the window as it is rather than raising; the
        loop reads the size it ends up with each frame either way."""
        self.sdl.set_window_fullscreen(self.handle, False)
        _ = self.sdl.set_window_bordered(self.handle, True)
        _ = self.sdl.restore_window(self.handle)
        if fullscreen:
            self.sdl.set_window_fullscreen(self.handle, True)
        elif borderless:
            _ = self.sdl.set_window_bordered(self.handle, False)
        elif maximized:
            _ = self.sdl.maximize_window(self.handle)

    def rumble_gamepad(
        self,
        id: Int,
        low_frequency: Float64,
        high_frequency: Float64,
        seconds: Float64,
    ) raises:
        self.sdl.rumble_gamepad(
            UInt32(id), low_frequency, high_frequency, seconds
        )

    def events(mut self) raises -> List[Event]:
        """Drains this frame's events; quit closes, resize updates
        `width`/`height`. The owner reacts to the new size afterwards."""
        var events: List[Event] = []
        var buf = Array[UInt8, SDL_EVENT_SIZE](fill=0)
        var ptr = buf.unsafe_ptr()
        while self.sdl.poll_event(ptr):
            var kind = event_type(ptr)
            if kind == SDL_EVENT_QUIT:
                self.open = False
                events.append(Event(Quit()))
            elif kind == SDL_EVENT_WINDOW_RESIZED:
                self.width = Int(window_data1(ptr))
                self.height = Int(window_data2(ptr))
                events.append(Event(Resized(self.width, self.height)))
            else:
                var translated = translate_gamepad_device(self.sdl, kind, ptr)
                if not translated:
                    translated = translate_event(kind, ptr)
                if translated:
                    events.append(translated.value())
        return events^
