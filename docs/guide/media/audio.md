# Audio

Sound effects and music bring a program to life. This page explains how to load a sound from a
file or make one from scratch, how to play it, and how to control each sound while it plays.

## How sound is stored

Sound is a vibration of the air, and a speaker makes it by moving back and forth. A digital sound
stores that movement as a long list of numbers called **samples**, each one the speaker's position
at one instant, from -1 to 1. Played back fast enough, usually 44,100 samples a second (the
**sample rate**), they make the sound again. A stereo sound has two **channels**, one for each
speaker, left and right.

## A first sound

A program that builds a short beep from samples and plays it when Space is pressed:

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
            _ = self.audio.play(self.beep)  # `_ =`: this program never needs the playback


def main() raises:
    run[Beep]("Beep")
```

A bigger one, loading sounds from files, is [examples/audio](../../../examples/audio/main.mojo).

## Sounds

A `Sound` is a sound's samples, ready to play, an asset like an `Image` (see [Assets and
playheads](../basics/programs.md#assets-and-playheads)): it never changes, and it is cheap to
copy, since copies share their samples.

```mojo
# In `create`:
var chime = Sound.load("assets/chime.wav")
```

- **Loading:** `Sound.load(path)` reads WAV, OGG, FLAC or MP3, chosen by the file's contents, not
  its extension. The whole file is decoded at load, to 16-bit samples whatever the file held. It
  raises, naming the path, for a file it can't read or one with no samples.
- **Synthesizing:** `Sound.from_samples(samples, channels=1, sample_rate=44100)` makes a sound from
  a list of `Float64` samples, from `-1.0` to `1.0`; any outside that range are cut off at it. With
  several channels, the samples take turns, one per channel: left, right, left, right. Each such
  group, one sample for every channel, is called an audio *frame*, which has nothing to do with
  the frames a program draws. It raises an error unless `channels` and `sample_rate` are positive
  and the samples make up whole frames.
- **Reading:** `channels()`, `sample_rate()`, `frame_count()` and `duration()` in seconds.
  `sample(frame, channel=0)` reads one sample back, from `-1.0` to `1.0`, and is `0.0` outside
  the sound, so drawing its waveform needs no checks for running off either end.

## Playing

An `Audio` is the program's connection to the computer's speakers: build one in `create` and keep
it as a field. On a computer with no sound output, such as a test server, it plays silently
rather than raising an error, so the program still runs.

`audio.play(sound)` plays a sound once, and `audio.loop(sound)` plays it over and over until
stopped. Each returns a `Playback`, which stands for that one playing of the sound, so the program
can pause it, change its volume or stop it later. It is a playhead in the sound, as an `Animator`
is in an animation, and one sound can be playing several times at once, each with its own
`Playback`:

```mojo
# In `update`, with `audio: Audio`, `music: Sound`, `jump: Sound` and
# `music_playback: Playback` fields:
if context.keyboard.pressed(Key.SPACE):
    _ = self.audio.play(self.jump, volume=0.6)
if context.keyboard.pressed(Key.M):
    if self.audio.is_playing(self.music_playback):
        self.audio.stop(self.music_playback)
    else:
        self.music_playback = self.audio.loop(self.music)
```

An `Audio` needs nothing each frame. Sound plays separately from the program's frames, so it
carries on smoothly through a slow frame or a long load.

## Playbacks

A playback becomes **stale** when it ends: a one-shot that has played to its end, or any playback
that was stopped. A call on a stale playback does nothing, safely, even if a newer sound has started
playing since. `Playback.NONE` is no playback, for a field before anything plays.

| Call | Does |
|---|---|
| `stop(playback)` | Stops it for good: it is stale from now on |
| `pause(playback)`, `resume(playback)` | Holds it where it is, and continues it from there |
| `is_playing(playback)`, `is_paused(playback)` | Whether it sounds, or is held. Neither means stale |
| `volume(playback)`, `volume(playback, v)` | Its own volume, `1.0` unless set; `0.0` once stale |
| `speed(playback)`, `speed(playback, s)` | Its speed, `1.0` unless set; `0.0` once stale |
| `stop_all()`, `pause_all()`, `resume_all()` | The same for every playback at once |

`play` and `loop` take a starting `volume=` and `speed=`, applied before the first sample
plays. Pass them there rather than setting them right after: by then the first moment may have
played at the old values.

- **Volume:** `0.0` is silent and `1.0` as recorded; above `1.0` amplifies, and below `0.0` is
  silent too. `audio.volume(v)` is the overall volume, which scales every playback's own: a playback
  at `0.5` under an overall `0.5` plays at a quarter. Either applies at once, to playbacks already
  playing.
- **Speed** plays a sound faster and higher, or slower and lower, as a record sped up or slowed
  down: `2.0` is twice as fast and an octave up. It is kept between `0.01` and `100.0`.
- **A pause screen** calls `pause_all()` on the way in and `resume_all()` on the way out. Playbacks
  played in between play as usual, so the screen can have sounds of its own; `resume_all` also
  resumes playbacks paused one by one before.
