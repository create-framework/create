"""The user interface: `UI`, which keeps the widgets' state from frame to
frame, and `UILayer`, the handle a `with` block gets to draw widgets with.
"""
from .ui import UI
from .layer import UILayer, IDGuard
