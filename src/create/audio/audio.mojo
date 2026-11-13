from ._sdl_audio import SDLAudio
from .sound import Sound

comptime _GEN_SHIFT = 32
comptime _INDEX_MASK: Int = 0xFFFFFFFF
comptime _LOOP_LEAD = 0.5
"""Seconds of a looping voice kept queued ahead of the device, so a loop
shorter than a frame, or a slow frame, never runs it dry."""


struct _Voice(Movable):
    """One playback slot. `stream == 0` means free.

    `loop_sound` holds a copy of the playing `Sound` -- sharing its samples,
    not copying them -- and is only populated for looping voices, since a
    one-shot voice never needs its PCM again after the initial `put_data`.
    `loop_offset` is the byte of it to queue next.
    """

    var stream: Int
    var generation: Int
    # This voice's own volume, from `volume(id, ...)`; it plays at this times
    # `Audio`'s volume.
    var gain: Float64
    var paused: Bool
    var looping: Bool
    var loop_sound: Optional[Sound]
    var loop_offset: Int

    def __init__(out self):
        self.stream = 0
        # Starts at 1, not 0: id 0 would otherwise be indistinguishable from
        # a zero-initialised `Int` field, so `_encode(0, 0) == 0` must never
        # be issuable. `reset` already bumps a recycled slot's generation, so
        # this only needs to hold for the append path.
        self.generation = 1
        self.gain = 1.0
        self.paused = False
        self.looping = False
        self.loop_sound = None
        self.loop_offset = 0

    def reset(mut self):
        """Return this slot to the free state, bumping its generation so
        stale ids from before the reset fail `_valid`."""
        self.stream = 0
        self.generation += 1
        self.gain = 1.0
        self.paused = False
        self.looping = False
        self.loop_sound = None
        self.loop_offset = 0


struct Voice(Copyable, Equatable, ImplicitlyCopyable, Movable):
    """One playback of a `Sound`, as `audio.play` and `audio.loop` return it:
    the handle `stop`, `pause`, `resume`, `volume`, `is_playing` and
    `is_paused` take.

    A `Sound` can play as several voices at once. A voice that has ended or
    been stopped is stale: every call on it does nothing, even after its slot
    plays another sound. `Voice.NONE` is no voice, for a field before
    anything plays. A handle, like `Sound`, so not printable.
    """

    var _id: Int
    """The slot index and its generation, as `Audio._encode` packs them."""

    comptime NONE = Voice(_id=0)

    def __init__(out self, *, _id: Int):
        self._id = _id

    def __eq__(self, other: Voice) -> Bool:
        return self._id == other._id

    def __ne__(self, other: Voice) -> Bool:
        return self._id != other._id


struct Audio(Movable):
    """Program-owned playback device. Construct once, hold as a Program field,
    call `play` from `update`.

    Call `update` once per frame (e.g. from `Program.update`): it keeps
    looping voices fed, which nothing else does, so skipping it stalls a loop
    once the half second queued ahead drains. A one-shot voice needs no
    `update`: it reads as stale once it has played to its end, and its slot
    is freed by the next `update` or `play`.
    """

    var _sdl: SDLAudio
    # The one logical device every voice's stream is bound to, so SDL mixes
    # them; a voice is a cheap stream, not a device of its own.
    var _device: UInt32
    var _voices: List[_Voice]
    var _volume: Float64

    def __init__(out self) raises:
        self._sdl = SDLAudio()
        self._sdl.init()
        self._device = self._sdl.open_device()
        self._voices = List[_Voice]()
        self._volume = 1.0

    def volume(self) -> Float64:
        """The volume every voice plays at, `1.0` unless set."""
        return self._volume

    def volume(mut self, volume: Float64) raises:
        """Set the volume every voice plays at, `0.0` silent and `1.0` as
        recorded; above `1.0` amplifies, and below `0.0` is silent too.
        Applies at once, to the voices already playing as well as later ones;
        each voice's own `volume(voice, ...)` scales it."""
        self._volume = max(volume, 0.0)
        for i in range(len(self._voices)):
            if self._voices[i].stream != 0:
                self._apply_gain(i)

    def _apply_gain(mut self, index: Int) raises:
        # SDL takes its gain as a Float32; the API stays in Float64 like
        # every other fraction, and narrows here, at the boundary.
        self._sdl.set_gain(
            self._voices[index].stream,
            Float32(self._volume * self._voices[index].gain),
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
            and index < len(self._voices)
            and self._voices[index].generation == generation
            and self._voices[index].stream != 0
            and not self._finished(index)
        )

    def _finished(self, index: Int) -> Bool:
        """Whether the voice in a live slot has played to its end: a one-shot
        that is not paused, with nothing left to play. Its slot is freed by
        the next `update` or `play`, but it is stale from now on."""
        ref voice = self._voices[index]
        return (
            not voice.looping
            and not voice.paused
            and self._sdl.drained(voice.stream)
        )

    def _reap(mut self) raises:
        """Free the slot of every voice that has played to its end."""
        for i in range(len(self._voices)):
            if self._voices[i].stream != 0 and self._finished(i):
                self._free_slot(i)

    def play(mut self, sound: Sound, volume: Float64 = 1.0) raises -> Voice:
        """Play `sound` once, as a new `Voice` at its own `volume`; it is
        stale once the sound ends."""
        return self._start(sound, volume, loop=False)

    def loop(mut self, sound: Sound, volume: Float64 = 1.0) raises -> Voice:
        """Play `sound` over and over until stopped, as a new `Voice` at its
        own `volume`, as `Animator.loop` and `Tween.loop` repeat. The voice
        is fed by `update`, from a copy of `sound` that shares its samples.
        """
        return self._start(sound, volume, loop=True)

    def _start(
        mut self, sound: Sound, volume: Float64, loop: Bool
    ) raises -> Voice:
        # Without this, a program that skips `update` would never free a
        # slot, and the list would grow by one voice per `play`.
        self._reap()
        var index = -1
        for i in range(len(self._voices)):
            if self._voices[i].stream == 0:
                index = i
                break
        if index == -1:
            self._voices.append(_Voice())
            index = len(self._voices) - 1

        var stream = self._sdl.create_stream(
            sound._format, Int32(sound._channels), Int32(sound._sample_rate)
        )
        self._voices[index].stream = stream
        self._voices[index].gain = max(volume, 0.0)
        self._voices[index].paused = False
        self._voices[index].looping = loop
        # The gain is set before binding, so not one sample plays louder.
        self._apply_gain(index)
        # Bound before any data: a stream takes none until binding gives its
        # output side the device's format.
        self._sdl.bind_stream(self._device, stream)

        if loop:
            self._voices[index].loop_sound = sound
            self._voices[index].loop_offset = 0
            self._feed(index)
        else:
            self._sdl.put_data(
                stream, sound._pcm[].unsafe_ptr(), Int32(len(sound._pcm[]))
            )
            self._sdl.flush(stream)
        return Voice(_id=Self._encode(index, self._voices[index].generation))

    def _feed(mut self, index: Int) raises:
        """Queue a looping voice's sound, from where it left off and round
        again, until `_LOOP_LEAD` seconds are waiting."""
        var stream = self._voices[index].stream
        var sound = self._voices[index].loop_sound.value()
        var total = len(sound._pcm[])
        if total == 0:
            return
        var frame = sound._frame_bytes()
        var lead = Int(_LOOP_LEAD * Float64(sound._sample_rate)) * frame
        var queued = Int(self._sdl.queued(stream))
        var offset = self._voices[index].loop_offset
        while queued < lead:
            var count = min(total - offset, lead - queued)
            self._sdl.put_data(
                stream,
                sound._pcm[].unsafe_ptr().unsafe_offset(offset),
                Int32(count),
            )
            queued += count
            offset = (offset + count) % total
        self._voices[index].loop_offset = offset

    def _free_slot(mut self, index: Int) raises:
        self._sdl.destroy_stream(self._voices[index].stream)
        self._voices[index].reset()

    def stop(mut self, voice: Voice) raises:
        """Stop and release `voice`. No-op if it is already stale."""
        var id = voice._id
        if not self._valid(id):
            return
        self._free_slot(Self._decode(id)[0])

    def stop_all(mut self) raises:
        """Stop and release every voice, playing or paused."""
        for i in range(len(self._voices)):
            if self._voices[i].stream != 0:
                self._free_slot(i)

    def pause_all(mut self) raises:
        """Pause every playing voice, as for a pause screen. Voices played
        afterwards play as usual, so the screen can have sounds of its own."""
        for i in range(len(self._voices)):
            if (
                self._voices[i].stream != 0
                and not self._voices[i].paused
                and not self._finished(i)
            ):
                self._sdl.unbind_stream(self._voices[i].stream)
                self._voices[i].paused = True

    def resume_all(mut self) raises:
        """Resume every paused voice, whether `pause_all` or `pause` held it."""
        for i in range(len(self._voices)):
            if self._voices[i].stream != 0 and self._voices[i].paused:
                self._sdl.bind_stream(self._device, self._voices[i].stream)
                self._voices[i].paused = False

    def pause(mut self, voice: Voice) raises:
        """Hold `voice` where it is; `resume` continues it."""
        var id = voice._id
        if not self._valid(id):
            return
        var index = Self._decode(id)[0]
        if self._voices[index].paused:
            return
        # Unbound, the stream keeps its queued samples but nothing pulls them.
        self._sdl.unbind_stream(self._voices[index].stream)
        self._voices[index].paused = True

    def volume(self, voice: Voice) -> Float64:
        """`voice`'s own volume, `1.0` unless set; `0.0` once it is stale."""
        if not self._valid(voice._id):
            return 0.0
        return self._voices[Self._decode(voice._id)[0]].gain

    def volume(mut self, voice: Voice, volume: Float64) raises:
        """Set `voice`'s own volume, which `volume()` scales: a voice at
        `0.5` under a volume of `0.5` plays at a quarter. Below `0.0` is
        silent, as for `volume()`. No-op if stale."""
        var id = voice._id
        if not self._valid(id):
            return
        var index = Self._decode(id)[0]
        self._voices[index].gain = max(volume, 0.0)
        self._apply_gain(index)

    def resume(mut self, voice: Voice) raises:
        """Continue a paused `voice` from where it was held."""
        var id = voice._id
        if not self._valid(id):
            return
        var index = Self._decode(id)[0]
        if not self._voices[index].paused:
            return
        self._sdl.bind_stream(self._device, self._voices[index].stream)
        self._voices[index].paused = False

    def is_playing(self, voice: Voice) -> Bool:
        """Whether `voice` is sounding: false once paused or stale."""
        var id = voice._id
        if not self._valid(id):
            return False
        return not self._voices[Self._decode(id)[0]].paused

    def is_paused(self, voice: Voice) -> Bool:
        """Whether `voice` is held by `pause`, waiting for `resume`. A voice
        neither playing nor paused is stale: it has ended or been stopped."""
        var id = voice._id
        if not self._valid(id):
            return False
        return self._voices[Self._decode(id)[0]].paused

    def update(mut self) raises:
        """Free finished one-shot voices and top up looping ones.

        A looping voice is kept `_LOOP_LEAD` seconds ahead of the device,
        however short its sound, so the device never drains between frames:
        a refill that lands after it has gone silent clicks at the seam.
        """
        self._reap()
        for i in range(len(self._voices)):
            if self._voices[i].stream != 0 and self._voices[i].looping:
                self._feed(i)

    def __deinit__(deinit self):
        try:
            self.stop_all()
            self._sdl.close_device(self._device)
            self._sdl.quit()
        except:
            pass
