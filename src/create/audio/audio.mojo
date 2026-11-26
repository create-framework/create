from std.math import clamp
from std.memory import OwnedPointer

from ._sdl_audio import (
    SDLAudio,
    SDL_AUDIO_S16,
    AudioStreamCallback,
    PutAudioStreamData,
)
from .sound import Sound
from .playback import Playback

comptime _GEN_SHIFT = 32
comptime _INDEX_MASK: Int = 0xFFFFFFFF
comptime _MIN_SPEED = 0.01
comptime _MAX_SPEED = 100.0
"""The speeds SDL can resample at."""


struct _LoopFeed(Movable):
    """What a looping playback's stream callback reads and writes, on SDL's audio
    thread. It lives on the heap, so its address holds while `_Slot`s move in
    their list, and only the callback touches it until the stream is
    destroyed, so it needs no lock but the stream's own."""

    var sound: Sound
    """The sound looping: a copy, sharing its samples, that keeps them alive
    while the callback reads them."""
    var put: PutAudioStreamData
    var offset: Int
    """The byte of the sound's samples to queue next."""
    var fed: Int
    """Bytes queued so far, all told."""

    def __init__(out self, sound: Sound, put: PutAudioStreamData):
        self.sound = sound
        self.put = put
        self.offset = 0
        self.fed = 0


def _feed_loop(
    userdata: Int, stream: Int, additional: Int32, total: Int32
) abi("C"):
    """The stream callback of a looping playback: queue what the device asked
    for, `additional` bytes in the sound's format, from where the last call
    left off and round again. Runs on SDL's audio thread, as often as the
    device needs, so a loop is fed whatever the program's frame rate, or with
    no frames at all. It must not raise or allocate."""
    var feed = Pointer[_LoopFeed, MutUntrackedOrigin](
        unsafe_from_address=userdata
    )
    var samples = Int(feed[].sound._samples[].unsafe_ptr())
    var length = len(feed[].sound._samples[]) * 2
    if length == 0:
        return
    # Whole frames only, so every put starts on one.
    var frame = feed[].sound._channels * 2
    var needed = (Int(additional) + frame - 1) // frame * frame
    while needed > 0:
        var count = min(length - feed[].offset, needed)
        _ = feed[].put(stream, samples + feed[].offset, Int32(count))
        feed[].offset = (feed[].offset + count) % length
        feed[].fed += count
        needed -= count


struct _Slot(Movable):
    """One playback slot. `stream == 0` means free.

    A one-shot playback's samples are all queued when it starts. A looping
    playback's are queued as the device asks, by `_feed_loop` from `loop_feed`.
    """

    var stream: Int
    var generation: Int
    # This playback's own volume, from `volume(id, ...)`; it plays at this times
    # `Audio`'s volume.
    var gain: Float64
    # This playback's speed, from `speed(id, ...)`.
    var speed: Float64
    var paused: Bool
    var looping: Bool
    var loop_feed: Optional[OwnedPointer[_LoopFeed]]

    def __init__(out self):
        self.stream = 0
        # Starts at 1, not 0: id 0 would otherwise be indistinguishable from
        # a zero-initialised `Int` field, so `_encode(0, 0) == 0` must never
        # be issuable. `reset` already bumps a recycled slot's generation, so
        # this only needs to hold for the append path.
        self.generation = 1
        self.gain = 1.0
        self.speed = 1.0
        self.paused = False
        self.looping = False
        self.loop_feed = None

    def reset(mut self):
        """Return this slot to the free state, bumping its generation so
        stale ids from before the reset fail `_valid`."""
        self.stream = 0
        self.generation += 1
        self.gain = 1.0
        self.speed = 1.0
        self.paused = False
        self.looping = False
        self.loop_feed = None


struct Audio(Movable):
    """Program-owned playback device. Construct once, hold as a Program field,
    call `play` from `update`. Where no audio device can be opened, it plays
    silently rather than raising.

    It needs nothing each frame: a looping playback is fed on SDL's audio
    thread, as the device asks, and a one-shot playback reads as stale once it
    has played to its end, its slot freed by the next `play`.
    """

    var _sdl: SDLAudio
    # The one logical device every playback's stream is bound to, so SDL mixes
    # them; a playback is a cheap stream, not a device of its own.
    var _device: UInt32
    var _slots: List[_Slot]
    var _volume: Float64

    def __init__(out self) raises:
        self._sdl = SDLAudio()
        # A program with sound must still run where there is nothing to play
        # it on: a server, CI, a headless recording. There it plays to SDL's
        # dummy driver, silently, and every call works as usual.
        var device: UInt32
        try:
            device = self._sdl.start()
        except:
            device = self._sdl.start_silent()
        self._device = device
        self._slots = List[_Slot]()
        self._volume = 1.0

    def volume(self) -> Float64:
        """The volume every playback plays at, `1.0` unless set."""
        return self._volume

    def volume(mut self, volume: Float64) raises:
        """Set the volume every playback plays at, `0.0` silent and `1.0` as
        recorded; above `1.0` amplifies, and below `0.0` is silent too.
        Applies at once, to the playbacks already playing as well as later ones;
        each playback's own `volume(playback, ...)` scales it."""
        self._volume = max(volume, 0.0)
        for i in range(len(self._slots)):
            if self._slots[i].stream != 0:
                self._apply_gain(i)

    def _apply_gain(mut self, index: Int) raises:
        # SDL takes its gain as a Float32; the API stays in Float64 like
        # every other fraction, and narrows here, at the boundary.
        self._sdl.set_gain(
            self._slots[index].stream,
            Float32(self._volume * self._slots[index].gain),
        )

    @staticmethod
    def _encode(index: Int, generation: Int) -> Int:
        return (generation << _GEN_SHIFT) | index

    @staticmethod
    def _decode(id: Int) -> Tuple[Int, Int]:
        return id & _INDEX_MASK, id >> _GEN_SHIFT

    def _valid(self, id: Int) -> Bool:
        var parts = Self._decode(id)
        var index = parts[0]
        var generation = parts[1]
        return (
            index >= 0
            and index < len(self._slots)
            and self._slots[index].generation == generation
            and self._slots[index].stream != 0
            and not self._finished(index)
        )

    def _finished(self, index: Int) -> Bool:
        """Whether the playback in a live slot has played to its end: a one-shot
        that is not paused, with nothing left to play. Its slot is freed by
        the next `play`, but it is stale from now on."""
        ref playback = self._slots[index]
        return (
            not playback.looping
            and not playback.paused
            and self._sdl.drained(playback.stream)
        )

    def _reap(mut self) raises:
        """Free the slot of every playback that has played to its end."""
        for i in range(len(self._slots)):
            if self._slots[i].stream != 0 and self._finished(i):
                self._free_slot(i)

    def play(
        mut self, sound: Sound, volume: Float64 = 1.0, speed: Float64 = 1.0
    ) raises -> Playback:
        """Play `sound` once, as a new `Playback` at its own `volume` and
        `speed`; it is stale once the sound ends."""
        return self._start(sound, volume, speed, loop=False)

    def loop(
        mut self, sound: Sound, volume: Float64 = 1.0, speed: Float64 = 1.0
    ) raises -> Playback:
        """Play `sound` over and over until stopped, as a new `Playback` at its
        own `volume` and `speed`, as `Animator.loop` and `Tween.loop` repeat.
        The playback is fed as the device asks, from a copy of `sound` that
        shares its samples.
        """
        return self._start(sound, volume, speed, loop=True)

    def _start(
        mut self, sound: Sound, volume: Float64, speed: Float64, loop: Bool
    ) raises -> Playback:
        # Frees what has ended, so the list grows only to the most playbacks
        # sounding at once.
        self._reap()
        var index = -1
        for i in range(len(self._slots)):
            if self._slots[i].stream == 0:
                index = i
                break
        if index == -1:
            self._slots.append(_Slot())
            index = len(self._slots) - 1

        var stream = self._sdl.create_stream(
            SDL_AUDIO_S16, Int32(sound._channels), Int32(sound._sample_rate)
        )
        self._slots[index].stream = stream
        self._slots[index].gain = max(volume, 0.0)
        self._slots[index].speed = clamp(speed, _MIN_SPEED, _MAX_SPEED)
        self._slots[index].paused = False
        self._slots[index].looping = loop
        # Gain and speed are set before binding, so not one sample plays
        # otherwise.
        self._apply_gain(index)
        self._sdl.set_frequency_ratio(stream, Float32(self._slots[index].speed))

        if loop:
            # The callback is set before binding, so the device's first
            # request finds it.
            var feed = OwnedPointer(_LoopFeed(sound, self._sdl.put_function()))
            var callback: AudioStreamCallback = _feed_loop
            self._sdl.set_get_callback(
                stream, callback, Int(Pointer(to=feed[]))
            )
            self._slots[index].loop_feed = feed^
            self._sdl.bind_stream(self._device, stream)
        else:
            # Bound before any data: a stream takes none until binding gives
            # its output side the device's format.
            self._sdl.bind_stream(self._device, stream)
            self._sdl.put_data(
                stream,
                sound._samples[].unsafe_ptr().unsafe_bitcast[UInt8](),
                Int32(len(sound._samples[]) * 2),
            )
            self._sdl.flush(stream)
        return Playback(_id=Self._encode(index, self._slots[index].generation))

    def _free_slot(mut self, index: Int) raises:
        # Destroyed first: once SDL_DestroyAudioStream returns, the callback
        # can't be running, so `reset` may free its feed.
        self._sdl.destroy_stream(self._slots[index].stream)
        self._slots[index].reset()

    def stop(mut self, playback: Playback) raises:
        """Stop and release `playback`. No-op if it is already stale."""
        var id = playback._id
        if not self._valid(id):
            return
        self._free_slot(Self._decode(id)[0])

    def stop_all(mut self) raises:
        """Stop and release every playback, playing or paused."""
        for i in range(len(self._slots)):
            if self._slots[i].stream != 0:
                self._free_slot(i)

    def pause_all(mut self) raises:
        """Pause every playing playback, as for a pause screen. Playbacks played
        afterwards play as usual, so the screen can have sounds of its own."""
        for i in range(len(self._slots)):
            if (
                self._slots[i].stream != 0
                and not self._slots[i].paused
                and not self._finished(i)
            ):
                self._sdl.unbind_stream(self._slots[i].stream)
                self._slots[i].paused = True

    def resume_all(mut self) raises:
        """Resume every paused playback, whether `pause_all` or `pause` held it.
        """
        for i in range(len(self._slots)):
            if self._slots[i].stream != 0 and self._slots[i].paused:
                self._sdl.bind_stream(self._device, self._slots[i].stream)
                self._slots[i].paused = False

    def pause(mut self, playback: Playback) raises:
        """Hold `playback` where it is; `resume` continues it."""
        var id = playback._id
        if not self._valid(id):
            return
        var index = Self._decode(id)[0]
        if self._slots[index].paused:
            return
        # Unbound, the stream keeps its queued samples but nothing pulls them.
        self._sdl.unbind_stream(self._slots[index].stream)
        self._slots[index].paused = True

    def volume(self, playback: Playback) -> Float64:
        """`playback`'s own volume, `1.0` unless set; `0.0` once it is stale."""
        if not self._valid(playback._id):
            return 0.0
        return self._slots[Self._decode(playback._id)[0]].gain

    def volume(mut self, playback: Playback, volume: Float64) raises:
        """Set `playback`'s own volume, which `volume()` scales: a playback at
        `0.5` under a volume of `0.5` plays at a quarter. Below `0.0` is
        silent, as for `volume()`. No-op if stale."""
        var id = playback._id
        if not self._valid(id):
            return
        var index = Self._decode(id)[0]
        self._slots[index].gain = max(volume, 0.0)
        self._apply_gain(index)

    def speed(self, playback: Playback) -> Float64:
        """`playback`'s speed, `1.0` unless set; `0.0` once it is
        stale."""
        if not self._valid(playback._id):
            return 0.0
        return self._slots[Self._decode(playback._id)[0]].speed

    def speed(mut self, playback: Playback, speed: Float64) raises:
        """Set `playback`'s speed: `2.0` plays it twice as fast and an
        octave higher, `0.5` half as fast and an octave lower, as a record
        sped up or slowed down. Clamped to `0.01` to `100.0`. No-op if stale.
        """
        var id = playback._id
        if not self._valid(id):
            return
        var index = Self._decode(id)[0]
        self._slots[index].speed = clamp(speed, _MIN_SPEED, _MAX_SPEED)
        self._sdl.set_frequency_ratio(
            self._slots[index].stream, Float32(self._slots[index].speed)
        )

    def resume(mut self, playback: Playback) raises:
        """Continue a paused `playback` from where it was held."""
        var id = playback._id
        if not self._valid(id):
            return
        var index = Self._decode(id)[0]
        if not self._slots[index].paused:
            return
        self._sdl.bind_stream(self._device, self._slots[index].stream)
        self._slots[index].paused = False

    def is_playing(self, playback: Playback) -> Bool:
        """Whether `playback` is sounding: false once paused or stale."""
        var id = playback._id
        if not self._valid(id):
            return False
        return not self._slots[Self._decode(id)[0]].paused

    def is_paused(self, playback: Playback) -> Bool:
        """Whether `playback` is held by `pause`, waiting for `resume`. A playback
        neither playing nor paused is stale: it has ended or been stopped."""
        var id = playback._id
        if not self._valid(id):
            return False
        return self._slots[Self._decode(id)[0]].paused

    def __deinit__(deinit self):
        try:
            self.stop_all()
            self._sdl.close_device(self._device)
            self._sdl.quit()
        except:
            pass
