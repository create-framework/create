# create.audio

Sound: `Sound` (the asset), `Audio` (the playback device) and `Playback` (one playback).

## Types

| Type | Description |
|---|---|
| [`Sound`](sound.md) | Decoded samples, the asset, not a playing playback: 16-bit integers, channels interleaved, whatever the file held. |
| [`Audio`](audio.md) | Program-owned playback device. Construct once, hold as a Program field, call `play` from `update`. Where no audio device can be opened, it plays silently rather than raising. |
| [`Playback`](playback.md) | One playback of a `Sound`, as `audio.play` and `audio.loop` return it: the handle `stop`, `pause`, `resume`, `volume`, `speed`, `is_playing` and `is_paused` take. |
