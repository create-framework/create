# Audio

Playing sounds: loading or synthesizing a `Sound`, playing it through an `Audio` as voices, and
controlling each voice. A complete program is [examples/audio](../examples/audio/main.mojo).

## Sounds

A `Sound` is decoded samples, an asset like an `Image` (see
[Assets and playheads](programs.md#assets-and-playheads)): immutable, and cheap to copy, since
copies share their samples.

```mojo
# A fragment, inside `create`.
var chime = Sound.load(source_path("assets/chime.wav"))
```

- **Loading:** `Sound.load(path)` reads WAV, OGG, FLAC or MP3, chosen by the file's contents, not
  its extension. The whole file is decoded at load, to 16-bit samples whatever the file held. It
  raises, naming the path, for a file it can't read or one with no samples.
- **Synthesizing:** `Sound.from_samples(samples, channels=1, sample_rate=44100)` takes `Float64`
  samples from `-1.0` to `1.0`, clipping any outside. With several channels they interleave, a
  sample of each to a frame: left, right, left, right. It raises unless `channels` and
  `sample_rate` are positive and the samples are whole frames.
- **Reading:** `channels()`, `sample_rate()`, `frame_count()` and `duration()` in seconds.
  `sample(frame, channel=0)` reads one sample back, from `-1.0` to `1.0`, and is `0.0` outside
  the sound, so drawing a waveform needs no bounds checks.

A one-second 440 Hz tone:

```mojo
# A fragment, inside `create`.
var samples = List[Float64](capacity=44100)
for i in range(44100):
    samples.append(0.5 * sin(TAU * 440.0 * Float64(i) / 44100.0))
var tone = Sound.from_samples(samples)
```

## Playing

An `Audio` is the program's playback device: construct one in `create` and keep it as a field.
Where no audio device can be opened, as on a server or in CI, it plays silently instead of
raising, so the program still runs.

`audio.play(sound)` plays a sound once and `audio.loop(sound)` over and over until stopped. Each
returns a `Voice`, the handle of that one playback, a playhead in the sound like an `Animator` in
an animation. A sound can play as many voices at once:

```mojo
# A fragment of `update`: the program has `audio: Audio`, `music: Sound`, `jump: Sound` and
# `music_voice: Voice` fields.
if context.keyboard.pressed(Key.SPACE):
    _ = self.audio.play(self.jump, volume=0.6)
if context.keyboard.pressed(Key.M):
    if self.audio.is_playing(self.music_voice):
        self.audio.stop(self.music_voice)
    else:
        self.music_voice = self.audio.loop(self.music)
```

An `Audio` needs nothing each frame. A looping voice is fed on SDL's audio thread whenever the
device wants more, so it plays on through a slow frame or a long load; a one-shot voice is stale
once it has played to its end.

## Voices

Each call taking a voice does nothing once the voice is stale, that is once it has ended (a
one-shot that played to its end) or been stopped, even after its slot plays another sound.
`Voice.NONE` is no voice, for a field before anything plays.

| Call | Does |
|---|---|
| `stop(voice)` | Stops it for good: it is stale from now on |
| `pause(voice)`, `resume(voice)` | Holds it where it is, and continues it from there |
| `is_playing(voice)`, `is_paused(voice)` | Whether it sounds, or is held. Neither means stale |
| `volume(voice)`, `volume(voice, v)` | Its own volume, `1.0` unless set; `0.0` once stale |
| `speed(voice)`, `speed(voice, s)` | Its playback speed, `1.0` unless set; `0.0` once stale |
| `stop_all()`, `pause_all()`, `resume_all()` | The same for every voice at once |

`play` and `loop` take a starting `volume=` and `speed=`, applied before the first sample
plays; setting them afterwards can let the start through as it was.

- **Volume:** `0.0` is silent and `1.0` as recorded; above `1.0` amplifies, and below `0.0` is
  silent too. `audio.volume(v)` is the overall volume, which scales every voice's own: a voice
  at `0.5` under an overall `0.5` plays at a quarter. Either applies at once, to voices already
  playing.
- **Speed** plays a voice faster and higher, or slower and lower, as a record sped up or slowed
  down: `2.0` is twice as fast and an octave up. It clamps to `0.01` through `100.0`.
- **A pause screen** calls `pause_all()` on the way in and `resume_all()` on the way out. Voices
  played in between play as usual, so the screen can have sounds of its own; `resume_all` also
  resumes voices paused one by one before.
