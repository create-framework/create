"""What every replay of a frame reads beside its commands: the text
renderer, with its glyph cache, and the images the commands name by id.

Kept apart from the command buffer and from either replay: commands are
recorded against it (`intern_image` at record time, text measured through
it), the CPU replay and `GLRenderer` both draw from it, and it outlives the
frame, as fonts and images have to.
"""

from std.memory import ArcPointer

from ._interned_image import IMAGE_KEEP_FRAMES, _InternedImage
from ._text import TextRenderer


struct Resources(Movable):
    """The text renderer and the interned images, shared by every replay."""

    var text: ArcPointer[TextRenderer]
    """The glyph cache and layout, behind a shared pointer so a measurement
    (`canvas.text_width`) can fill the cache through a read-only canvas."""
    var images: Dict[Int, _InternedImage]
    """Interned image copies by backend image id, the id a command
    carries. One per image version rendered, dropped by `expire_images`."""
    var interned_ids: Dict[Int, Int]
    """`Image._id` to the backend id of its most recently interned copy."""
    var next_image: Int
    var frame: Int
    """Frames presented so far: the clock `_InternedImage.last_used` is read
    against."""

    def __init__(out self) raises:
        self.text = ArcPointer(TextRenderer())
        self.images = Dict[Int, _InternedImage]()
        self.interned_ids = Dict[Int, Int]()
        self.next_image = 1
        self.frame = 0

    def intern_image(
        mut self,
        source: Int,
        pixels: ArcPointer[List[UInt8]],
        width: Int,
        height: Int,
    ) -> Int:
        """Return a backend id for `pixels`, the `width` x `height` RGBA
        pixels of image `source`.

        Keeps a share of the pixels on first sight of an image and returns
        the cached id thereafter. Nothing is copied: an image never changes,
        so its identity alone says the share is current, and the share keeps
        the pixels alive for a command replayed after the image itself is
        gone. `source` must be stable for the life of the image — an
        `Image`'s identity, not its pixel address, which could be reused
        after a free.

        Called while recording rather than at replay, which is what keeps a
        borrow of caller-owned memory out of the command buffer.
        """
        try:
            if source in self.interned_ids:
                var id = self.interned_ids[source]
                self.images[id].last_used = self.frame
                return id
        except:
            pass  # unreachable: `interned_ids` names only interned ids
        var id = self.next_image
        self.next_image += 1
        self.images[id] = _InternedImage(
            pixels, width, height, source, self.frame
        )
        self.interned_ids[source] = id
        return id

    def expire_images(mut self) raises -> List[Int]:
        """Advance the frame clock and drop every image no render has used
        for `IMAGE_KEEP_FRAMES` frames, returning their ids so a GPU present
        can delete their textures. Runs after the frame has been replayed
        and captured, so nothing still refers to what it drops."""
        self.frame += 1
        var expired = List[Int]()
        for id in self.images:
            if self.frame - self.images[id].last_used > IMAGE_KEEP_FRAMES:
                expired.append(id)
        for id in expired:
            var image = self.images.pop(id)
            if (
                image.source in self.interned_ids
                and self.interned_ids[image.source] == id
            ):
                _ = self.interned_ids.pop(image.source)
        return expired^
