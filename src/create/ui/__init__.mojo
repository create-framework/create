"""The user interface: widgets, such as `Button`, `Checkbox`, `Label`,
`Panel`, `Slider` and `TextField`, which are values a program keeps,
updates and draws with `canvas.draw`, and the traits they share (`Widget`,
`Hoverable`, `Clickable`); `UI`, which keeps widgets together and lays them
out with `Column`, `Row` and `Space`, reached through `WidgetHandle`s; and
`ColorScheme`, the colours they are drawn in.
"""
from .tree import UI, WidgetHandle
from .colors import ColorScheme, StateLayers, FocusRing
from .button import Button, ButtonVariant
from .checkbox import Checkbox
from .label import Label
from .layout import Column, Row, Space
from .panel import Panel
from .slider import Slider
from .widget import Clickable, Hoverable, Widget
from .text_field import TextField
