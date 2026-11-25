from create.geometry import Rectangle
from create.image.image import Image
from create.math.point import Point
from create.math.vector import Vector
from .canvas import Canvas
from .drawable import Drawable


struct Picture(Copyable, Drawable, Movable):
    """An `Image` placed in the world, to draw with `canvas.draw`.

    An `Image` is an asset: the pixels, loaded once and shared, with no place
    of its own. A `Picture` is one place to draw it, centred on `position`
    and stretched to `width` by `height`, so `canvas.draw(picture)` draws
    what `canvas.image(image, position, width, height)` draws, tinted and
    faded by the style's `tint` and `opacity`. As a value it can be kept in a
    field and be one part of a `Drawable` of your own:

    ```mojo
    @fieldwise_init
    struct Card(Drawable):
        var frame: Rectangle
        var portrait: Picture

        def draw_to(self, mut canvas: Canvas):
            canvas.draw(self.frame)
            canvas.draw(self.portrait)
    ```

    Copying a `Picture` shares its image's pixels, as copying the `Image`
    does, so several pictures of one image cost nothing more.
    """

    var image: Image
    """The image drawn."""
    var position: Point
    """Where its centre is."""
    var width: Float64
    """How wide it is drawn, in units."""
    var height: Float64
    """How tall it is drawn, in units."""

    def __init__(out self, image: Image, position: Point):
        """The image at its own size: one unit per image pixel, as
        `canvas.image(image, position)` draws it."""
        self.width = Float64(image.width())
        self.height = Float64(image.height())
        self.image = image
        self.position = position

    def __init__(
        out self,
        image: Image,
        position: Point,
        width: Float64,
        height: Float64,
    ):
        """The image stretched to `width` by `height`."""
        self.image = image
        self.position = position
        self.width = width
        self.height = height

    def __init__(
        out self, image: Image, position: Point, width: Int, height: Int
    ):
        self = Self(image, position, Float64(width), Float64(height))

    def bounds(self) -> Rectangle:
        """The rectangle it covers: `width` by `height`, centred on
        `position`."""
        return Rectangle(self.position, self.width, self.height)

    def move_to(self, position: Point) -> Self:
        """The picture centred on `position` instead; this one is
        unchanged."""
        var moved = self.copy()
        moved.position = position
        return moved^

    def translate(self, delta: Vector) -> Self:
        """The picture moved by `delta`; this one is unchanged."""
        var moved = self.copy()
        moved.position = moved.position + delta
        return moved^

    def draw_to(self, mut canvas: Canvas):
        canvas.image(self.image, self.position, self.width, self.height)
