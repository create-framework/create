"""Scalar helpers for animation and ranges.

Reached through `from create import *`, or by name from `create.math`.
"""

from .number import Number
from std.math import floor, clamp
from .constants import PI


def lerp(a: Number, b: Number, t: Number) -> Float64:
    """Blend from `a` to `b`, `t` running 0 to 1. Not clamped: `t` outside that
    range extrapolates past either end."""
    var start = Float64(a)
    return start + (Float64(b) - start) * Float64(t)


def map(
    value: Number,
    in_low: Number,
    in_high: Number,
    out_low: Number,
    out_high: Number,
) -> Float64:
    """Re-scale `value` from one range onto another: a slider position to a
    world coordinate, say. Linear and unclamped."""
    var low = Float64(in_low)
    var start = Float64(out_low)
    return start + (Float64(value) - low) / (Float64(in_high) - low) * (
        Float64(out_high) - start
    )


def inverse_lerp(value: Number, low: Number, high: Number) -> Float64:
    """Where `value` sits in `[low, high]` as a 0-to-1 fraction. The inverse of
    `lerp`, and `map` with a 0..1 output range."""
    var start = Float64(low)
    return (Float64(value) - start) / (Float64(high) - start)


def smoothstep(edge0: Number, edge1: Number, x: Number) -> Float64:
    """Like `inverse_lerp`, but clamped to 0..1 and eased at both ends: the usual
    choice for a transition that should not start or stop abruptly."""
    var start = Float64(edge0)
    var t = clamp((Float64(x) - start) / (Float64(edge1) - start), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def sign(x: Number) -> Float64:
    """-1.0, 0.0 or 1.0 by the sign of `x`. Zero is its own case, not positive.
    """
    var number = Float64(x)
    if number > 0.0:
        return 1.0
    if number < 0.0:
        return -1.0
    return 0.0


def fractional_part(x: Number) -> Float64:
    """The part after the decimal point, always positive: `fractional_part(-0.25)` is
    0.75, since it floors rather than truncating."""
    var number = Float64(x)
    return number - floor(number)


def wrap(value: Number, period: Number) -> Float64:
    """`value` wrapped into `[0, period)`. Floored, so a negative `value`
    wraps forward instead of staying negative: what an angle or a scrolling
    offset wants."""
    var number = Float64(value)
    var length = Float64(period)
    return number - floor(number / length) * length


def degrees(radians: Number) -> Float64:
    """`radians` in degrees. Rotations take radians, so this is for display."""
    return Float64(radians) * (180.0 / PI)


def radians(degrees: Number) -> Float64:
    """`degrees` in radians, for feeding `rotate` an angle written in degrees.
    """
    return Float64(degrees) * (PI / 180.0)
