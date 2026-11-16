"""Generates the API reference into docs/reference, and stages the
documentation site's pages for Zensical, in build/docs/pages.

    pixi run reference     -> generate docs/reference only
    pixi run docs          -> generate, stage, then build the site into
                              build/docs/site
    pixi run docs-serve    -> generate, stage, then serve it with live reload

Nothing here is written by hand twice: the pages are this repo's own.

- docs/reference is the API reference, rendered from `mojo doc`'s JSON and
  committed, so it reads on GitHub too; CI fails when it differs from a fresh
  one. Each subpackage is a folder whose README.md lists exactly what its
  __init__.mojo imports, since that is the public surface (ARCHITECTURE.md):
  grouped into types, traits, functions and constants, each in the order it
  is imported. A type, trait or function has a page of its own, linked from
  the list; a constant is documented on the package's page. A type's members
  are grouped in turn: constants, fields, constructors (`__init__` and the
  static methods returning `Self`), methods, and special methods (the other
  dunders).
- The site's index.md is the README; guide/ is docs/guide and reference/ is
  docs/reference, each folder's README.md its index.md.

The reference's pages are generated, so its navigation is too: the site's
config is zensical.toml with the reference added to its nav, written to
build/docs/zensical.toml, which the docs tasks build from.

A link in the README or the guide is written for GitHub, relative to the
file. Rewritten for the site: one to another staged page stays relative; one
to an image is copied in at its repo path; anything else (an example, a
source file, CONTRIBUTING.md) points at GitHub, at the commit being built.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

import tomli_w

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "docs"
PAGES = OUT / "pages"
REFERENCE = ROOT / "docs" / "reference"
GITHUB = "https://github.com/create-framework/create"
IMAGES = {".png", ".gif", ".jpg", ".jpeg", ".svg", ".webp"}

# Methods every value type has, which say nothing about this one: its
# traits list says it is copyable, movable and printable.
BOILERPLATE = {
    "__copyinit__",
    "__moveinit__",
    "__del__",
    "__deinit__",
    "copy",
    "write_to",
    "write_repr_to",
}

# How the reference groups a package's names, by `mojo doc`'s kind, in
# this order: the index lists them so, and each package's page puts them
# under these headings, with each table's column named in the singular.
KIND_GROUPS = {
    "struct": ("Types", "Type"),
    "trait": ("Traits", "Trait"),
    "function": ("Functions", "Function"),
    "alias": ("Constants", "Constant"),
}


def main() -> None:
    packages = write_reference()
    if sys.argv[1:] == ["--reference"]:
        return
    commit = os.environ.get("GITHUB_SHA") or git("rev-parse", "HEAD")
    shutil.rmtree(PAGES, ignore_errors=True)
    PAGES.mkdir(parents=True)

    staged = {"README.md": "index.md"}
    for folder in ("guide", "reference"):
        for page in sorted((ROOT / "docs" / folder).rglob("*.md")):
            path = page.relative_to(ROOT / "docs")
            if page.name == "README.md":
                path = path.with_name("index.md")
            staged[str(page.relative_to(ROOT))] = str(path)
    for source, target in staged.items():
        text = (ROOT / source).read_text()
        write(PAGES / target, Links(source, target, staged, commit).rewrite(text))

    nav = [staged["docs/reference/README.md"]]
    for name, pages in packages:
        paths = [staged[f"docs/reference/{p}"] for p in pages]
        nav.append({f"create.{name}": paths})
    write_config(nav)


def write_reference() -> list:
    """Writes the API reference into docs/reference, afresh, and returns
    each package's name and pages, relative to it, in the order the root
    imports them."""
    doc = run_mojo_doc()
    packages = {p["name"]: p for p in doc["decl"]["packages"]}
    order = re.findall(
        r"^from create\.(\w+) import \*",
        (ROOT / "src/create/__init__.mojo").read_text(),
        re.M,
    )
    shutil.rmtree(REFERENCE, ignore_errors=True)
    index = ["# API reference\n", summary_and_description(doc["decl"])]
    written = []
    for name in order:
        package = Package(name, packages[name])
        pages = package.render()
        for path, text in pages.items():
            write(REFERENCE / path, text)
        written.append((name, list(pages)))
        index.append(package.index_entry())
    write(REFERENCE / "README.md", "\n".join(index))
    return written


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def write(target: Path, text: str) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text.rstrip() + "\n")


def write_config(reference: list) -> None:
    """The site's config: zensical.toml with the reference's pages added to
    its nav, its paths made relative to where the copy is written."""
    config = tomllib.loads((ROOT / "zensical.toml").read_text())
    project = config["project"]
    for key in ("docs_dir", "site_dir"):
        project[key] = os.path.relpath(ROOT / project[key], OUT)
    project["nav"].append({"API reference": reference})
    (OUT / "zensical.toml").write_text(tomli_w.dumps(config))


def run_mojo_doc() -> dict:
    output = OUT / "api.json"
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["mojo", "doc", "src/create", "-o", str(output)], cwd=ROOT, check=True
    )
    return json.loads(output.read_text())


# Links -----------------------------------------------------------------------

# A Markdown link or image target, and an HTML src/href attribute.
MARKDOWN_LINK = re.compile(r"(\]\()([^)\s]+)(\))")
HTML_LINK = re.compile(r"""((?:src|href)=")([^"]+)(")""")
FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"(`+).+?\1")


class Links:
    def __init__(self, source: str, target: str, staged: dict, commit: str):
        self.source = source
        self.target = target
        self.staged = staged
        self.commit = commit

    def rewrite(self, text: str) -> str:
        lines = []
        in_fence = False
        for line in text.split("\n"):
            if FENCE.match(line):
                in_fence = not in_fence
            elif not in_fence:
                line = self.rewrite_line(line)
            lines.append(line)
        return "\n".join(lines)

    def rewrite_line(self, line: str) -> str:
        # Code spans are left as written: `canvas.image(...)[0]` is no link.
        out, last = [], 0
        for span in INLINE_CODE.finditer(line):
            out.append(self.rewrite_prose(line[last : span.start()]))
            out.append(span.group(0))
            last = span.end()
        out.append(self.rewrite_prose(line[last:]))
        return "".join(out)

    def rewrite_prose(self, text: str) -> str:
        def replace(match: re.Match) -> str:
            return match.group(1) + self.url(match.group(2)) + match.group(3)

        return HTML_LINK.sub(replace, MARKDOWN_LINK.sub(replace, text))

    def url(self, link: str) -> str:
        if re.match(r"^[a-z]+:|^#", link):
            return link
        path, hash, anchor = link.partition("#")
        fragment = hash + anchor
        repo_path = os.path.normpath(
            os.path.join(os.path.dirname(self.source), path)
        )
        here = os.path.dirname(self.target) or "."
        if repo_path in self.staged:
            return os.path.relpath(self.staged[repo_path], here) + fragment
        source = ROOT / repo_path
        if not source.exists():
            sys.exit(f"{self.source}: link to a missing path: {link}")
        if source.suffix.lower() in IMAGES:
            copy = PAGES / repo_path
            copy.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, copy)
            return os.path.relpath(repo_path, here)
        kind = "tree" if source.is_dir() else "blob"
        return f"{GITHUB}/{kind}/{self.commit}/{repo_path}{fragment}"


# Reference -------------------------------------------------------------------


def summary_and_description(decl: dict) -> str:
    parts = [decl.get("summary", ""), decl.get("description", "")]
    return "\n\n".join(p.strip() for p in parts if p.strip()) + "\n"


def public_names(init: str) -> tuple:
    """The names an __init__.mojo imports from its own modules, and those it
    re-exports from the standard library, each in the order listed."""
    own, std = [], []
    for module, names in re.findall(
        r"^from\s+([.\w]+)\s+import\s+(\([^)]*\)|[^\n]+)", init, re.M
    ):
        for name in re.split(r"[,\s]+", re.sub(r"#.*", "", names.strip("()"))):
            if name and name != "as":
                bucket = own if module.startswith(".") else std
                if name not in bucket:
                    bucket.append(name)
    return own, std


class Package:
    def __init__(self, name: str, decl: dict):
        self.name = name
        self.decl = decl
        init = (ROOT / "src/create" / name / "__init__.mojo").read_text()
        self.names, self.reexports = public_names(init)
        self.declarations = {}
        for module in decl["modules"]:
            for kind in ("structs", "traits", "functions", "aliases"):
                for item in module.get(kind, []):
                    self.declarations[item["name"]] = item
        missing = [n for n in self.names if n not in self.declarations]
        if missing:
            sys.exit(f"create.{name}: no documentation for {missing}")

    def groups(self) -> dict:
        """The package's names grouped by kind, leaving out empty groups;
        each in the order __init__.mojo lists them."""
        groups = {label: [] for label, _ in KIND_GROUPS.values()}
        for name in self.names:
            groups[KIND_GROUPS[self.kind(name)][0]].append(name)
        return {label: names for label, names in groups.items() if names}

    def kind(self, name: str) -> str:
        return self.declarations[name]["kind"]

    def page(self, name: str) -> str:
        """Where a name is documented, relative to the reference: its own
        page, or for a constant, its heading on the package's page."""
        if self.kind(name) == "alias":
            return f"{self.name}/README.md#{name.lower()}"
        return f"{self.name}/{name.lower()}.md"

    def index_entry(self) -> str:
        lines = [
            f"- **{label}:** "
            + ", ".join(f"[`{n}`]({self.page(n)})" for n in names)
            for label, names in self.groups().items()
        ]
        return (
            f"## [`create.{self.name}`]({self.name}/README.md)\n\n"
            f"{summary_and_description(self.decl)}\n" + "\n".join(lines) + "\n"
        )

    def render(self) -> dict:
        """The package's pages by path, relative to the reference: its own
        page first, then one per type, trait and function, in the order
        __init__.mojo lists them."""
        out = [f"# create.{self.name}\n", summary_and_description(self.decl)]
        pages = {}
        for label, names in self.groups().items():
            out.append(f"## {label}\n")
            if label == "Constants":
                out.extend(render_constant(self.declarations[n]) for n in names)
                continue
            column = KIND_GROUPS[self.kind(names[0])][1]
            out.append(f"| {column} | Description |\n|---|---|")
            for name in names:
                item = self.declarations[name]
                link = os.path.relpath(self.page(name), self.name)
                out.append(f"| [`{name}`]({link}) | {table_cell(summary(item))} |")
                pages[self.page(name)] = render_declaration(item)
            out.append("")
        if self.reexports:
            names = ", ".join(f"`{n}`" for n in self.reexports)
            out.append(
                "## From the standard library\n\n"
                f"Re-exported from `std.math`, so a program has them without a "
                f"second import: {names}.\n"
            )
        return {f"{self.name}/README.md": "\n".join(out)} | pages


def summary(item: dict) -> str:
    """A declaration's one-line summary; a function's is the first one its
    public overloads have."""
    if item["kind"] != "function":
        return item.get("summary", "").strip()
    for overload in item["overloads"]:
        text = overload.get("summary", "").strip()
        if text and not is_internal(overload):
            return text
    return ""


def table_cell(text: str) -> str:
    return text.replace("|", "\\|")


def render_constant(item: dict) -> str:
    """A package's constant, under a heading of its own on the package's
    page."""
    name = item["name"]
    return "\n".join(
        [
            f"### `{name}`\n",
            code(f"comptime {name} = {item['value']}"),
            summary_and_description(item),
        ]
    )


def render_declaration(item: dict) -> str:
    """A type's, trait's or function's own page."""
    kind = item["kind"]
    name = item["name"]
    out = [f"# {name}\n"]
    if kind == "function":
        out.append(render_overloads(item["overloads"]))
        return "\n".join(out)

    out.append(code(item.get("signature") or f"{kind} {name}"))
    out.append(summary_and_description(item))
    traits = [
        t["name"]
        for t in item.get("parentTraits", [])
        if t["name"] not in ("AnyType", "UnknownDestructibility")
    ]
    if traits:
        out.append("Implements " + ", ".join(f"`{t}`" for t in traits) + ".\n")

    constants = item.get("aliases", [])
    if constants:
        out.append("## Constants\n")
        out.extend(member_line(f"{c['name']} = {c['value']}", c) for c in constants)
        out.append("")
    fields = [f for f in item.get("fields", []) if not f["name"].startswith("_")]
    if fields:
        out.append("## Fields\n")
        out.extend(member_line(f"{f['name']}: {f['type']}", f) for f in fields)
        out.append("")

    groups = member_groups(item)
    for label, functions in groups.items():
        if not functions:
            continue
        out.append(f"## {label}\n")
        for function in functions:
            method = function["name"]
            if method != "__init__":
                out.append(f"### `{method}`\n")
            out.append(render_overloads(function["overloads"]))
    return "\n".join(out)


def member_groups(item: dict) -> dict:
    """A type's public methods under the headings its page gives them:
    `__init__` and the static factories returning `Self` are constructors,
    the other dunders special methods, and the rest plain methods."""
    groups = {"Constructors": [], "Methods": [], "Special methods": []}
    for function in item.get("functions", []):
        method = function["name"]
        if method in BOILERPLATE:
            continue
        if method.startswith("_") and not method.startswith("__"):
            continue
        if all(is_internal(o) for o in function["overloads"]):
            continue
        if method == "__init__" or is_factory(function):
            groups["Constructors"].append(function)
        elif method.startswith("__"):
            groups["Special methods"].append(function)
        else:
            groups["Methods"].append(function)
    return groups


def is_factory(function: dict) -> bool:
    """A static method that builds the type, such as `Image.load`."""
    return all(
        o.get("isStatic") and o["signature"].rstrip().endswith("-> Self")
        for o in function["overloads"]
    )


def member_line(text: str, item: dict) -> str:
    doc = item.get("summary", "").strip()
    return f"- `{text}`" + (f": {doc}" if doc else "")


def render_overloads(overloads: list) -> str:
    """Overloads documented alike (as `overlaps`'s 49 are) are shown as one
    block of signatures followed by their shared documentation."""
    out = []
    groups = []
    for overload in overloads:
        if is_internal(overload):
            continue
        key = (overload["summary"], overload["description"])
        if groups and groups[-1][0] == key:
            groups[-1][1].append(overload)
        else:
            groups.append((key, [overload]))
    for _, group in groups:
        out.append(code("\n".join(signature(o) for o in group)))
        first = group[0]
        text = summary_and_description(first).strip()
        if text:
            out.append(text + "\n")
        arguments = [
            a for a in first["args"] if a.get("description", "").strip()
        ]
        if arguments:
            out.append("**Arguments**\n")
            out.extend(
                f"- `{a['name']}`: {a['description'].strip()}" for a in arguments
            )
            out.append("")
        returns = (first.get("returns") or {}).get("doc", "").strip()
        if returns:
            out.append(f"**Returns** {returns}\n")
        if first.get("raisesDoc", "").strip():
            out.append(f"**Raises** {first['raisesDoc'].strip()}\n")
    return "\n".join(out)


def is_internal(overload: dict) -> bool:
    """An internal constructor or method takes only `_`-prefixed keywords
    (ARCHITECTURE.md, "Imports and public surface")."""
    arguments = [a["name"] for a in overload["args"] if a["name"] != "self"]
    return bool(arguments) and all(a.startswith("_") for a in arguments)


def signature(overload: dict, width: int = 88) -> str:
    """The overload as it is declared: `mojo doc`'s signature leaves out
    `raises` and `@staticmethod`. A long one gets an argument per line, as
    `mojo format` would write it."""
    text = overload["signature"]
    start, end = argument_list(text)
    if overload["raises"] and end is not None:
        text = text[: end + 1] + " raises" + text[end + 1 :]
    if len(text) > width and end is not None:
        arguments = split_top_level(text[start + 1 : end])
        text = (
            text[: start + 1]
            + "\n"
            + "".join(f"    {a.strip()},\n" for a in arguments)
            + text[end:]
        )
    if overload["isStatic"]:
        text = "@staticmethod\n" + text
    return text


def argument_list(text: str) -> tuple:
    """Where the argument list's parentheses are, past any `[parameters]`."""
    depth, start = 0, None
    for i, char in enumerate(text):
        if char in "([":
            if depth == 0 and char == "(":
                start = i
            depth += 1
        elif char in ")]":
            depth -= 1
            if depth == 0 and start is not None:
                return start, i
    return None, None


def split_top_level(text: str) -> list:
    parts, depth, current = [], 0, ""
    for char in text:
        if char in "([{":
            depth += 1
        elif char in ")]}":
            depth -= 1
        if char == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += char
    if current.strip():
        parts.append(current)
    return parts


def code(text: str) -> str:
    return f"```mojo\n{text}\n```\n"


if __name__ == "__main__":
    main()
