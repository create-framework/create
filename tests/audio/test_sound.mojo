from std.testing import TestSuite, assert_equal, assert_true, assert_raises
from create.audio import Sound
from create.core import source_path


def _fixture(name: String) -> String:
    return source_path("../fixtures/" + name)


def test_from_pcm_keeps_the_samples_and_format() raises -> None:
    var data: List[Int16] = [0, 100, -100, Int16.MIN]
    var s = Sound.from_pcm(data, channels=2, sample_rate=48000)
    assert_equal(len(s._samples[]), 4)
    assert_equal(s._samples[][3], Int16.MIN)
    assert_equal(s.channels(), 2)
    assert_equal(s.sample_rate(), 48000)


def test_from_pcm_defaults() raises -> None:
    var data: List[Int16] = [0, 0]
    var s = Sound.from_pcm(data)
    assert_equal(s.channels(), 1)
    assert_equal(s.sample_rate(), 44100)


def test_load_wav() raises -> None:
    var s = Sound.load(_fixture("tone.wav"))
    assert_equal(s.channels(), 1)
    assert_equal(s.sample_rate(), 8000)
    assert_equal(len(s._samples[]), 80)
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
