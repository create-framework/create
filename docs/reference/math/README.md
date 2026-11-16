# create.math

Maths: `Point2D`, `Vector2D` and `Matrix`, `Random` and `Noise`, the easing curves, scalar helpers, `PI` and `TAU`, and the common `std.math` functions.

## Types

| Type | Description |
|---|---|
| [`Easing`](easing.md) | Which curve `ease` applies. A `Tween` stores one as a field. |
| [`Point2D`](point2d.md) | A location in world space: `distance`, `lerp`, the affine operators, and an explicit constructor from a `Vector2D` for crossing between the two. |
| [`Vector2D`](vector2d.md) | A 2D displacement or direction: arithmetic operators, `magnitude`, `normalize`, `dot`, `distance`, `lerp`, the angle helpers `from_angle`, `angle` and `rotate`, the length helpers `with_length` and `limit`, and an explicit constructor from a `Point2D`. |
| [`Matrix`](matrix.md) | A fixed-size matrix, row-major, sized at compile time. |
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
| [`identity`](identity.md) | The N x N transform that changes nothing — the start of a composition. |
| [`inverse`](inverse.md) | The transform that undoes `m` — Gauss-Jordan with partial pivoting. |
| [`apply`](apply.md) | `point` mapped through `m`, translation included. |
| [`translate`](translate.md) | Move by `(dx, dy)` in world units. `dy` is up, since y grows upward. |
| [`rotate`](rotate.md) | Turn by `angle` radians about the origin, counter-clockwise — the mathematical convention, which holds here because y grows upward. Use `radians(d)` for an angle written in degrees. |
| [`scale`](scale.md) | Scale each axis about the origin. Negative values mirror. |

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
