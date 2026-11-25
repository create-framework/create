# Tests

How Create's tests are written and run, and how the GPU backend is covered. Run them with `pixi run
test` (see [CONTRIBUTING.md](../CONTRIBUTING.md#building-and-testing)).

Tests use `std.testing.TestSuite`; each `tests/**/test_*.mojo` is a program:

```mojo
from std.testing import TestSuite, assert_equal

def test_thing_does_what_it_says() raises -> None:
    assert_equal(actual, expected)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
```

`pixi run test` runs files concurrently. It prints a failing file's full output, and one `PASS` line
for each passing file, with any `SKIP` lines that file printed indented beneath it. Each file is its
own process; namespace any scratch path under `/tmp` per file.

Fixtures are named relative to the test file, since Create resolves every path it is given that way
(`Image.load("../fixtures/test_2x2.png")` from `tests/image/`). A fixture read through the stdlib's
`open()` goes through `source_path`, which resolves the same way.

**Rendering is tested for real.** `run_headless` returns the last frame as an `Image`, and
`image.pixel(x, y)` reads it back: assert on pixels rather than judging by eye. It antialiases at
`MEDIUM` like `run`: a test pinning an edge pixel's exact colour passes
`antialiasing=Antialiasing.OFF`. `app/test_step.mojo` scripts `context.mouse` and calls `step`
directly for input-driven behaviour.

**GPU coverage, three tiers:**
- `render/test_gl_parity.mojo` renders one shape kind per frame through both backends and compares
  structurally (bounding box, centroid, ink coverage within tolerance, interior colour), not pixel
  by pixel. The rasterisers may legitimately differ at edges, and demanding exactness would rule out
  GPU antialiasing.
- `run_headless(..., backend=RenderBackend.GPU)` for what parity can't see across several commands
  in one frame: batch breaks, buffer growth and per-frame texture cleanup
  (`render/test_gl_batching.mojo`), and the GPU capture paths (`render/test_gl_capture.mojo`).
- Per pixel, where both backends are meant to compute the same colour:
  `render/test_gradient_fill.mojo` renders each gradient scene through both and compares every pixel
  at least two pixels from an edge, within one level per channel.

GL tests skip without a context. Their windows are `GLWindow(..., offscreen=True)` (as is
`run_headless`'s GPU path). They use SDL's offscreen driver, which is never shown and needs no
display, and get their context from EGL: the host's GPU driver where there is one, and Mesa's
software GL elsewhere. Mesa is enough to catch bugs in the library's own logic, but blind to
driver-specific ones. macOS has no EGL, so there the window is a hidden Cocoa one instead: still
never shown, but it needs a logged-in desktop session (a Mac reached only over SSH may skip). If GL
tests skip on a machine with a working driver, suspect the environment's libraries shadowing the
host driver's: `scripts/activate.sh` preloads the system libdrm for that reason. Window tests that
open a window pin `SDL_VIDEODRIVER=dummy` in their own `main`.

`app/test_smoke.mojo` is built on every commit and run by the suite. Its uncalled
`_windowed_entry_point` still gets type-checked, which gates the windowed path. Keep it minimal.
