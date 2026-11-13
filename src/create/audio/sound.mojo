from std.math import clamp
from std.memory import ArcPointer

from ._sdl_audio import SDLAudio
from ._sndfile import SndFile


struct Sound(Copyable, ImplicitlyCopyable, Movable):
    """Decoded samples, the asset, not a playing voice: 16-bit integers,
    channels interleaved, whatever the file held.

    Decoding happens once, at load; `Audio.play` reads the samples without
    touching the file again. Copying one is cheap, like copying an `Image`:
    the copies share the samples, and so does every voice playing it.
    """

    var _samples: ArcPointer[List[Int16]]
    var _channels: Int
    var _sample_rate: Int

    def __init__(
        out self,
        *,
        var _samples: List[Int16],
        _channels: Int,
        _sample_rate: Int,
    ):
        self._samples = ArcPointer(_samples^)
        self._channels = _channels
        self._sample_rate = _sample_rate

    def channels(self) -> Int:
        """How many channels the samples interleave: 1 mono, 2 stereo."""
        return self._channels

    def sample_rate(self) -> Int:
        """Samples per second, per channel."""
        return self._sample_rate

    def frame_count(self) -> Int:
        """How many frames the sound holds: one sample of every channel."""
        return len(self._samples[]) // self._channels

    def duration(self) -> Float64:
        """How long the sound plays, in seconds."""
        return Float64(self.frame_count()) / Float64(self._sample_rate)

    def sample(self, frame: Int, channel: Int = 0) -> Float64:
        """The sample of `channel` in `frame`, from `-1.0` to `1.0`, as
        `from_samples` takes them. Outside the sound it is `0.0`, silence."""
        if (
            frame < 0
            or frame >= self.frame_count()
            or channel < 0
            or channel >= self._channels
        ):
            return 0.0
        var value = self._samples[][frame * self._channels + channel]
        return max(Float64(value) / 32767.0, -1.0)

    @staticmethod
    def load(path: String) raises -> Sound:
        """Load a WAV, OGG, FLAC, or MP3 file. Dispatches on the file's magic
        bytes, not its extension: `RIFF` (WAV) decodes via the zero-dependency
        `SDL_LoadWAV` path; everything else goes through `libsndfile`. Raises,
        naming `path`, when the file can't be read or holds no samples."""
        var sound: Sound
        try:
            sound = Sound._decode(path)
        except e:
            raise Error(String(e), ": ", path)
        if len(sound._samples[]) == 0:
            raise Error("Sound has no samples: ", path)
        return sound^

    @staticmethod
    def _decode(path: String) raises -> Sound:
        var header: List[UInt8]
        with open(path, "r") as f:
            header = f.read_bytes(4)
        var decoded: Tuple[List[Int16], Int32, Int32]
        if (
            len(header) == 4
            and header[0] == 82
            and header[1] == 73
            and header[2] == 70
            and header[3] == 70
        ):
            decoded = SDLAudio().load_wav(path)
        else:
            decoded = SndFile().load(path)
        return Sound(
            _samples=decoded[0].copy(),
            _channels=Int(decoded[1]),
            _sample_rate=Int(decoded[2]),
        )

    @staticmethod
    def from_samples(
        samples: List[Float64], channels: Int = 1, sample_rate: Int = 44100
    ) raises -> Sound:
        """A sound of `samples`, from `-1.0` to `1.0`, such as a synthesized
        waveform. With more than one channel they interleave, a sample of each
        channel to a frame: left, right, left, right for stereo. A sample
        outside the range is clipped to it.

        Raises unless `channels` and `sample_rate` are positive and `samples`
        is whole frames.
        """
        if channels < 1:
            raise Error(
                "Sound.from_samples: channels must be positive, got ",
                channels,
            )
        if sample_rate < 1:
            raise Error(
                "Sound.from_samples: sample_rate must be positive, got ",
                sample_rate,
            )
        if len(samples) % channels != 0:
            raise Error(
                "Sound.from_samples: ",
                len(samples),
                " samples are not whole frames of ",
                channels,
                " channels",
            )
        var converted = List[Int16](capacity=len(samples))
        for sample in samples:
            converted.append(Int16(round(clamp(sample, -1.0, 1.0) * 32767.0)))
        return Sound(
            _samples=converted^,
            _channels=channels,
            _sample_rate=sample_rate,
        )
