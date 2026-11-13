# Requires SDL_AUDIO_DRIVER=dummy (set globally by the `test` pixi task) so
# this runs without real audio hardware.

from std.testing import TestSuite, assert_equal, assert_true, assert_false
from std.time import sleep
from create.audio import Audio, Sound, Voice


def _tone() raises -> Sound:
    """Half a second: long enough not to end while a test checks it."""
    return Sound.from_samples(List[Float64](length=22050, fill=0.0))


def _blip() raises -> Sound:
    """256 samples, under 6 ms: for a test that waits for a voice to end, or
    a loop shorter than a frame."""
    return Sound.from_samples(List[Float64](length=256, fill=0.0))


def test_play_returns_valid_id() raises -> None:
    var audio = Audio()
    var id = audio.play(_tone())
    assert_true(audio.is_playing(id))


def test_stop_invalidates_id() raises -> None:
    var audio = Audio()
    var id = audio.play(_tone())
    audio.stop(id)
    assert_false(audio.is_playing(id))


def test_stop_all() raises -> None:
    var audio = Audio()
    var a = audio.play(_tone())
    var b = audio.play(_tone())
    audio.stop_all()
    assert_false(audio.is_playing(a))
    assert_false(audio.is_playing(b))


def test_pause_all_holds_every_voice_and_resume_all_continues_them() raises -> (
    None
):
    var audio = Audio()
    var one_shot = audio.play(_tone())
    var looping = audio.loop(_tone())
    var held = audio.loop(_tone())
    audio.pause(held)
    audio.pause_all()
    assert_true(audio.is_paused(one_shot))
    assert_true(audio.is_paused(looping))
    assert_true(audio.is_paused(held))
    var menu = audio.play(_tone())
    assert_true(audio.is_playing(menu))
    audio.resume_all()
    assert_true(audio.is_playing(one_shot))
    assert_true(audio.is_playing(looping))
    assert_true(audio.is_playing(held))


def test_pause_resume() raises -> None:
    var audio = Audio()
    var id = audio.play(_tone())
    audio.pause(id)
    assert_false(audio.is_playing(id))
    audio.resume(id)
    assert_true(audio.is_playing(id))


def test_is_paused_tells_a_paused_voice_from_a_stale_one() raises -> None:
    var audio = Audio()
    var voice = audio.loop(_tone())
    assert_false(audio.is_paused(voice))
    audio.pause(voice)
    assert_true(audio.is_paused(voice))
    assert_false(audio.is_playing(voice))
    audio.resume(voice)
    assert_false(audio.is_paused(voice))
    audio.pause(voice)
    audio.stop(voice)
    assert_false(audio.is_paused(voice))
    assert_false(audio.is_playing(voice))
    assert_false(audio.is_paused(Voice.NONE))


def test_stale_id_after_slot_recycle() raises -> None:
    var audio = Audio()
    var first = audio.play(_tone())
    audio.stop(first)
    var second = audio.play(_tone())
    # first's slot was recycled into second; the stale id must not alias it.
    assert_false(audio.is_playing(first))
    assert_true(audio.is_playing(second))


def test_pausing_one_voice_leaves_the_others_playing() raises -> None:
    # Every voice shares one device, so a pause must hold only its own stream.
    var audio = Audio()
    var held = audio.loop(_tone())
    var other = audio.loop(_tone())
    audio.pause(held)
    assert_false(audio.is_playing(held))
    assert_true(audio.is_playing(other))


def test_pause_twice_then_resume() raises -> None:
    var audio = Audio()
    var id = audio.loop(_tone())
    audio.pause(id)
    audio.pause(id)
    audio.resume(id)
    audio.resume(id)
    assert_true(audio.is_playing(id))


def test_play_loop_returns_valid_id() raises -> None:
    var audio = Audio()
    var id = audio.loop(_tone())
    assert_true(audio.is_playing(id))


def _fed(audio: Audio, voice: Voice) raises -> Int:
    """Bytes a looping voice's callback has queued, read under the stream's
    lock, since the callback writes it on SDL's audio thread."""
    ref slot = audio._voices[Audio._decode(voice._id)[0]]
    audio._sdl.lock(slot.stream)
    var fed = slot.loop_feed.value()[].fed
    audio._sdl.unlock(slot.stream)
    return fed


comptime _BYTES_PER_SECOND = 44100 * 2
"""Mono 16-bit at 44.1 kHz, as `_tone` and `_blip` are."""


def test_a_short_loop_keeps_sounding() raises -> None:
    # Under 6 ms of sound, and nothing done each frame: the device asks for
    # more on its own thread. The dummy driver plays in real time, so a third of
    # a second asks for at least a fifth of a second's samples.
    var audio = Audio()
    var voice = audio.loop(_blip())
    sleep(0.3)
    assert_true(_fed(audio, voice) >= _BYTES_PER_SECOND // 5)
    assert_true(audio.is_playing(voice))


def test_a_faster_loop_is_fed_faster() raises -> None:
    var audio = Audio()
    var voice = audio.loop(_blip(), speed=4.0)
    sleep(0.3)
    assert_true(_fed(audio, voice) >= 4 * _BYTES_PER_SECOND // 5)


def test_a_long_loop_is_fed_as_asked_not_whole() raises -> None:
    # Ten seconds of sound: not queued whole at the start.
    var audio = Audio()
    var voice = audio.loop(
        Sound.from_samples(List[Float64](length=441000, fill=0.0))
    )
    sleep(0.1)
    assert_true(_fed(audio, voice) < 10 * _BYTES_PER_SECOND)


def test_a_paused_loop_is_not_fed() raises -> None:
    var audio = Audio()
    var voice = audio.loop(_blip())
    audio.pause(voice)
    var fed = _fed(audio, voice)
    sleep(0.2)
    assert_true(_fed(audio, voice) - fed < _BYTES_PER_SECOND // 20)


def test_stop_releases_looping_voice() raises -> None:
    var audio = Audio()
    var id = audio.loop(_tone())
    audio.stop(id)
    assert_false(audio.is_playing(id))


def test_stop_all_releases_looping_and_one_shot_together() raises -> None:
    var audio = Audio()
    var one_shot = audio.play(_tone())
    var looping = audio.loop(_tone())
    audio.stop_all()
    assert_false(audio.is_playing(one_shot))
    assert_false(audio.is_playing(looping))


def test_looping_voice_shares_sound_via_refcount() raises -> None:
    var audio = Audio()
    var sound = _tone()
    assert_equal(sound._samples.count(), 1)
    var id = audio.loop(sound)
    # `loop` copies the sound into the voice's feed, sharing its samples.
    assert_equal(sound._samples.count(), 2)
    audio.stop(id)
    assert_equal(sound._samples.count(), 1)


def test_voice_none_is_never_valid() raises -> None:
    var audio = Audio()
    assert_false(audio.is_playing(Voice.NONE))
    audio.stop(Voice.NONE)
    audio.pause(Voice.NONE)
    audio.resume(Voice.NONE)
    audio.volume(Voice.NONE, 1.0)
    var id = audio.play(_tone())
    assert_false(audio.is_playing(Voice.NONE))
    assert_true(audio.is_playing(id))


def test_a_negative_id_is_invalid() raises -> None:
    var audio = Audio()
    var id = audio.play(_tone())
    assert_false(audio.is_playing(Voice(_id=-1)))
    audio.stop(Voice(_id=-1))
    assert_true(audio.is_playing(id))


def test_out_of_range_id_is_invalid() raises -> None:
    var audio = Audio()
    var id = audio.play(_tone())
    var out_of_range = Voice(_id=(1 << 32) | 9999)  # past the end of _voices
    assert_false(audio.is_playing(out_of_range))
    audio.stop(out_of_range)
    audio.pause(out_of_range)
    audio.resume(out_of_range)
    audio.volume(out_of_range, 1.0)
    assert_true(audio.is_playing(id))


def _wait_until_stale(audio: Audio, voice: Voice) raises -> Bool:
    """Poll for a one-shot to play out: under the dummy driver a 256-sample
    buffer drains in real time, so only waiting can show it."""
    for _ in range(200):
        if not audio.is_playing(voice):
            return True
        sleep(0.01)
    return False


def test_a_finished_one_shot_is_stale() raises -> None:
    var audio = Audio()
    var one_shot = audio.play(_blip())
    var looping = audio.loop(_blip())
    assert_true(_wait_until_stale(audio, one_shot))
    assert_true(audio.is_playing(looping))


def test_play_reuses_a_finished_voice_slot() raises -> None:
    var audio = Audio()
    var first = audio.play(_blip())
    assert_true(_wait_until_stale(audio, first))
    var second = audio.play(_blip())
    assert_equal(len(audio._voices), 1)
    assert_true(second != first)


def test_a_paused_one_shot_is_never_freed() raises -> None:
    var audio = Audio()
    var voice = audio.play(_tone())
    audio.pause(voice)
    sleep(0.1)
    _ = audio.play(_tone())  # frees every slot whose voice has ended
    assert_true(audio.is_paused(voice))
    audio.resume(voice)
    assert_true(audio.is_playing(voice))


def test_many_concurrent_voices() raises -> None:
    var audio = Audio()
    var ids = List[Voice]()
    for _ in range(16):
        ids.append(audio.play(_tone()))

    for i in range(16):
        assert_true(audio.is_playing(ids[i]))
    for i in range(16):
        for j in range(i + 1, 16):
            assert_true(ids[i] != ids[j])

    for i in range(0, 16, 2):
        audio.stop(ids[i])
    for i in range(16):
        if i % 2 == 0:
            assert_false(audio.is_playing(ids[i]))
        else:
            assert_true(audio.is_playing(ids[i]))

    var more = List[Voice]()
    for _ in range(8):
        more.append(audio.play(_tone()))
    for i in range(8):
        for j in range(0, 16, 2):
            assert_true(more[i] != ids[j])


def test_voice_volume_does_not_disturb_is_playing() raises -> None:
    var audio = Audio()
    var id = audio.play(_tone())
    audio.volume(id, 0.3)
    assert_true(audio.is_playing(id))


def test_voice_volume_on_stale_id_is_a_no_op() raises -> None:
    var audio = Audio()
    var first = audio.play(_tone())
    audio.stop(first)
    var second = audio.play(_tone())
    audio.volume(first, 0.5)
    assert_false(audio.is_playing(first))
    assert_true(audio.is_playing(second))


def _gain(audio: Audio, voice: Voice) raises -> Float32:
    return audio._sdl.gain(audio._voices[Audio._decode(voice._id)[0]].stream)


def test_voice_volume_reads_back() raises -> None:
    var audio = Audio()
    var voice = audio.play(_tone())
    assert_equal(audio.volume(voice), 1.0)
    audio.volume(voice, 0.4)
    assert_equal(audio.volume(voice), 0.4)
    audio.stop(voice)
    assert_equal(audio.volume(voice), 0.0)


def test_play_and_loop_start_at_the_volume_given() raises -> None:
    var audio = Audio()
    audio.volume(0.5)
    var one_shot = audio.play(_tone(), volume=0.4)
    var looping = audio.loop(_tone(), volume=0.6)
    assert_equal(audio.volume(one_shot), 0.4)
    assert_equal(audio.volume(looping), 0.6)
    assert_equal(_gain(audio, one_shot), Float32(0.2))
    assert_equal(_gain(audio, looping), Float32(0.3))


def test_a_negative_volume_is_silent_not_an_error() raises -> None:
    var audio = Audio()
    audio.volume(-0.5)
    assert_equal(audio.volume(), 0.0)
    audio.volume(1.0)
    var voice = audio.play(_tone(), volume=-1.0)
    assert_equal(audio.volume(voice), 0.0)
    audio.volume(voice, -2.0)
    assert_equal(audio.volume(voice), 0.0)
    assert_equal(_gain(audio, voice), Float32(0.0))


def test_a_volume_above_one_amplifies() raises -> None:
    var audio = Audio()
    var voice = audio.play(_tone(), volume=2.0)
    assert_equal(_gain(audio, voice), Float32(2.0))


def _ratio(audio: Audio, voice: Voice) raises -> Float32:
    return audio._sdl.frequency_ratio(
        audio._voices[Audio._decode(voice._id)[0]].stream
    )


def test_speed_reads_back_and_reaches_the_stream() raises -> None:
    var audio = Audio()
    var voice = audio.loop(_tone())
    assert_equal(audio.speed(voice), 1.0)
    audio.speed(voice, 2.0)
    assert_equal(audio.speed(voice), 2.0)
    assert_equal(_ratio(audio, voice), Float32(2.0))
    audio.stop(voice)
    assert_equal(audio.speed(voice), 0.0)
    audio.speed(voice, 3.0)


def test_play_starts_at_the_speed_given_and_clamps_it() raises -> None:
    var audio = Audio()
    var slow = audio.play(_tone(), speed=0.5)
    var stopped = audio.loop(_tone(), speed=0.0)
    var fast = audio.loop(_tone(), speed=1000.0)
    assert_equal(_ratio(audio, slow), Float32(0.5))
    assert_equal(audio.speed(stopped), 0.01)
    assert_equal(audio.speed(fast), 100.0)


def test_volume_reads_back_its_default_and_what_was_set() raises -> None:
    var audio = Audio()
    assert_equal(audio.volume(), 1.0)
    audio.volume(0.25)
    assert_equal(audio.volume(), 0.25)


def test_volume_reaches_voices_already_playing() raises -> None:
    var audio = Audio()
    var one_shot = audio.play(_tone())
    var looping = audio.loop(_tone())
    audio.volume(0.5)
    assert_equal(_gain(audio, one_shot), Float32(0.5))
    assert_equal(_gain(audio, looping), Float32(0.5))
    assert_equal(_gain(audio, audio.play(_tone())), Float32(0.5))


def test_voice_volume_is_scaled_by_the_volume() raises -> None:
    var audio = Audio()
    var id = audio.play(_tone())
    audio.volume(id, 0.5)
    audio.volume(0.5)
    assert_equal(_gain(audio, id), Float32(0.25))
    audio.volume(1.0)
    assert_equal(_gain(audio, id), Float32(0.5))


def _play_and_drop_scope() raises:
    var audio = Audio()
    _ = audio.play(_tone())
    _ = audio.loop(_tone())
    _ = audio.play(_tone())


def test_clean_teardown_with_live_voices() raises -> None:
    # `audio` from the helper above drops at the end of its scope, exercising
    # `__deinit__` with live one-shot and looping voices still open. There is
    # little to assert since `__deinit__` swallows exceptions -- that's the
    # finding -- but a second `Audio` working afterward proves teardown
    # didn't abort the process or leave the device in a broken state.
    _play_and_drop_scope()
    var audio = Audio()
    var id = audio.play(_tone())
    assert_true(audio.is_playing(id))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
