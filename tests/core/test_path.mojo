"""Resolving a relative path against the calling source file."""

from std.os import remove
from std.testing import TestSuite, assert_equal, assert_true

from create.core import source_path
from create.data import JSON


def test_a_relative_path_resolves_against_this_file() raises -> None:
    var path = source_path("x.png")
    assert_true(path.startswith("/"), path)
    assert_true(path.endswith("/tests/core/x.png"), path)


def test_an_absolute_path_is_kept() raises -> None:
    assert_equal(source_path("/tmp/x.png"), "/tmp/x.png")


def _resolved_in_a_helper() -> String:
    return source_path("y.png")


def test_a_helper_resolves_against_its_own_file() raises -> None:
    assert_equal(_resolved_in_a_helper(), source_path("y.png"))


def test_a_loader_resolves_against_its_caller() raises -> None:
    var relative = JSON.load("../fixtures/data/config.json")
    var resolved = JSON.load(source_path("../fixtures/data/config.json"))
    assert_equal(String(relative), String(resolved))


def test_a_saver_resolves_against_its_caller() raises -> None:
    var path = "test_path_saved.json"
    JSON.parse('{"a": 1}').save(path)
    var back = JSON.load(source_path(path))
    remove(source_path(path))
    assert_equal(String(back), '{"a":1}')


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
