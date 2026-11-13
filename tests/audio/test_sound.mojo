from std.testing import TestSuite, assert_equal, assert_true, assert_raises
from create.audio import Sound
from create.core import source_path


def _fixture(name: String) -> String:
    return source_path("../fixtures/" + name)


def test_from_samples_scales_to_16_bit() raises -> None:
    var data: List[Float64] = [0.0, 1.0, -1.0, 0.5]
    var s = Sound.from_samples(data, channels=2, sample_rate=48000)
    assert_equal(len(s._samples[]), 4)
    assert_equal(s._samples[][0], 0)
    assert_equal(s._samples[][1], 32767)
    assert_equal(s._samples[][2], -32767)
    assert_equal(s._samples[][3], 16384)
    assert_equal(s.channels(), 2)
    assert_equal(s.sample_rate(), 48000)


def test_from_samples_clips_out_of_range() raises -> None:
    var data: List[Float64] = [2.0, -3.0]
    var s = Sound.from_samples(data)
    assert_equal(s._samples[][0], 32767)
    assert_equal(s._samples[][1], -32767)


def test_from_samples_defaults() raises -> None:
    var data: List[Float64] = [0.0, 0.0]
    var s = Sound.from_samples(data)
    assert_equal(s.channels(), 1)
    assert_equal(s.sample_rate(), 44100)


def test_from_samples_rejects_a_bad_format() raises -> None:
    var data: List[Float64] = [0.0, 0.0, 0.0]
    with assert_raises(contains="channels"):
        _ = Sound.from_samples(data, channels=0)
    with assert_raises(contains="sample_rate"):
        _ = Sound.from_samples(data, sample_rate=0)
    with assert_raises(contains="whole frames"):
        _ = Sound.from_samples(data, channels=2)


def test_frame_count_and_duration() raises -> None:
    var data = List[Float64](length=48000, fill=0.0)
    var s = Sound.from_samples(data, channels=2, sample_rate=24000)
    assert_equal(s.frame_count(), 24000)
    assert_equal(s.duration(), 1.0)


def test_sample_reads_back_what_from_samples_took() raises -> None:
    var data: List[Float64] = [0.0, 1.0, -1.0, 0.5]
    var s = Sound.from_samples(data, channels=2)
    assert_equal(s.sample(0), 0.0)
    assert_equal(s.sample(0, channel=1), 1.0)
    assert_equal(s.sample(1, channel=0), -1.0)
    assert_true(abs(s.sample(1, channel=1) - 0.5) < 1.0 / 32767.0)


def test_sample_outside_the_sound_is_silence() raises -> None:
    var data: List[Float64] = [1.0, 1.0]
    var s = Sound.from_samples(data)
    assert_equal(s.sample(-1), 0.0)
    assert_equal(s.sample(2), 0.0)
    assert_equal(s.sample(0, channel=1), 0.0)


def test_sample_of_int16_min_is_minus_one() raises -> None:
    var s = Sound(_samples=[Int16.MIN], _channels=1, _sample_rate=8000)
    assert_equal(s.sample(0), -1.0)


def test_load_wav() raises -> None:
    var s = Sound.load(_fixture("tone.wav"))
    assert_equal(s.channels(), 1)
    assert_equal(s.sample_rate(), 8000)
    assert_equal(s.frame_count(), 80)
    assert_equal(s.duration(), 0.01)
    assert_equal(s._samples[][0], 290)


def test_load_flac() raises -> None:
    var s = Sound.load(_fixture("tone.flac"))
    assert_equal(s.channels(), 1)
    assert_equal(s.sample_rate(), 8000)
    # Lossless, so this can assert exact sample values, not a tolerance --
    # and they match tone.wav's, since both are the same source signal.
    assert_equal(len(s._samples[]), 80)
    assert_equal(s._samples[][0], 290)


def test_load_dispatches_on_magic_bytes_not_extension() raises -> None:
    # tone_disguised.flac holds tone.wav's exact bytes under a `.flac` name --
    # `load` dispatches on the RIFF magic, not the extension, so this must
    # still take the WAV branch.
    var s = Sound.load(_fixture("tone_disguised.flac"))
    assert_equal(s.channels(), 1)
    assert_equal(s.sample_rate(), 8000)
    assert_equal(len(s._samples[]), 80)


def test_load_nonexistent_path_raises() raises -> None:
    with assert_raises():
        _ = Sound.load(_fixture("does_not_exist.wav"))


def test_load_too_short_file_raises() raises -> None:
    with assert_raises():
        _ = Sound.load(_fixture("too_short.bin"))


def test_load_error_names_the_path() raises -> None:
    var path = _fixture("does_not_exist.wav")
    try:
        _ = Sound.load(path)
    except e:
        assert_true(String(e).endswith(path))
        return
    raise Error("expected Sound.load to raise")


def test_load_converts_a_float_wav_to_16_bit() raises -> None:
    # tone_f32.wav is tone.wav's samples as 32-bit floats.
    var s = Sound.load(_fixture("tone_f32.wav"))
    var reference = Sound.load(_fixture("tone.wav"))
    assert_equal(s.channels(), 1)
    assert_equal(s.sample_rate(), 8000)
    assert_equal(len(s._samples[]), len(reference._samples[]))
    for i in range(len(s._samples[])):
        assert_true(
            abs(Int(s._samples[][i]) - Int(reference._samples[][i])) <= 1
        )


def test_load_a_file_with_no_samples_raises() raises -> None:
    # A valid WAV header around zero bytes of data.
    with assert_raises(contains="no samples"):
        _ = Sound.load(_fixture("empty.wav"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
