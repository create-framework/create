# Releasing Create

For maintainers: how a version of Create is tagged, released on GitHub and published as a conda
package. Contributors don't need any of this.

A release is an annotated tag `vX.Y.Z` on a commit of `main` with a GitHub release, then the
package on the [modular-community](https://github.com/modular/modular-community) conda channel,
which is what the README's `pixi add mojo create` installs.

## The package recipe

[recipe/recipe.yaml](recipe/recipe.yaml) builds the package from the checkout.
`pixi run check-package` (CI's `linux-package`) builds it with rattler-build, in its own `package`
environment at the version modular-community's CI uses, and runs
[recipe/test.mojo](recipe/test.mojo) against the installed package. It is the only check that sees
Create as installed rather than as source.

The published recipe, `recipes/create/` in modular-community, is the same file with `context` and
`source` pointing at the release tarball. Change the build script, requirements and test here
first, then carry them over at the next release.

**One Mojo minor version.** A `.mojoc` loads only on the compiler that built it, so the recipe
builds against `mojo-compiler` at the minor version `pixi.toml` pins, and the run requirement
allows that minor only (`upper_bound='x.x'`). Moving Mojo moves `pixi.toml`, `recipe/` and the
published recipe together.

## Steps

1. **Bump the version.** Change `version` in `pixi.toml` in a pull request and merge it.
2. **Tag what merged**, by the remote's `main` rather than whatever is checked out, and create the
   GitHub release:
   ```bash
   git fetch origin
   git tag -a vX.Y.Z -m "Create X.Y.Z" origin/main
   git push origin vX.Y.Z
   gh release create vX.Y.Z --title "Create X.Y.Z" --verify-tag --notes-file NOTES.md
   ```
3. **Update the published recipe.** In a fork of modular-community, branched from upstream's
   `main`, update `recipes/create/recipe.yaml`: `version`, the tarball's `sha256`
   (`curl -sL https://github.com/create-framework/create/archive/refs/tags/vX.Y.Z.tar.gz | sha256sum`),
   build `number: 0`, and any change from `recipe/`. Copy `recipe/test.mojo` over too.
4. **Check it on the fork first.** Upstream's build job runs only on a pull request labelled
   `OK to test`, which its maintainers add, so a manual run skips it. Instead, push upstream's
   `main` to the fork as a branch, open a pull request into that branch, and give it the label.
   Delete that branch once the build passes on all three platforms.
5. **Open the pull request** to `modular/modular-community`, titled `Update create to X.Y.Z` (it
   is squash-merged under its title), with the checklist from its template filled in.
