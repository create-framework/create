# Random numbers

Random numbers make a program less predictable: where the stars are scattered, which enemy
appears next, how far a spark flies. This page explains how to get random numbers from a `Random`,
and how a seed makes the same "random" numbers come out every time, when you want them to. For
values that vary randomly but smoothly, such as the height of rolling hills, see
[Noise](noise.md).

## Getting random numbers

Make a `Random` once, keep it as a field, and ask it for numbers whenever you need them:

```mojo
# In `create`, building the `random` field:
var random = Random()

# In `update`:
var x = self.random.float(-100, 100)  # a decimal number from -100 up to 100
var face = self.random.int(1, 7)  # a whole number from 1 to 6, like a die
if self.random.bool():  # True half of the time
    self.spawn_enemy()
```

| Call | Gives |
|---|---|
| `float()` | A decimal number from 0 up to, but never quite reaching, 1 |
| `float(low, high)` | A decimal number from `low` up to, but never quite reaching, `high` |
| `int(low, high)` | A whole number from `low` up to `high - 1` |
| `bool()` | `True` or `False`, each half of the time |

`int` leaves out `high` itself, as `range` does, so `random.int(0, len(items))` always picks a
valid position in a list: `items[random.int(0, len(items))]` is a random item.

Every call gives a new number, unrelated to the one before. To make something happen with a given
chance, compare `float()` with it: `if random.float() < 0.1:` is true one time in ten.

## Seeds

The numbers a `Random` gives aren't truly random: they are worked out, one after another, from a
starting number called the **seed**. The same seed always gives the same numbers in the same
order. `Random()` takes its seed from the clock, so the numbers differ every time the program
runs. `Random(seed)` takes one you choose, so the numbers come out the same every run:

```mojo
# In `create`: the same 60 stars, in the same places, every time the program runs.
var random = Random(7)
var stars = List[Point2D]()
for _ in range(60):
    stars.append(Point2D(random.float(-640, 640), random.float(0, 360)))
```

A fixed seed is useful when a random result should be repeatable: a level generated from a seed
the player can share, a test that must see the same numbers every time, or a picture you want to
draw again exactly.

## One `Random`, kept

Each call moves a `Random` on to its next number, so a `Random` can't be copied, only moved: a copy
would give the same numbers as the original. Keep one as a field and take every number from it.
With a fixed seed this matters most: a new `Random(7)` made each frame would give the same first
number every frame.
