from std.testing import (
    TestSuite,
    assert_equal,
    assert_almost_equal,
    assert_true,
)
from std.math import abs
from create.math.matrix import Matrix, identity, inverse


def test_zero_init() raises -> None:
    var m = Matrix[2, 2]()
    assert_equal(m[0, 0], 0.0)
    assert_equal(m[0, 1], 0.0)
    assert_equal(m[1, 0], 0.0)
    assert_equal(m[1, 1], 0.0)


def test_compares_by_elements() raises -> None:
    assert_true(Matrix[2, 2](1, 2, 3, 4) == Matrix[2, 2](1, 2, 3, 4))
    assert_true(Matrix[2, 2](1, 2, 3, 4) != Matrix[2, 2](1, 2, 3, 5))
    assert_true(identity[2]() == Matrix[2, 2](1, 0, 0, 1))


def test_get_set() raises -> None:
    var m = Matrix[3, 3]()
    m[1, 2] = 7.5
    assert_equal(m[1, 2], 7.5)
    assert_equal(m[0, 0], 0.0)


def test_identity_2x2() raises -> None:
    var m = identity[2]()
    assert_equal(m[0, 0], 1.0)
    assert_equal(m[1, 1], 1.0)
    assert_equal(m[0, 1], 0.0)
    assert_equal(m[1, 0], 0.0)


def test_identity_3x3() raises -> None:
    var m = identity[3]()
    for i in range(3):
        for j in range(3):
            var expected = 1.0 if i == j else 0.0
            assert_equal(m[i, j], expected)


def test_matmul_by_identity() raises -> None:
    var m = Matrix[2, 2]()
    m[0, 0] = 1.0
    m[0, 1] = 2.0
    m[1, 0] = 3.0
    m[1, 1] = 4.0
    var id = identity[2]()
    var r = m @ id
    assert_equal(r[0, 0], 1.0)
    assert_equal(r[0, 1], 2.0)
    assert_equal(r[1, 0], 3.0)
    assert_equal(r[1, 1], 4.0)


def test_matmul_values() raises -> None:
    # [[1,2],[3,4]] @ [[5,6],[7,8]] = [[19,22],[43,50]]
    var a = Matrix[2, 2]()
    a[0, 0] = 1.0
    a[0, 1] = 2.0
    a[1, 0] = 3.0
    a[1, 1] = 4.0
    var b = Matrix[2, 2]()
    b[0, 0] = 5.0
    b[0, 1] = 6.0
    b[1, 0] = 7.0
    b[1, 1] = 8.0
    var r = a @ b
    assert_equal(r[0, 0], 19.0)
    assert_equal(r[0, 1], 22.0)
    assert_equal(r[1, 0], 43.0)
    assert_equal(r[1, 1], 50.0)


def test_matmul_above_the_unroll_limit() raises -> None:
    # 5 by 5 by 5 is past the size `@` unrolls, so this takes its loop.
    var m = Matrix[5, 5]()
    for r in range(5):
        for c in range(5):
            m[r, c] = Float64(r * 5 + c)
    assert_true(m @ identity[5]() == m)
    assert_true(identity[5]() @ m == m)
    var twice = m @ m
    assert_equal(twice[0, 0], 150.0)  # 0*0 + 1*5 + 2*10 + 3*15 + 4*20
    assert_equal(twice[4, 4], 1590.0)  # 20*4 + 21*9 + 22*14 + 23*19 + 24*24


def test_transpose_square() raises -> None:
    var m = Matrix[2, 2]()
    m[0, 0] = 1.0
    m[0, 1] = 2.0
    m[1, 0] = 3.0
    m[1, 1] = 4.0
    var t = m.transpose()
    assert_equal(t[0, 0], 1.0)
    assert_equal(t[0, 1], 3.0)
    assert_equal(t[1, 0], 2.0)
    assert_equal(t[1, 1], 4.0)


def test_transpose_non_square() raises -> None:
    # 2×3 → 3×2: element [r,c] maps to [c,r]
    var m = Matrix[2, 3]()
    m[0, 0] = 1.0
    m[0, 1] = 2.0
    m[0, 2] = 3.0
    m[1, 0] = 4.0
    m[1, 1] = 5.0
    m[1, 2] = 6.0
    var t = m.transpose()
    assert_equal(t[0, 0], 1.0)
    assert_equal(t[1, 0], 2.0)
    assert_equal(t[2, 0], 3.0)
    assert_equal(t[0, 1], 4.0)
    assert_equal(t[2, 1], 6.0)


def test_inverse_2x2() raises -> None:
    # [[2,1],[1,1]], det=1, inverse=[[1,-1],[-1,2]]
    var m = Matrix[2, 2]()
    m[0, 0] = 2.0
    m[0, 1] = 1.0
    m[1, 0] = 1.0
    m[1, 1] = 1.0
    var inv = inverse(m)
    assert_almost_equal(inv[0, 0], 1.0, atol=1e-9)
    assert_almost_equal(inv[0, 1], -1.0, atol=1e-9)
    assert_almost_equal(inv[1, 0], -1.0, atol=1e-9)
    assert_almost_equal(inv[1, 1], 2.0, atol=1e-9)


def test_inverse_roundtrip_3x3() raises -> None:
    # M @ inverse(M) ≈ identity
    var m = Matrix[3, 3]()
    m[0, 0] = 1.0
    m[0, 1] = 2.0
    m[0, 2] = 0.0
    m[1, 0] = 0.0
    m[1, 1] = 1.0
    m[1, 2] = 3.0
    m[2, 0] = 0.0
    m[2, 1] = 0.0
    m[2, 2] = 1.0
    var inv = inverse(m)
    var prod = m @ inv
    for i in range(3):
        for j in range(3):
            var expected = 1.0 if i == j else 0.0
            assert_almost_equal(prod[i, j], expected, atol=1e-9)


def test_inverse_of_identity() raises -> None:
    var m = identity[3]()
    var inv = inverse(m)
    for i in range(3):
        for j in range(3):
            var expected = 1.0 if i == j else 0.0
            assert_almost_equal(inv[i, j], expected, atol=1e-9)


def test_inverse_with_pivot_swap() raises -> None:
    # m[0,0] is zero, forcing the partial-pivot row swap before elimination.
    var m = Matrix[3, 3]()
    m[0, 0] = 0.0
    m[0, 1] = 1.0
    m[0, 2] = 2.0
    m[1, 0] = 1.0
    m[1, 1] = 0.0
    m[1, 2] = 3.0
    m[2, 0] = 4.0
    m[2, 1] = 5.0
    m[2, 2] = 6.0
    var inv = inverse(m)
    var prod = m @ inv
    for i in range(3):
        for j in range(3):
            var expected = 1.0 if i == j else 0.0
            assert_almost_equal(prod[i, j], expected, atol=1e-9)


def test_inverse_of_singular_matrix_is_garbage() raises -> None:
    # Row 2 = row 0 + row 1: exactly singular, determinant 0. This
    # implementation has no singularity check, so a near-zero pivot from
    # rounding error (not a true zero) is divided into rather than
    # rejected — the result is huge, unusable finite values, not NaN and
    # not a valid inverse.
    var m = Matrix[3, 3]()
    m[0, 0] = 1.0
    m[0, 1] = 2.0
    m[0, 2] = 3.0
    m[1, 0] = 4.0
    m[1, 1] = 5.0
    m[1, 2] = 6.0
    m[2, 0] = 5.0
    m[2, 1] = 7.0
    m[2, 2] = 9.0
    var inv = inverse(m)
    var max_abs = 0.0
    for i in range(3):
        for j in range(3):
            var v = abs(inv[i, j])
            if v > max_abs:
                max_abs = v
    assert_true(max_abs > 1e10)

    var prod = m @ inv
    # The product is nowhere near identity — this is not a usable inverse.
    var off = abs(prod[0, 0] - 1.0)
    assert_true(off > 0.01)


def test_copy_ctor_is_independent() raises -> None:
    var m = Matrix[2, 2]()
    m[0, 0] = 1.0
    m[0, 1] = 2.0
    m[1, 0] = 3.0
    m[1, 1] = 4.0
    var c = Matrix[2, 2](copy=m)
    m[0, 0] = 99.0
    assert_equal(c[0, 0], 1.0)
    assert_equal(c[0, 1], 2.0)
    assert_equal(c[1, 0], 3.0)
    assert_equal(c[1, 1], 4.0)


def test_prints_as_source() raises -> None:
    var m = Matrix[2, 3]()
    m[0, 0] = 1.0
    m[0, 1] = 2.0
    m[0, 2] = 3.0
    m[1, 0] = 4.0
    m[1, 1] = 5.0
    m[1, 2] = -60.5
    assert_equal(
        String(m),
        "Matrix[2, 3](\n    1.0, 2.0,   3.0,\n    4.0, 5.0, -60.5,\n)",
    )


def test_printed_form_is_source() raises -> None:
    # What `test_prints_as_source` prints, pasted back in (and reflowed by
    # `mojo format`): the trailing comma parses.
    var m = Matrix[2, 3](
        1.0,
        2.0,
        3.0,
        4.0,
        5.0,
        -60.5,
    )
    assert_equal(m[1, 2], -60.5)


def test_values_fill_row_by_row() raises -> None:
    var m = Matrix[2, 2](1.0, 2.0, 3.0, 4.0)
    assert_equal(m[0, 1], 2.0)
    assert_equal(m[1, 0], 3.0)
    assert_true(m == Matrix[2, 2](1.0, 2.0, 3.0, 4.0))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
