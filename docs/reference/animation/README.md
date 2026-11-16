# create.animation

Animation: values and sprites that move over time. `Tween` eases a number between two values; `Animation` is a sequence of frames, and `Animator` is one entity's playhead in it. Each keeps time on its own, off the run's clock. The curves themselves, `Easing` and `ease`, are `math`'s.

## Types

| Type | Description |
|---|---|
| [`Tween`](tween.md) | A value moving from one number to another over a fixed duration. |
| [`Animation`](animation.md) | An ordered sequence of frames and the rate they play at. |
| [`Animator`](animator.md) | The playhead over one `Animation`. |
