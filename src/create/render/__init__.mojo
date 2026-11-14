"""Drawing: `Canvas` and its `with`-block guards, `Style`, `Camera`, and the
settings that shape a frame (`Antialiasing`, `Autoscale`, `Align`,
`StrokeCap`, `StrokeDash`, `StrokeAlign`, `RenderBackend`).
"""
from .render_backend import RenderBackend
from .antialiasing import Antialiasing
from .align import Align
from .stroke_align import StrokeAlign
from .stroke_cap import StrokeCap
from .stroke_dash import StrokeDash
from .autoscale import Autoscale
from .style import Style
from .camera import Camera
from .canvas import (
    Canvas,
    StyleGuard as StyleGuard,
    TransformGuard as TransformGuard,
    OverlayGuard as OverlayGuard,
    ClipGuard as ClipGuard,
)
