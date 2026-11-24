@fieldwise_init
struct Scene(Equatable, ImplicitlyCopyable):
    """Which scene is showing. Each scene's `update` returns one: the scene
    to show next frame, its own to stay."""

    var value: Int

    comptime TITLE = Scene(0)
    comptime PLAY = Scene(1)
    comptime PAUSE = Scene(2)
    comptime OVER = Scene(3)

    def __eq__(self, other: Scene) -> Bool:
        return self.value == other.value
