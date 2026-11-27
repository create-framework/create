# Releasing Create

For maintainers: how a version of Create is tagged, released on GitHub and published as a conda
package. Contributors don't need any of this.

A release is an annotated tag `vX.Y.Z` on a commit of `main` with a GitHub release. Pushing the tag
publishes the conda package to the prefix.dev channel
[create-framework/create](https://prefix.dev/channels/create-framework/create), the one
[create-cli](https://github.com/create-framework/create-cli) is on too. That channel is what the
README's `pixi add mojo create` installs from.

## The package recipe

[recipe/recipe.yaml](recipe/recipe.yaml) builds the package from the checkout. `pixi run
check-package` (CI's `linux-package`) builds it with rattler-build, in its own `package`
environment, and runs [recipe/test.mojo](recipe/test.mojo) against the installed package. It is the
only check that sees Create as installed rather than as source. Besides the library, the package
installs the [project template](examples/CONTRIBUTING.md#the-project-template) to
`share/create/template`, where create-cli's `create new` reads it, and its test checks it is there.

**A local build has a name of its own.** `pixi run check-package` names its package
`create-X.Y.Z-local_h…`, and only the release workflow, which sets `CREATE_RELEASE`, builds the name
it publishes, `create-X.Y.Z-h…`. pixi's cache keys packages by name, so a local build named like a
release would be installed in its place on the machine that built it.

**One Mojo minor version.** A `.mojoc` loads only on the compiler that built it, so the recipe
builds against `mojo-compiler` at the minor version `pixi.toml` pins, and the run requirement allows
that minor only (`upper_bound='x.x'`). So a change of Mojo version changes `pixi.toml` and `recipe/`
together.

## The release workflow

[.github/workflows/release.yml](.github/workflows/release.yml) runs on a pushed `v*` tag. It fails
unless the tag names `pixi.toml`'s version. Then it builds and tests the package on each platform
`pixi.toml` lists (linux-64, osx-arm64) with `pixi run check-package`, and uploads them all once
every build has passed, so a release reaches every platform or none. Then it runs
[docs.yml](.github/workflows/docs.yml) on `main`, so the site's `/latest/` shows the release: the
documentation follows the newest `vX.Y.Z` tag, not the package channel.

The upload authenticates through trusted publishing: the channel's settings on prefix.dev name this
repository and `release.yml` as a trusted publisher, so no token is stored. Renaming the workflow
file breaks that until the setting is updated.

## Steps

1. **Bump the version.** Change `version` in `pixi.toml` in a pull request, run the [macOS
   workflow](.github/workflows/macos.yml) on its branch (Actions → macOS → Run workflow), and merge
   it once both pass. CI builds the package on Linux only, and the release builds it on macOS too,
   so `macos-package` is what catches a package that builds on Linux alone.
2. **Tag the merged commit**, taken from the remote's `main` rather than whatever is checked out
   locally, and create the GitHub release:
   ```bash
   git fetch origin
   git tag -a vX.Y.Z -m "Create X.Y.Z" origin/main
   git push origin vX.Y.Z
   gh release create vX.Y.Z --title "Create X.Y.Z" --verify-tag --notes-file NOTES.md
   ```
3. **Watch the release workflow** (Actions → Release). When it passes, the package is on the channel
   and the Docs workflow is publishing the release's documentation. A failed run publishes nothing:
   fix the cause on `main`, then move the tag to the fixed commit and push it again (`git push
   --force origin vX.Y.Z`) to rerun it.
