"""Animation: values and sprites that move over time. `Tween` eases a number
between two values; `Animation` is a sequence of frames, and `Animator` is one
entity's playhead in it. Each keeps time on its own, off the run's clock. The
curves themselves, `Easing` and `ease`, are `math`'s.
"""
from .tween import Tween
from .animation import Animation
from .animator import Animator
