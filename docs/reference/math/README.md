# create.math

Maths: `Point`, `Vector`, `Transform` and `Matrix`, `Random` and `Noise`, `OptionalNumber`, the easing curves, scalar helpers, `PI` and `TAU`, and the common `std.math` functions.

## Types

| Type | Description |
|---|---|
| [`Easing`](easing.md) | Which curve `ease` applies. A `Tween` stores one as a field. |
| [`Point`](point.md) | A location in world space: `distance`, `lerp`, the affine operators, and an explicit constructor from a `Vector` for crossing between the two. |
| [`OptionalNumber`](optionalnumber.md) | A number that may be left out: any integer or `Float64`, or `None`. |
| [`Vector`](vector.md) | A 2D displacement or direction: arithmetic operators, `magnitude`, `normalize`, `dot`, `distance`, `lerp`, the angle helpers `from_angle`, `angle` and `rotate`, the length helpers `with_length` and `limit`, and an explicit constructor from a `Point`. |
| [`Transform`](transform.md) | A change of position applied to points: moving, turning, scaling, mirroring and shearing, or any combination of them. |
| [`Matrix`](matrix.md) | A grid of numbers, `rows` by `cols`, sized when the program is compiled: for linear algebra, such as solving equations or working in more dimensions than two. |
| [`Random`](random.md) | A seeded pseudo-random generator: `.float()`, `.int()`, `.bool()`. |
| [`Noise`](noise.md) | Smooth pseudo-random values: `.at(x)`, `.at(position)` and `.at(position, time)`, each in `[0.0, 1.0]`. |

## Functions

| Function | Description |
|---|---|
| [`lerp`](lerp.md) | Blend from `a` to `b`, `t` running 0 to 1. Not clamped: `t` outside that range extrapolates past either end. |
| [`map`](map.md) | Re-scale `value` from one range onto another — a slider position to a world coordinate, say. Linear and unclamped. |
| [`inverse_lerp`](inverse_lerp.md) | Where `value` sits in `[low, high]` as a 0-to-1 fraction. The inverse of `lerp`, and `map` with a 0..1 output range. |
| [`smoothstep`](smoothstep.md) | Like `inverse_lerp`, but clamped to 0..1 and eased at both ends — the usual choice for a transition that should not start or stop abruptly. |
| [`sign`](sign.md) | -1.0, 0.0 or 1.0 by the sign of `x`. Zero is its own case, not positive. |
| [`fractional_part`](fractional_part.md) | The part after the decimal point, always positive: `fractional_part(-0.25)` is 0.75, since it floors rather than truncating. |
| [`wrap`](wrap.md) | `value` wrapped into `[0, period)`. Floored, so a negative `value` wraps forward instead of staying negative — what an angle or a scrolling offset wants. |
| [`degrees`](degrees.md) | `radians` in degrees. Rotations take radians, so this is for display. |
| [`radians`](radians.md) | `degrees` in radians, for feeding `rotate` an angle written in degrees. |
| [`ease`](ease.md) | Reshape the fraction `t` by `curve`. |
| [`identity`](identity.md) | The N by N matrix that changes nothing when multiplied by: ones along its diagonal, zeros everywhere else. |
| [`inverse`](inverse.md) | The matrix that undoes `m`: `inverse(m) @ m` is the identity. |

## Constants

### `PI`

```mojo
comptime PI = pi
```

Half a turn in radians.

### `TAU`

```mojo
comptime TAU = tau
```

A whole turn in radians: `2 * PI`.

## From the standard library

Re-exported from `std.math`, so a program has them without a second import: `clamp`, `sqrt`, `floor`, `ceil`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan2`, `exp`, `log`, `log2`, `isnan`, `isinf`, `isfinite`.
