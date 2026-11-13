# Runs with an SDL_AUDIO_DRIVER no SDL has, set in `main` before any `Audio`,
# so opening the default device fails as it does on a machine with none.

from std.os import setenv
from std.time import sleep
from std.testing import TestSuite, assert_true
from create.audio import Audio, Sound


def test_audio_plays_silently_where_no_device_opens() raises -> None:
    var audio = Audio()
    var voice = audio.loop(
        Sound.from_samples(List[Float64](length=22050, fill=0.0))
    )
    assert_true(audio.is_playing(voice))
    sleep(0.1)
    assert_true(audio.is_playing(voice))


def main() raises:
    _ = setenv("SDL_AUDIO_DRIVER", "no_such_driver", overwrite=True)
    TestSuite.discover_tests[__functions_in_module()]().run()
