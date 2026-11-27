# Mojo

Create programs are written in [Mojo](https://www.modular.com/mojo), a language that reads much like
Python but is compiled, so it runs fast. You don't need to know much of it to write a sketch or a
game, but the guide's examples use a handful of its features without stopping to explain them. This
page explains those, for readers new to Mojo. It isn't a full course: the [Mojo
manual](https://docs.modular.com/mojo/manual/) covers the language completely.

## Variables and numbers

`var` introduces a variable. Mojo works out its type from the value, or you can write the type after
a colon. Once a variable exists, assigning to it again needs no `var`:

```mojo
var score = 0  # an Int
var speed: Float64 = 2.5  # a Float64, written out
score = score + 10  # no `var`: the variable already exists
```

There are two kinds of number you will meet everywhere:

- **`Int`** is a whole number, such as a score, a count or a position in a list.
- **`Float64`** is a number with a decimal point, such as a position, a size, an angle or a time.
  Create measures almost everything in `Float64`.

**Create takes either kind.** Every number you hand to Create, such as a radius, a thickness or
`lerp`'s `t`, can be an `Int` or a `Float64`, whether written straight into the code (`40`, `0.5`)
or held in a variable. So `canvas.circle((0, 0), 40)` and `canvas.circle((0, 0), i * 5)` both work
as they are. What Create gives back, such as `canvas.width()`, is a `Float64`.

Your own sums are different: Mojo never turns one kind of number into the other by itself once it is
held in a variable, so an `Int` variable in a sum with a `Float64` has to be converted, with
`Float64(count)`. A number written straight into the code becomes whichever kind the sum needs.

```mojo
# In `update`: a ring of `count` dots, `count` being an Int.
for i in range(count):
    var angle = TAU * Float64(i) / Float64(count)  # Int to Float64 for the sum
    canvas.circle(Point(0, 0) + Vector.from_angle(angle, 150), i + 4)  # an Int radius
```

A function of your own can take either kind too, by asking for a `Number`, and read it as a
`Float64` with `Float64(n)`.

Text is a `String`, written in double quotes. `+` joins strings, and `String(value)` turns a value
into text, which is how a number reaches the screen: `canvas.text("Score: " + String(score), (0,
0))`.

## Functions and `mut`

`def` defines a function, with each argument's type after a colon and the type of the result after
`->`. A function that is part of a struct is a **method**, and its first argument, `self`, is the
value it was called on:

```mojo
def distance_to_mouse(position: Point, context: Context) -> Float64:
    return position.distance(context.mouse.position)
```

**A function can't change its arguments, unless they are marked `mut`.** By default, an argument is
only lent to the function to read. `mut` lends it for changing, and the changes reach the caller's
value. That is why `update` is written `update(mut self, mut context: Context, mut canvas: Canvas)`:
it changes the program's own fields through `self`, draws on the `canvas` and may change the run's
settings through the `context`. A helper that only reads its arguments leaves `mut` out.

## Structs

A **struct** is a type of your own, made of named **fields** and the methods that work on them.
Every Create program is one:

```mojo
@fieldwise_init
struct Game(Program):
    var player: Point
    var score: Int

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> Self:
        return Self(Point(0, 0), 0)

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        self.score += 1
```

- **`@fieldwise_init`** writes the struct's constructor for you, taking one value for each field, in
  the order the fields are listed: `Game(Point(0, 0), 0)`.
- **`(Program)`** after the name says that the struct conforms to the `Program` **trait**, a promise
  that it has the methods `Program` asks for, `create` and `update`. `run` accepts only a type that
  keeps that promise. Create has a few other traits, such as `Drawable` for a type that
  [`canvas.draw`](../drawing/canvas.md#your-own-types) can draw.
- **`@staticmethod`** marks a method that is called on the type itself rather than on a value of it.
  `create` is one because its job is to build the program, so there is no program yet to call it on.
- **`Self`**, inside a struct, is the struct's own type, so `Self(...)` above is `Game(...)`.

A struct can also hold constants, and so can a file outside any struct. `comptime` introduces one: a
value fixed when the program is compiled, such as `comptime FALL_SPEED = 320.0`, which gives a
number a name that says what it means.

## Lists and tuples

A **`List`** holds any number of values of one type, in order. Write one with square brackets, or
start an empty one and `append` to it:

```mojo
var names: List[String] = ["Ada", "Grace"]
names.append("Alan")
var stars = List[Point]()  # empty, to fill later
for name in names:
    print(name)
```

`len(names)` is how many values the list holds, and `names[0]` is the first, as positions count
from 0. `for i in range(10)` counts `i` from 0 up to 9, which is the usual way to repeat something a
number of times.

A **tuple** is a few values written together in round brackets, such as `(10, 20)`. Wherever Create
expects a `Point`, a pair of numbers is read as one, which is why `canvas.circle((0, 0), 20)` needs
no `Point(...)` around the position (see [Points and
vectors](../math/points-and-vectors.md#writing-them)).

## Optional values

Some questions have no answer. `Key.from_name("jmup")` is given a name that isn't a key, and
`table.find_row_index("name", "Zoe")` looks for a row that isn't there. Calls like these give an
**`Optional`**: a box that either holds a value or is empty, which Mojo writes `None`. Before using
what is inside, check that there is something:

```mojo
# In `create`, with a key's name, `setting`, read from a settings file:
var jump_key = Key.SPACE
var key = Key.from_name(setting)
if key:  # true when the box holds a key
    jump_key = key.value()  # take the key out of the box
else:
    print("Not a key:", setting)
```

`key.value()` takes the value out. On an empty box it is an error that stops the program, so call it
only after checking. When there is a sensible fallback, `or_else` does both at once: it gives the
value if there is one and the fallback otherwise, as in `Key.from_name(setting).or_else(Key.SPACE)`.

## Errors

Things can go wrong while a program runs: a file to load may not be there, or a JSON field may be
missing. A function **raises an error** to say so, and stops there. A function that may raise one
says so in its definition with `raises`, as Create's loaders do. Any function that calls one must
either be marked `raises` too, passing the error on to its own caller, or catch it. That is why
`create`, `update` and `main` are all marked `raises`: an error inside them is passed on, and ends
the run (see [When something goes wrong](programs.md#when-something-goes-wrong)).

To deal with an error yourself, put the call that may raise inside `try`, and what to do instead
inside `except`:

```mojo
# In `create`: load the saved game, or start a new one the first time.
var save: JSON
try:
    save = JSON.load("save.json")
except error:
    print("No save yet:", error)
    save = JSON.object()
```

`except error:` names the error, to print it or show it; plain `except:` catches it without a name.
The `var save: JSON` before the `try` declares the variable without a value yet, since it gets its
value in one of the two branches.

## Moving and copying values

Most of Create's values are copied freely: assigning a point, a colour, a shape or an image to a new
variable gives a copy, and copying an asset such as an image or a font is cheap, since the copies
share their data (see [Assets and playheads](programs.md#assets-and-playheads)).

A few types aren't copied silently, because copying them could be costly or wrong: a `List`, a
`Table` and a `JSON` document can be large, and a `Random` must never be copied at all (see [One
`Random`, kept](../math/random-numbers.md#one-random-kept)). To hand one of these to a function or a
constructor, **move** it, by writing `^` after its name:

```mojo
# In `create`:
var table = Table.load("scores.csv")
table.sort("score", descending=True)
return Scores(table^)  # the table moves into the program
```

After a move, the value lives in its new place, and the old name can no longer be used. To keep
using it as well, pass a copy instead, with `table.copy()`. You don't need to remember which types
need this: when one is needed, the compiler stops with an error saying that the value can't be
copied implicitly, and adding `^` or `.copy()` fixes it.

## References

A loop over a list or a table normally gives each item for reading only. `ref` makes the name a
**reference**: another name for the item itself, where it lives, so a change made through it changes
the item in the table:

```mojo
# With a `Table` named `table`:
for ref row in table.rows():
    row.set("score", row.int("score") + 10)  # changes the table's own row
```

`ref` works outside loops too: `ref row = table.add_row()` names the new row in the table, so it can
be filled in where it is.

## Imports

`from create import *` brings in everything Create offers, which is all most programs need. Create
also includes the common maths functions, such as `sqrt`, `sin` and `cos`, so they need no import of
their own. Anything else from Mojo's standard library is imported from `std`, such as `from
std.pathlib import cwd` (see [File paths](programs.md#file-paths)).

Instead of the star, a program can import each name it uses from the subpackage that defines it. The
[API reference](../../reference/README.md) lists every name under its subpackage:

```mojo
from create.app import Program, Context, run
from create.render import Canvas
from create.color import Color
from create.math import Point, sin
```

The two differ in convenience and clarity, not speed: a program compiles only what it uses, so
neither builds faster.

- **`from create import *`** needs no upkeep: every name in this guide works as written, and a name
  you start using is already there. But it brings in over a hundred names at once. A reader can't
  tell where a name comes from, and a name of Create's, such as `map` or `Key`, can clash with one
  from another library imported the same way.
- **Named imports** show where every name comes from and bring in only the ones specified. But the
  list has to be kept up to date, and each new name used is an error until it is added.

A subpackage star, such as `from create.render import *`, is not a middle way. Each subpackage
exports only the names it defines, so `from create.render import *` brings in `Canvas` but not the
`Color` and `Point` that its methods take.
