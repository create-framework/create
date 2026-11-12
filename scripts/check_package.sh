#!/bin/sh
# Builds the conda package from this checkout with rattler-build, as
# modular-community's CI builds the published recipe, and runs its test:
# text rendered through the installed package. The only check that sees
# Create as installed rather than as source — a path baked in at compile
# time, say, is valid in the tree and gone in a package.
#
#   pixi run check-package
set -eu

out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT

CREATE_VERSION=$(sed -n 's/^version = "\(.*\)"$/\1/p' pixi.toml)
export CREATE_VERSION

rattler-build build \
    --recipe recipe/recipe.yaml \
    --channel conda-forge \
    --channel https://conda.modular.com/max \
    --output-dir "$out"
