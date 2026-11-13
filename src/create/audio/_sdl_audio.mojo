"""Raw SDL3 audio bindings via `std.ffi._DLHandle`.

Internal only — nothing here is re-exported from the package `__init__`.
Mirrors the FFI idiom of `create/_window/_sdl.mojo`: opaque `Int` handles
for everything SDL returns a pointer for, `get_error()` on every failure, and
its own `load_library("libSDL3", 0)` rather than importing the window's, since
`audio` has no business depending on the platform window. A second `dlopen`
of the same shared object returns the same handle, and SDL ref-counts
`SDL_InitSubSystem`/`SDL_QuitSubSystem` per subsystem, so `SDL_INIT_AUDIO`
here coexists safely with the window's `SDL_INIT_VIDEO`.

`SDL_AudioSpec` is `{ SDL_AudioFormat format; int channels; int freq; }` —
three packed 4-byte fields, no padding (verified against
`SDL3/SDL_audio.h`). Everywhere a `SDL_AudioSpec*` is needed, a
`List[Int32](length=3)` stands in for it.

`SDL_LoadWAV`'s `Uint8 **audio_buf` out-param is a pointer-to-pointer, one
level deeper than any existing binding handles. It's read back with
`Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=...)`, the same
raw-address-to-Pointer idiom `_window/gl_window.mojo` uses for
`SDL_GL_GetProcAddress` results.
"""

from std.ffi import _DLHandle
from std.memory import unsafe_memcpy

from create._bytes import cstr as _cstr
from create._library import load_library

comptime SDL_INIT_AUDIO: UInt32 = 0x00000010
comptime SDL_AUDIO_S16: Int32 = 0x8010
comptime SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK: UInt32 = 0xFFFFFFFF
comptime SDL_HINT_OVERRIDE: Int32 = 2


struct SDLAudio:
    """Thin wrapper over the dynamically-loaded SDL3 library's audio API."""

    var lib: _DLHandle

    def __init__(out self) raises:
        self.lib = load_library("libSDL3", 0)

    def get_error(self) raises -> String:
        var ptr = self.lib.call[
            "SDL_GetError", Pointer[UInt8, MutUntrackedOrigin]
        ]()
        return String(unsafe_from_utf8_ptr=ptr)

    def init(self) raises:
        if not self.lib.call["SDL_InitSubSystem", Bool](SDL_INIT_AUDIO):
            raise Error(
                "SDL_InitSubSystem(SDL_INIT_AUDIO) failed: " + self.get_error()
            )

    def start(self) raises -> UInt32:
        """Start the audio subsystem and open a device on the default
        playback device, or raise with the subsystem left stopped."""
        self.init()
        try:
            return self.open_device()
        except e:
            self.quit()
            raise e^

    def start_silent(self) raises -> UInt32:
        """`start` on SDL's dummy driver, which plays to nowhere: for a
        machine with no audio device, or none SDL can open."""
        var hint = String("SDL_AUDIO_DRIVER")
        var driver = String("dummy")
        _ = self.lib.call["SDL_SetHintWithPriority", Bool](
            hint.as_c_string_span().ptr(),
            driver.as_c_string_span().ptr(),
            SDL_HINT_OVERRIDE,
        )
        try:
            var device = self.start()
            _ = self.lib.call["SDL_ResetHint", Bool](
                hint.as_c_string_span().ptr()
            )
            return device
        except e:
            _ = self.lib.call["SDL_ResetHint", Bool](
                hint.as_c_string_span().ptr()
            )
            raise e^

    def quit(self) raises:
        self.lib.call["SDL_QuitSubSystem"](SDL_INIT_AUDIO)

    def load_wav(self, path: String) raises -> Tuple[List[Int16], Int32, Int32]:
        """Load a WAV file, converted to `SDL_AUDIO_S16` whatever its own
        sample format. Returns (samples, channels, sample_rate)."""
        var spec = List[Int32](length=3, fill=0)
        var buf_out = List[Int](length=1, fill=0)
        var len_out = List[Int32](length=1, fill=0)
        var cpath = _cstr(path)

        if not self.lib.call["SDL_LoadWAV", Bool](
            cpath.unsafe_ptr(),
            spec.unsafe_ptr(),
            buf_out.unsafe_ptr(),
            len_out.unsafe_ptr(),
        ):
            raise Error("SDL_LoadWAV failed: " + self.get_error())

        if spec[0] != SDL_AUDIO_S16:
            var target = List[Int32](length=3, fill=0)
            target[0] = SDL_AUDIO_S16
            target[1] = spec[1]
            target[2] = spec[2]
            var converted = List[Int](length=1, fill=0)
            var converted_len = List[Int32](length=1, fill=0)
            var ok = self.lib.call["SDL_ConvertAudioSamples", Bool](
                spec.unsafe_ptr(),
                buf_out[0],
                len_out[0],
                target.unsafe_ptr(),
                converted.unsafe_ptr(),
                converted_len.unsafe_ptr(),
            )
            self.lib.call["SDL_free"](buf_out[0])
            if not ok:
                raise Error(
                    "SDL_ConvertAudioSamples failed: " + self.get_error()
                )
            buf_out[0] = converted[0]
            len_out[0] = converted_len[0]

        var samples = List[Int16](length=Int(len_out[0]) // 2, fill=0)
        unsafe_memcpy(
            dest=samples.unsafe_ptr().unsafe_bitcast[UInt8](),
            src=Pointer[UInt8, MutUntrackedOrigin](
                unsafe_from_address=buf_out[0]
            ),
            count=len(samples) * 2,
        )
        self.lib.call["SDL_free"](buf_out[0])
        return samples^, spec[1], spec[2]

    def open_device(self) raises -> UInt32:
        """Open a logical device on the default playback device, in its own
        preferred format. It starts unpaused; streams bound to it mix."""
        var device = self.lib.call["SDL_OpenAudioDevice", UInt32](
            SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, Int(0)
        )
        if device == 0:
            raise Error("SDL_OpenAudioDevice failed: " + self.get_error())
        return device

    def close_device(self, device: UInt32):
        self.lib.call["SDL_CloseAudioDevice"](device)

    def pause_device(self, device: UInt32) raises:
        if not self.lib.call["SDL_PauseAudioDevice", Bool](device):
            raise Error("SDL_PauseAudioDevice failed: " + self.get_error())

    def resume_device(self, device: UInt32) raises:
        if not self.lib.call["SDL_ResumeAudioDevice", Bool](device):
            raise Error("SDL_ResumeAudioDevice failed: " + self.get_error())

    def create_stream(
        self, format: Int32, channels: Int32, sample_rate: Int32
    ) raises -> Int:
        """A stream taking samples in this format; binding it to a device
        sets its output side to the device's format."""
        var spec = List[Int32](length=3, fill=0)
        spec[0] = format
        spec[1] = channels
        spec[2] = sample_rate
        var stream = self.lib.call["SDL_CreateAudioStream", Int](
            spec.unsafe_ptr(), Int(0)
        )
        if stream == 0:
            raise Error("SDL_CreateAudioStream failed: " + self.get_error())
        return stream

    def bind_stream(self, device: UInt32, stream: Int) raises:
        if not self.lib.call["SDL_BindAudioStream", Bool](device, stream):
            raise Error("SDL_BindAudioStream failed: " + self.get_error())

    def unbind_stream(self, stream: Int):
        self.lib.call["SDL_UnbindAudioStream"](stream)

    def put_data(self, stream: Int, data: Pointer[UInt8, _], len: Int32) raises:
        if not self.lib.call["SDL_PutAudioStreamData", Bool](stream, data, len):
            raise Error("SDL_PutAudioStreamData failed: " + self.get_error())

    def set_gain(self, stream: Int, gain: Float32) raises:
        if not self.lib.call["SDL_SetAudioStreamGain", Bool](stream, gain):
            raise Error("SDL_SetAudioStreamGain failed: " + self.get_error())

    def set_frequency_ratio(self, stream: Int, ratio: Float32) raises:
        if not self.lib.call["SDL_SetAudioStreamFrequencyRatio", Bool](
            stream, ratio
        ):
            raise Error(
                "SDL_SetAudioStreamFrequencyRatio failed: " + self.get_error()
            )

    def frequency_ratio(self, stream: Int) raises -> Float32:
        var ratio = self.lib.call["SDL_GetAudioStreamFrequencyRatio", Float32](
            stream
        )
        if ratio == 0:
            raise Error(
                "SDL_GetAudioStreamFrequencyRatio failed: " + self.get_error()
            )
        return ratio

    def gain(self, stream: Int) raises -> Float32:
        var gain = self.lib.call["SDL_GetAudioStreamGain", Float32](stream)
        if gain < 0:
            raise Error("SDL_GetAudioStreamGain failed: " + self.get_error())
        return gain

    def available(self, stream: Int) raises -> Int32:
        return self.lib.call["SDL_GetAudioStreamAvailable", Int32](stream)

    def queued(self, stream: Int) raises -> Int32:
        """Bytes put into `stream` and not yet consumed, in its input format."""
        var queued = self.lib.call["SDL_GetAudioStreamQueued", Int32](stream)
        if queued < 0:
            raise Error("SDL_GetAudioStreamQueued failed: " + self.get_error())
        return queued

    def flush(self, stream: Int) raises:
        """Mark the end of `stream`'s input, so the samples a resampler holds
        back for what follows are converted and played too."""
        if not self.lib.call["SDL_FlushAudioStream", Bool](stream):
            raise Error("SDL_FlushAudioStream failed: " + self.get_error())

    def drained(self, stream: Int) -> Bool:
        """Whether `stream` has nothing left to give the device: no input
        waiting and no converted output. A failed query counts as drained."""
        return (
            self.lib.call["SDL_GetAudioStreamQueued", Int32](stream) <= 0
            and self.lib.call["SDL_GetAudioStreamAvailable", Int32](stream) <= 0
        )

    def clear_stream(self, stream: Int) raises:
        if not self.lib.call["SDL_ClearAudioStream", Bool](stream):
            raise Error("SDL_ClearAudioStream failed: " + self.get_error())

    def destroy_stream(self, stream: Int) raises:
        self.lib.call["SDL_DestroyAudioStream"](stream)
