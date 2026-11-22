from std.testing import (
    TestSuite,
    assert_almost_equal,
    assert_equal,
    assert_true,
)
from create.math import PI
from create.geometry import Rectangle
from create.math.point import Point
from create.math.vector import Vector


def _assert_rect(
    got: Rectangle, x: Float64, y: Float64, width: Float64, height: Float64
) raises -> None:
    assert_almost_equal(got.position.x, x, atol=1e-9)
    assert_almost_equal(got.position.y, y, atol=1e-9)
    assert_almost_equal(got.width, width, atol=1e-9)
    assert_almost_equal(got.height, height, atol=1e-9)


def test_inset_moves_each_side_in() raises -> None:
    var r = Rectangle((10, 20), 100, 60, corner_radius=4).inset(5)
    _assert_rect(r, 10, 20, 90, 50)
    assert_equal(r.corner_radius, 4.0)


def test_negative_inset_grows() raises -> None:
    _assert_rect(Rectangle((0, 0), 100, 60).inset(-10), 0, 0, 120, 80)


def test_inset_stops_at_zero() raises -> None:
    _assert_rect(Rectangle((0, 0), 100, 20).inset(15), 0, 0, 70, 0)


def test_columns_are_equal_left_first_with_gaps() raises -> None:
    var cells = Rectangle((0, 0), 300, 100).columns(3, gap=10)
    assert_equal(len(cells), 3)
    var w = 280.0 / 3.0
    _assert_rect(cells[0], -150 + w / 2, 0, w, 100)
    _assert_rect(cells[1], 0, 0, w, 100)
    _assert_rect(cells[2], 150 - w / 2, 0, w, 100)


def test_rows_are_top_first() raises -> None:
    var rows = Rectangle((0, 50), 200, 100).rows(2)
    _assert_rect(rows[0], 0, 75, 200, 50)
    _assert_rect(rows[1], 0, 25, 200, 50)


def test_rows_with_gaps_tile_the_height() raises -> None:
    var rows = Rectangle((0, 0), 40, 100).rows(4, gap=4)
    assert_almost_equal(rows[0].top(), 50.0, atol=1e-9)
    assert_almost_equal(rows[3].bottom(), -50.0, atol=1e-9)
    for i in range(3):
        assert_almost_equal(rows[i].bottom() - rows[i + 1].top(), 4.0)


def test_weights_share_in_proportion() raises -> None:
    var weights: List[Float64] = [1, 3]
    var cells = Rectangle((0, 0), 408, 40).columns(weights=weights, gap=8)
    _assert_rect(cells[0], -204 + 50, 0, 100, 40)
    _assert_rect(cells[1], 204 - 150, 0, 300, 40)
    var rows = Rectangle((0, 0), 40, 400).rows(weights=weights)
    _assert_rect(rows[0], 0, 150, 40, 100)
    _assert_rect(rows[1], 0, -50, 40, 300)


def test_no_pieces() raises -> None:
    assert_equal(len(Rectangle((0, 0), 10, 10).columns(0)), 0)
    assert_equal(
        len(Rectangle((0, 0), 10, 10).rows(weights=List[Float64]())), 0
    )


def test_gaps_wider_than_the_rectangle_leave_empty_pieces() raises -> None:
    for cell in Rectangle((0, 0), 10, 10).columns(3, gap=20):
        assert_equal(cell.width, 0.0)


def test_pieces_are_sharp() raises -> None:
    for row in Rectangle((0, 0), 100, 100, corner_radius=10).rows(2):
        assert_equal(row.corner_radius, 0.0)


def test_a_turned_rectangle_is_cut_along_its_own_axes() raises -> None:
    # turned a quarter turn, its own "left" points down the screen
    var r = Rectangle((10, 0), 200, 40, rotation=PI / 2)
    var cells = r.columns(2)
    for cell in cells:
        assert_almost_equal(cell.rotation, PI / 2)
        assert_almost_equal(cell.width, 100.0)
        assert_almost_equal(cell.height, 40.0)
    _assert_rect(cells[0], 10, -50, 100, 40)
    _assert_rect(cells[1], 10, 50, 100, 40)
    assert_true(r.contains(cells[0].position))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
