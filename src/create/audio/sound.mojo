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
    def from_pcm(
        data: List[Int16], channels: Int = 1, sample_rate: Int = 44100
    ) -> Sound:
        """Build a Sound from raw 16-bit samples, e.g. a synthesized waveform.
        """
        return Sound(
            _samples=data.copy(), _channels=channels, _sample_rate=sample_rate
        )
