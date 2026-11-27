# Contributing to the library

The conventions Create's code follows, for anyone changing the library itself. Where a change
belongs, and what each package may import, is in [ARCHITECTURE.md](../ARCHITECTURE.md); a package
whose internals need explaining has a README beside its code.

## One public type per file

Every public type, struct or trait, has a file of its own, named after it in snake case:
`FontWeight` is in `text/font_weight.mojo`, `Shape` in `geometry/shape.mojo`. So searching for a
type's name finds its file, and the source matches the API reference, which has a page for each
type. Free functions and constants that belong to a type live in its file.

Internal types are exempt. One that serves a single public type lives in that type's file, such as
`JSON`'s `_Parser` in `json.mojo`; one shared by several lives in an `_`-prefixed file, such as the
render commands in `render/_command.mojo`.

## Verbs on values

A value type's verb method returns a new value and leaves the receiver as it was: `rect =
rect.translate(delta)`, `v.normalize()`, `line.split(t)`, `color.with_alpha(a)`. A shape, vector,
point, colour or matrix is never changed in place by a method; assign a field to change one. The
types that change in place are those that hold state over time, and their methods act on that state
(`tween.play()`, `table.sort(...)`): `Tween`, `Animator`, `Audio`, `UI`, `Random`, `Table`,
`PixelBuffer`, `Canvas` and `Context`.

## Locations, displacements and extents

Use `Point` for new locations, `Vector` for displacements and scalars for extents;
`canvas.rectangle(position: Point, width: Number, height: Number)` is the shape to copy. The reasons
are in [Points and
vectors](../docs/guide/math/points-and-vectors.md#locations-displacements-and-extents), and three
rules keep them working:

- Don't take a location as separate `x, y` scalars, not even as a convenience overload beside the
  `Point` one: a bare tuple already fills a `Point` parameter, and `(x, y)` keeps the pairs readable
  where a run of numbers doesn't.
- Don't give any type but `Point` an `@implicit` constructor from a tuple of two numbers. If two
  types could both be built from the same bare tuple, any function overloaded on those two types
  would be ambiguous when called with one. Locations are the values most worth writing as a tuple,
  so only `Point` gets the shorthand. A tuple that holds something else can't be confused with a
  point: `GradientStop` is built from a `(position, colour)` pair.
- Don't add `Point.__add__(Point)`. Adding two locations has no meaning, and refusing it is why
  `Point` is a separate type from `Vector`.

## Numbers

A public function takes a number as a `Number`, which accepts an `Int` as well as a `Float64`, so a
program never has to convert an `Int` variable to pass it. Read it with `Float64(n)`, once into a
local where the body uses it more than once. A number that may be left out is an `OptionalNumber`.
Return values and fields stay `Float64`, so what comes out of the library is an ordinary number. Two
kinds of parameter keep their own types: a count or an index is an `Int`, and a value whose kind of
number matters, such as `JSON`'s and `TableRow.set`'s, keeps its `Int` and `Float64` overloads.

## Printing

A public value type implements `Writable` and prints as it would be written in source:

- Positionally for the small maths types and `Color`: `Point(1.0, 2.0)`.
- By name for an `Int`-wrapping enum: `Easing.OUT_BOUNCE` (an unnamed value falls back to
  `Easing(99)`).
- In keyword form otherwise, labelled by the constructor's keywords where it has them
  (`Circle(position=Point(0.0, 0.0), radius=5.0)`) and by public field names where it doesn't
  (`Time`, `Tween`). Private fields are left out.

Resource handles (`Image`, `PixelBuffer`, `Sound`, `Audio`, `Playback`) and shared assets
(`Animation`) are not printable. A `Font` prints as it is loaded, `Font.load("path")` (with `,
italic_path="..."` when it has one). `JSON` prints as compact JSON text, its own source form;
`Table` and `TableRow` are containers and not printable.

## File paths

A relative path given to Create resolves against the source file that makes the call, as [File
paths](../docs/guide/basics/programs.md#file-paths) describes. A public function that takes a path
does three things to make that work:

- It is `@always_inline`, and passes the path to `_caller_relative` (in `_path.mojo`) directly from
  its own body. `call_location` counts exactly those two inlined calls, so the path resolves against
  the caller's file.
- It hands the absolute path to a `_`-named twin that does the work, such as `Image._load`.
- Library code calls the twin, never the public function: called from the library, the public
  function would resolve the path against the library's own file.

## Shared libraries

A binding opens its library with `load_library("libname", version)` from `_library.mojo`, where
`version` is the soname's version, and never with `_DLHandle("libname.so")`. `load_library` decides
the platform's file name and search path. It opens the versioned name because the runtime package
installs that one, so the library is found even on a system without `-devel` packages.

## Mojo

Create is on Mojo 1.2, and some older forms are gone or deprecated:

- Don't use `alias`; it is deprecated for `comptime`.
- Don't use `UnsafePointer`; it is deprecated for `Pointer`.
- Don't use `fn`; it is removed. Use `def`.
- Don't hold a raw `Pointer` to `Canvas` outside the guards and `UILayer`; use origin-tracked
  references.

## Tests

Name a test file with the `test_` prefix, or the runner won't find it. The rest is in
[tests/README.md](../tests/README.md).
