"""The user interface: widgets, such as `Button`, `Checkbox`, `Label`,
`Panel`, `Slider` and `TextField`, which are values a program keeps,
updates and draws with `canvas.draw`, and the traits they share (`Widget`,
`Hoverable`, `Clickable`); `UI`, which keeps the widgets' state from frame
to frame, `UILayer`, the handle a `with` block gets to draw widgets with,
and `ColorScheme`, the colours they are drawn in.
"""
from .ui import UI
from .layer import (
    UILayer,
    IDGuard,
    DisabledGuard,
    ColorsGuard,
    WidgetStyleGuard,
    PanelGuard,
    LayoutGuard,
)
from .colors import ColorScheme, StateLayers, FocusRing
from .button import Button, ButtonVariant
from .checkbox import Checkbox
from .label import Label
from .panel import Panel
from .slider import Slider
from .widget import Clickable, Hoverable, Widget
from .text_field import TextEditor, TextField
from .tree import WidgetHandle
