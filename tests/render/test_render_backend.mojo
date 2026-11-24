# RenderBackend.from_arguments reads the command line, and asks in the
# terminal when it names no backend; its rules are tested on lists and answers
# through the internal _from_argument_list and _from_answer it delegates to.
# The prompt itself needs a terminal, so it isn't tested here.

from std.testing import TestSuite, assert_equal, assert_false

from create import *


def test_no_arguments_name_no_backend() raises -> None:
    assert_false(RenderBackend._from_argument_list(List[String]()))


def test_gpu_among_other_arguments_is_the_gpu() raises -> None:
    var arguments: List[String] = ["fullscreen", "gpu"]
    assert_equal(
        RenderBackend._from_argument_list(arguments).value(), RenderBackend.GPU
    )


def test_the_last_named_backend_wins() raises -> None:
    var arguments: List[String] = ["gpu", "cpu"]
    assert_equal(
        RenderBackend._from_argument_list(arguments).value(), RenderBackend.CPU
    )
    arguments = ["cpu", "gpu"]
    assert_equal(
        RenderBackend._from_argument_list(arguments).value(), RenderBackend.GPU
    )


def test_unrelated_arguments_name_no_backend() raises -> None:
    var arguments: List[String] = ["GPU", "--gpu", "fullscreen"]
    assert_false(RenderBackend._from_argument_list(arguments))


def test_an_answer_ignores_case_and_spaces() raises -> None:
    assert_equal(
        RenderBackend._from_answer(" GPU \n").value(), RenderBackend.GPU
    )
    assert_equal(RenderBackend._from_answer("cpu").value(), RenderBackend.CPU)
    assert_equal(RenderBackend._from_answer("Cpu").value(), RenderBackend.CPU)


def test_an_answer_naming_neither_is_no_backend() raises -> None:
    assert_false(RenderBackend._from_answer(""))
    assert_false(RenderBackend._from_answer("vulkan"))
    assert_false(RenderBackend._from_answer("g pu"))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
