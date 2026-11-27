#!/bin/sh
# Builds the conda package from this checkout with rattler-build, as the
# release workflow publishes it, and runs its test: text rendered through the
# installed package. The only check that sees Create as installed rather than
# as source — a path baked in at compile time, say, is valid in the tree and
# gone in a package.
#
#   pixi run check-package                # build and test, then discard
#   pixi run check-package build/package  # keep it in build/package/<platform>/
set -eu

if [ $# -gt 0 ]; then
    out=$1
    # rattler-build creates the directory but not its parents.
    mkdir -p "$out"
else
    out=$(mktemp -d)
    trap 'rm -rf "$out"' EXIT
fi

CREATE_VERSION=$(sed -n 's/^version = "\(.*\)"$/\1/p' pixi.toml)
export CREATE_VERSION
# A package built to check it is named `create-X.Y.Z-local_h…`, never the
# name the release publishes, or pixi's cache would serve it in place of the
# published package of the same version. The release workflow sets
# CREATE_RELEASE for the packages it uploads.
if [ -z "${CREATE_RELEASE:-}" ]; then
    CREATE_BUILD_LABEL=local_
    export CREATE_BUILD_LABEL
fi

rattler-build build \
    --recipe recipe/recipe.yaml \
    --channel conda-forge \
    --channel https://conda.modular.com/max \
    --output-dir "$out"
