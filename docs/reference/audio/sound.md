# Sound

```mojo
struct Sound
```

Decoded samples, the asset, not a playing playback: 16-bit integers, channels interleaved, whatever the file held.

Decoding happens once, at load; `Audio.play` reads the samples without
touching the file again. Copying one is cheap, like copying an `Image`:
the copies share the samples, and so does every playback playing it.

Implements `Copyable`, `Deinitable`, `ImplicitlyCopyable`, `Movable`.

## Constructors

### `load`

```mojo
@staticmethod
def load(path: String) raises -> Self
```

Load a WAV, OGG, FLAC, or MP3 file. Dispatches on the file's magic bytes, not its extension: `RIFF` (WAV) decodes via the zero-dependency `SDL_LoadWAV` path; everything else goes through `libsndfile`. Raises, naming `path`, when the file can't be read or holds no samples.

A relative `path` is resolved against the directory of the calling
source file, not the working directory, as `Image.load`'s is.

### `from_samples`

```mojo
@staticmethod
def from_samples(
    samples: List[Float64],
    channels: Int = Int(1),
    sample_rate: Int = Int(44100),
) raises -> Self
```

A sound of `samples`, from `-1.0` to `1.0`, such as a synthesized waveform. With more than one channel they interleave, a sample of each channel to a frame: left, right, left, right for stereo. A sample outside the range is clipped to it.

Raises unless `channels` and `sample_rate` are positive and `samples`
is whole frames.

## Methods

### `channels`

```mojo
def channels(self) -> Int
```

How many channels the samples interleave: 1 mono, 2 stereo.

### `sample_rate`

```mojo
def sample_rate(self) -> Int
```

Samples per second, per channel.

### `frame_count`

```mojo
def frame_count(self) -> Int
```

How many frames the sound holds: one sample of every channel.

### `duration`

```mojo
def duration(self) -> Float64
```

How long the sound plays, in seconds.

### `sample`

```mojo
def sample(self, frame: Int, channel: Int = Int(0)) -> Float64
```

The sample of `channel` in `frame`, from `-1.0` to `1.0`, as `from_samples` takes them. Outside the sound it is `0.0`, silence.
