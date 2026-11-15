# Audio

Playing sounds: loading or synthesizing a `Sound`, playing it through an `Audio` as voices, and
controlling each voice. A program that builds a short beep and plays it on Space:

```mojo
from create import *


@fieldwise_init
struct Beep(Program):
    var audio: Audio
    var beep: Sound

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Beep:
        var samples = List[Float64](capacity=22050)  # half a second
        for i in range(22050):
            var fade = 1.0 - Float64(i) / 22050.0
            var wave = sin(TAU * 440.0 * Float64(i) / 44100.0)  # 440 Hz
            samples.append(0.5 * fade * wave)
        return Beep(Audio(), Sound.from_samples(samples))

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        canvas.background(Color.WHITE)
        canvas.text("Press Space", (0, 0))
        if context.keyboard.pressed(Key.SPACE):
            _ = self.audio.play(self.beep)  # `_ =`: this program never needs the voice


def main() raises:
    run[Beep]("Beep")
```

A bigger one, loading sounds from files, is [examples/audio](../examples/audio/main.mojo).

## Sounds

A `Sound` is decoded samples, an asset like an `Image` (see
[Assets and playheads](programs.md#assets-and-playheads)): immutable, and cheap to copy, since
copies share their samples.

```mojo
# In `create`:
var chime = Sound.load("assets/chime.wav")
```

- **Loading:** `Sound.load(path)` reads WAV, OGG, FLAC or MP3, chosen by the file's contents, not
  its extension. The whole file is decoded at load, to 16-bit samples whatever the file held. It
  raises, naming the path, for a file it can't read or one with no samples.
- **Synthesizing:** `Sound.from_samples(samples, channels=1, sample_rate=44100)` takes `Float64`
  samples from `-1.0` to `1.0`, clipping any outside. With several channels the samples
  interleave, one per channel in turn: left, right, left, right. Each such group is an audio
  *frame*, unrelated to the display's frames. It raises unless `channels` and `sample_rate` are
  positive and the samples are whole frames.
- **Reading:** `channels()`, `sample_rate()`, `frame_count()` and `duration()` in seconds.
  `sample(frame, channel=0)` reads one sample back, from `-1.0` to `1.0`, and is `0.0` outside
  the sound, so drawing a waveform needs no bounds checks.

## Playing

An `Audio` is the program's playback device: construct one in `create` and keep it as a field.
Where no audio device can be opened, as on a server or in CI, it plays silently instead of
raising, so the program still runs.

`audio.play(sound)` plays a sound once and `audio.loop(sound)` over and over until stopped. Each
returns a `Voice`, the handle of that one playback, a playhead in the sound like an `Animator` in
an animation. A sound can play as several voices at once:

```mojo
# In `update`, with `audio: Audio`, `music: Sound`, `jump: Sound` and
# `music_voice: Voice` fields:
if context.keyboard.pressed(Key.SPACE):
    _ = self.audio.play(self.jump, volume=0.6)
if context.keyboard.pressed(Key.M):
    if self.audio.is_playing(self.music_voice):
        self.audio.stop(self.music_voice)
    else:
        self.music_voice = self.audio.loop(self.music)
```

An `Audio` needs nothing each frame. Sound plays on a background thread, so it carries on
smoothly through a slow frame or a long load.

## Voices

A voice becomes **stale** when it ends: a one-shot that has played to its end, or any voice that
was stopped. A call on a stale voice does nothing, safely, even if a newer sound has started
playing since. `Voice.NONE` is no voice, for a field before anything plays.

| Call | Does |
|---|---|
| `stop(voice)` | Stops it for good: it is stale from now on |
| `pause(voice)`, `resume(voice)` | Holds it where it is, and continues it from there |
| `is_playing(voice)`, `is_paused(voice)` | Whether it sounds, or is held. Neither means stale |
| `volume(voice)`, `volume(voice, v)` | Its own volume, `1.0` unless set; `0.0` once stale |
| `speed(voice)`, `speed(voice, s)` | Its playback speed, `1.0` unless set; `0.0` once stale |
| `stop_all()`, `pause_all()`, `resume_all()` | The same for every voice at once |

`play` and `loop` take a starting `volume=` and `speed=`, applied before the first sample
plays. Pass them there rather than setting them right after: by then the first moment may have
played at the old values.

- **Volume:** `0.0` is silent and `1.0` as recorded; above `1.0` amplifies, and below `0.0` is
  silent too. `audio.volume(v)` is the overall volume, which scales every voice's own: a voice
  at `0.5` under an overall `0.5` plays at a quarter. Either applies at once, to voices already
  playing.
- **Speed** plays a voice faster and higher, or slower and lower, as a record sped up or slowed
  down: `2.0` is twice as fast and an octave up. It clamps to `0.01` through `100.0`.
- **A pause screen** calls `pause_all()` on the way in and `resume_all()` on the way out. Voices
  played in between play as usual, so the screen can have sounds of its own; `resume_all` also
  resumes voices paused one by one before.
