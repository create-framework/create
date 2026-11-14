"""Builds the published documentation site, every version side by side.

    pixi run docs-site    -> build/docs/published, what CI deploys

The site has two versions, chosen by a selector in the header:

- latest/ is the newest release, built from its tag: what users install.
- main/ is main, built from this checkout, with a banner saying it is
  unreleased.

The root redirects to latest/, and its 404 page sends a path from before the
site was versioned (/guide/drawing/) to the same page in latest/.

Each version is built by its own tree, with its own pixi environment,
scripts/docs.py and zensical.toml, since the Mojo that writes the API
reference and the pages it stages change between releases. The release's
tree is a worktree of its tag, in build/docs/release. Versioning is added
here, to a copy of each tree's zensical.toml, so a release tagged before the
site was versioned needs nothing of its own.
"""

import json
import os
import re
import shutil
import subprocess
import tomllib
from collections.abc import Mapping
from pathlib import Path

import tomli_w

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "docs"
PUBLISHED = OUT / "published"
RELEASE_TREE = OUT / "release"
THEME = ROOT / "scripts" / "docs_theme"
SITE_URL = tomllib.loads((ROOT / "zensical.toml").read_text())["project"][
    "site_url"
]
LATEST = "latest"
MAIN = "main"

# The root page, sending a visitor on to latest/ with the rest of the URL.
REDIRECT = """<!doctype html>
<meta charset="utf-8">
<title>Redirecting</title>
<meta http-equiv="refresh" content="0; url=latest/">
<script>location.replace("latest/" + location.search + location.hash)</script>
<a href="latest/">Redirecting to the latest release's documentation.</a>
"""

# Put first in the root 404 page: a path in neither version is one from
# before the site was versioned, so it is looked up again in latest/.
UNVERSIONED = """<script>
  if (!/^\\/(latest|main)(\\/|$)/.test(location.pathname))
    location.replace("/latest" + location.pathname + location.search + location.hash)
</script>"""


def main() -> None:
    tag = latest_release()
    shutil.rmtree(PUBLISHED, ignore_errors=True)
    PUBLISHED.mkdir(parents=True)

    build(ROOT, MAIN, os.environ)
    checkout(tag)
    # docs.py links source files at $GITHUB_SHA when set, CI's commit of main.
    release_env = {k: v for k, v in os.environ.items() if k != "GITHUB_SHA"}
    build(RELEASE_TREE, LATEST, release_env)

    versions = [
        {"version": LATEST, "title": f"{tag} (latest)", "aliases": []},
        {"version": MAIN, "title": "main (unreleased)", "aliases": []},
    ]
    versions_json = json.dumps(versions, indent=2) + "\n"
    (PUBLISHED / "versions.json").write_text(versions_json)
    (PUBLISHED / "index.html").write_text(REDIRECT)
    not_found = (PUBLISHED / LATEST / "404.html").read_text()
    (PUBLISHED / "404.html").write_text(
        not_found.replace("<head>", "<head>\n" + UNVERSIONED, 1)
    )
    print(f"Published {tag} as {LATEST}/ and main as {MAIN}/ in {PUBLISHED}")


def latest_release() -> str:
    """The newest vX.Y.Z tag."""
    tags = git("tag", "--list", "v*", "--sort=-v:refname").split()
    releases = [t for t in tags if re.fullmatch(r"v\d+\.\d+\.\d+", t)]
    if not releases:
        raise SystemExit("no vX.Y.Z tag to publish as the latest release")
    return releases[0]


def checkout(tag: str) -> None:
    """Points the release worktree at the tag, kept between runs so its pixi
    environment is installed once."""
    if not (RELEASE_TREE / ".git").exists():
        shutil.rmtree(RELEASE_TREE, ignore_errors=True)
        git("worktree", "prune")
        git("worktree", "add", "--detach", str(RELEASE_TREE), tag)
    else:
        subprocess.run(
            ["git", "checkout", "--quiet", "--detach", tag],
            cwd=RELEASE_TREE,
            check=True,
        )


def build(tree: Path, version: str, env: Mapping[str, str]) -> None:
    """Builds the tree's site as `version` and copies it into the published
    site."""
    config = tomllib.loads((tree / "zensical.toml").read_text())
    project = config["project"]
    # The copy sits in build/docs, and its paths are relative to it.
    versioned = tree / "build" / "docs" / "zensical.versioned.toml"
    site = tree / project["site_dir"]
    for key in ("docs_dir", "site_dir"):
        project[key] = os.path.relpath(tree / project[key], versioned.parent)
    # Where the site is published is this checkout's say, not the tree's.
    project["site_url"] = SITE_URL
    project["theme"]["custom_dir"] = str(THEME)
    project.setdefault("extra", {})["version"] = {
        "provider": "mike",
        "default": LATEST,
    }
    versioned.parent.mkdir(parents=True, exist_ok=True)
    versioned.write_text(tomli_w.dumps(config))

    # MIKE_DOCS_VERSION is how mike tells Zensical it is building a version:
    # the site URL, and so the canonical links and sitemap, gain /version/.
    # The tree's pixi finds its own manifest, not the one running this script.
    env = {k: v for k, v in env.items() if not k.startswith("PIXI_")}
    env["MIKE_DOCS_VERSION"] = version
    pixi = ["pixi", "run", "--locked", "-e", "docs"]
    run(tree, env, *pixi, "python", "scripts/docs.py")
    build_site = ["zensical", "build", "--strict", "--clean", "-f"]
    run(tree, env, *pixi, *build_site, str(versioned))
    shutil.copytree(site, PUBLISHED / version)


def run(cwd: Path, env: Mapping[str, str], *command: str) -> None:
    subprocess.run(command, cwd=cwd, env=env, check=True)


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


if __name__ == "__main__":
    main()
