## What and why

<!-- What the change does, and why. Link the issue it closes ("Closes #12"). For a change of the
public API, show a few lines of a program using it. -->

## Checklist

<!-- Tick what applies, and delete what doesn't. -->

- [ ] Each commit builds and has a [Conventional
  Commits](https://github.com/create-framework/create/blob/main/CONTRIBUTING.md#commit-messages)
  message, with `!` for a breaking change of the public API: the branch is rebased onto `main` as it
  is, not squashed.
- [ ] New behaviour has a test, and the tests the change can reach pass (`pixi run test <package>`).
- [ ] `pixi run build-examples` passes, if the public API changed.
- [ ] The user guide describes the new behaviour, and the examples use it where they should.
- [ ] `docs/reference` is regenerated (`pixi run reference`), if a docstring changed.
- [ ] The CPU and GPU backends draw the same, if drawing changed.
- [ ] The [macOS workflow](https://github.com/create-framework/create/actions/workflows/macos.yml)
  passes, if the change could behave differently there (windowing, GL, library search).
