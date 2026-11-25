"""A small game in four scenes: a title, the game, a pause menu drawn over
the game, and a game-over screen.

Each scene is a plain struct, not a `Program`, kept as a field of `App`.
`App.scene` says which one is showing. Each scene's `update` returns the
scene to show next, and `App.switch` is the one place that acts on a
change: it starts a new round, or passes the score on. State that outlasts
a scene, such as the best score, stays on `App` and goes to the scenes that
need it as an argument. "Multiple scenes" in the user guide's Programs page
says why there is no scene trait.

Move the mouse to catch the falling dots before the time runs out. Escape
pauses the game, and resumes it.
"""

from create import *
from scene import Scene
from title import Title
from play import Play
from pause import Pause
from over import Over


@fieldwise_init
struct App(Program):
    var scene: Scene
    var best: Int
    var title: Title
    var play: Play
    var pause: Pause
    var over: Over

    @staticmethod
    def create(mut context: Context, mut canvas: Canvas) raises -> App:
        return App(
            scene=Scene.TITLE,
            best=0,
            title=Title(),
            play=Play(),
            pause=Pause(),
            over=Over(),
        )

    def update(mut self, mut context: Context, mut canvas: Canvas) raises:
        var next: Scene
        if self.scene == Scene.TITLE:
            next = self.title.update(context, canvas, self.best)
        elif self.scene == Scene.PLAY:
            next = self.play.update(context, canvas)
        elif self.scene == Scene.PAUSE:
            self.play.draw(canvas)  # the game shows through, frozen
            next = self.pause.update(context, canvas)
        else:
            next = self.over.update(context, canvas)
        if next != self.scene:
            self.switch(next)

    def switch(mut self, next: Scene):
        """Every change of scene passes through here, so what happens on
        each change is in one place."""
        if next == Scene.PLAY and self.scene != Scene.PAUSE:
            self.play.enter()  # a new round, unless resuming
        if next == Scene.OVER:
            self.over.enter(self.play.score, self.best)
            self.best = max(self.best, self.play.score)
        self.scene = next


def main() raises:
    run[App]("Scenes", width=800, height=600)
