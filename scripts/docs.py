"""Stages the documentation site's pages for Zensical, in build/docs/pages.

    pixi run docs          -> stage, then build the site into build/docs/site
    pixi run docs-serve    -> stage, then serve it with live reload

Nothing here is written by hand twice: the pages are this repo's own.

- index.md is the README; guide/ is docs/, its README the guide's index.
- reference/ is the API reference, one page per subpackage, rendered from
  `mojo doc`'s JSON. A page lists exactly what the subpackage's __init__.mojo
  imports, in that order, since that is the public surface (ARCHITECTURE.md).

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
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "docs"
PAGES = OUT / "pages"
GITHUB = "https://github.com/create-framework/create"
IMAGES = {".png", ".gif", ".jpg", ".jpeg", ".svg", ".webp"}

# Methods every value type has, which say nothing about this one: its
# traits list says it is copyable, movable and printable.
BOILERPLATE = {
    "__copyinit__",
    "__moveinit__",
    "__del__",
    "copy",
    "write_to",
    "write_repr_to",
}


def main() -> None:
    commit = os.environ.get("GITHUB_SHA") or git("rev-parse", "HEAD")
    shutil.rmtree(PAGES, ignore_errors=True)
    PAGES.mkdir(parents=True)

    staged = {"README.md": "index.md"}
    for page in sorted((ROOT / "docs").glob("*.md")):
        name = "index.md" if page.name == "README.md" else page.name
        staged[f"docs/{page.name}"] = f"guide/{name}"
    for source, target in staged.items():
        text = (ROOT / source).read_text()
        write(target, Links(source, target, staged, commit).rewrite(text))

    doc = run_mojo_doc()
    packages = {p["name"]: p for p in doc["decl"]["packages"]}
    order = re.findall(
        r"^from create\.(\w+) import \*",
        (ROOT / "src/create/__init__.mojo").read_text(),
        re.M,
    )
    index = ["# API reference\n", summary_and_description(doc["decl"])]
    for name in order:
        page = Package(name, packages[name])
        write(f"reference/{name}.md", page.render())
        index.append(page.index_entry())
    write("reference/index.md", "\n".join(index))


def git(*args: str) -> str:
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def write(path: str, text: str) -> None:
    target = PAGES / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text.rstrip() + "\n")


def run_mojo_doc() -> dict:
    output = OUT / "api.json"
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

    def index_entry(self) -> str:
        names = ", ".join(
            f"[`{n}`]({self.name}.md#{anchor(n)})" for n in self.names
        )
        return (
            f"## [`create.{self.name}`]({self.name}.md)\n\n"
            f"{summary_and_description(self.decl)}\n{names}\n"
        )

    def render(self) -> str:
        out = [f"# create.{self.name}\n", summary_and_description(self.decl)]
        for name in self.names:
            out.append(render_declaration(self.declarations[name]))
        if self.reexports:
            names = ", ".join(f"`{n}`" for n in self.reexports)
            out.append(
                "## From the standard library\n\n"
                f"Re-exported from `std.math`, so a program has them without a "
                f"second import: {names}.\n"
            )
        return "\n".join(out)


def anchor(name: str) -> str:
    """A heading's id: `Canvas.rectangle` is `#canvas.rectangle`, and a
    dunder loses its underscores, which Markdown would read as bold."""
    return name.strip("_").lower()


def render_declaration(item: dict) -> str:
    kind = item["kind"]
    name = item["name"]
    out = [f"## `{name}` {{ #{anchor(name)} }}\n"]
    if kind == "function":
        out.append(render_overloads(item["overloads"]))
        return "\n".join(out)
    if kind == "alias":
        out.append(code(f"comptime {name} = {item['value']}"))
        out.append(summary_and_description(item))
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
        out.append("### Constants\n")
        out.extend(member_line(f"{c['name']} = {c['value']}", c) for c in constants)
        out.append("")
    fields = [f for f in item.get("fields", []) if not f["name"].startswith("_")]
    if fields:
        out.append("### Fields\n")
        out.extend(member_line(f"{f['name']}: {f['type']}", f) for f in fields)
        out.append("")

    for function in item.get("functions", []):
        method = function["name"]
        if method in BOILERPLATE:
            continue
        if method.startswith("_") and not method.startswith("__"):
            continue
        if all(is_internal(o) for o in function["overloads"]):
            continue
        label = "Constructors" if method == "__init__" else f"`{method}`"
        out.append(f"### {label} {{ #{anchor(name)}.{anchor(method)} }}\n")
        out.append(render_overloads(function["overloads"]))
    return "\n".join(out)


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
