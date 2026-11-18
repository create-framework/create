# Easing

Things in the real world rarely start or stop moving all at once. A car pulls away slowly and
gathers speed; a ball dropped on the floor bounces before it settles; a drawer slides out quickly
and slows as it reaches the end. **Easing** gives a movement that kind of character. This page
explains what an easing curve is, how to read the names of Create's curves and how to use one.

## What an easing curve does

Many animations come down to a fraction growing from 0 to 1 as time passes: 0 when the movement
starts, 1 when it ends, and 0.5 halfway through. Used directly, that fraction moves things at a
constant speed, from start to end, which looks mechanical.

An easing curve reshapes the fraction. It still starts at 0 and ends at 1, but in between it can run
slowly at first and then catch up, rush ahead and then slow down, overshoot 1 and come back, or
bounce. `ease(curve, t)` applies a curve to the fraction `t`:

```mojo
ease(Easing.LINEAR, 0.5)  # 0.5: no change
ease(Easing.IN_QUAD, 0.5)  # 0.25: still slow halfway through
ease(Easing.OUT_QUAD, 0.5)  # 0.75: already most of the way there
```

Feed the eased fraction to `lerp` to move anything with that character (see
[Interpolation](interpolation.md)):

```mojo
# In `update`, with a fraction `t` running from 0 to 1:
var x = lerp(-300, 300, ease(Easing.OUT_CUBIC, t))
```

Usually you won't call `ease` yourself: a [Tween](../motion/tweens.md) takes an easing curve and
applies it for you.

## Reading the names

Each curve's name is made of two parts: *where* the easing happens, and *what kind* it is.

**Where:**

- **`IN_`** eases at the start: the movement starts slowly and speeds up, ending abruptly. It suits
  things leaving, such as a menu sliding off the screen.
- **`OUT_`** eases at the end: the movement starts quickly and slows down as it arrives. It suits
  things arriving, such as a menu sliding in, and is the most generally useful.
- **`IN_OUT_`** eases at both ends: it starts slowly, speeds up through the middle and slows down
  again to arrive. It suits things moving from one place on the screen to another.

**What kind**, from the gentlest to the strongest:

| Kind | Character |
|---|---|
| `SINE` | Very gentle, barely more than constant speed |
| `QUAD` | Gentle and natural, a good default |
| `CUBIC` | Noticeably stronger |
| `EXPO` | Very strong: almost still at one end, very fast at the other |
| `BACK` | Pulls back a little before it starts (`IN_`), or overshoots and settles back (`OUT_`) |
| `ELASTIC` | Wobbles past the end like a spring before settling |
| `BOUNCE` | Bounces against the end, like a dropped ball |

So `OUT_BACK` arrives quickly, overshoots slightly and settles into place, which is a lively choice
for a button popping up. `OUT_BOUNCE` drops something into place with a bounce. `LINEAR`, with no
easing at all, is the constant speed you started with.

All 22 curves: `LINEAR`, then `IN_`, `OUT_` and `IN_OUT_` versions of `QUAD`, `CUBIC`, `SINE`,
`EXPO`, `BACK`, `ELASTIC` and `BOUNCE`, such as `Easing.IN_OUT_SINE`.

## Values outside 0 to 1

`ease` keeps `t` between 0 and 1 first, so a fraction that runs slightly past the end doesn't make
the movement fly off.

The `BACK` and `ELASTIC` curves, however, leave the range from 0 to 1 *in the middle* of their run,
on purpose: that is the overshoot. Mostly that is what you want, but take care where a value outside
0 to 1 means nothing, such as a colour's alpha, an opacity or a position in a list: clamp the eased
value first (see [`clamp`](interpolation.md#clamp)).
