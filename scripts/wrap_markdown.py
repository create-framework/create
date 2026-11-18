"""Wraps the prose of Create's Markdown at 100 columns.

    python scripts/wrap_markdown.py            -> rewrite every tracked page
    python scripts/wrap_markdown.py --check    -> list the pages it would change
    python scripts/wrap_markdown.py --staged   -> wrap what is staged (pre-commit)
    python scripts/wrap_markdown.py FILE...    -> rewrite these files

Each paragraph and list item is refilled: its words are joined and broken again
as late as fits, never inside a word, so a word longer than the line stays
whole on a line of its own. A word that would read as Markdown syntax at the
start of a line (`-`, `1.`, `#`, `>`, a fence, ...) is kept on the line before.

Everything else is left exactly as written: fenced code, tables, HTML, headings,
link definitions, rules, and any paragraph with a hard line break. A blockquote's
contents are wrapped inside its `> `.

`--staged` is the pre-commit hook's: it wraps the staged version of each staged
page and stages the result, and wraps the working file too when it has no
unstaged edits, so a partly staged page never gains or loses a hunk.
"""

import re
import subprocess
import sys

WIDTH = 100

# Generated (docs/reference, from the docstrings) or vendored (agent skills):
# not written by hand here, so not wrapped.
EXCLUDED = ("docs/reference/", ".agents/", ".claude/")

_FENCE = re.compile(r"^\s*(`{3,}|~{3,})")
_LIST_ITEM = re.compile(r"^(\s*)([-+*]|\d{1,9}[.)])( +)(\S.*)$")
_RULE = re.compile(r"^\s*([-*_])(\s*\1){2,}\s*$")
_LINK_DEFINITION = re.compile(r"^\s*\[[^\]]+\]:")
_SETEXT = re.compile(r"^\s*(=+|-+)\s*$")
# A word that, starting a line, would begin a list, heading, quote, fence,
# table or HTML block instead of continuing the paragraph.
_NO_LINE_START = re.compile(r"^([-+*]|\d{1,9}[.)]|#{1,6}|=+|-+)$|^(>|`{3}|~{3}|\||<)")


def _starts_block(line: str) -> bool:
    """Whether `line` ends the paragraph before it."""
    stripped = line.strip()
    return (
        not stripped
        or _FENCE.match(line) is not None
        or _LIST_ITEM.match(line) is not None
        or stripped.startswith(("#", ">", "|"))
        or _RULE.match(line) is not None
        or _LINK_DEFINITION.match(line) is not None
        or _SETEXT.match(line) is not None
    )


def _fill(words: list[str], first: str, rest: str, width: int) -> list[str]:
    tokens: list[str] = []
    for word in words:
        if tokens and _NO_LINE_START.search(word):
            tokens[-1] += " " + word
        else:
            tokens.append(word)
    lines: list[str] = []
    line = first
    has_word = False
    for token in tokens:
        if has_word and len(line) + 1 + len(token) > width:
            lines.append(line)
            line, has_word = rest, False
        line += (" " if has_word else "") + token
        has_word = True
    lines.append(line)
    return lines


def wrap(lines: list[str], width: int = WIDTH) -> list[str]:
    """Returns `lines`, a page without line endings, with its prose refilled."""
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        fence = _FENCE.match(line)
        if fence:
            marker = fence.group(1)
            out.append(line)
            i += 1
            while i < len(lines):
                out.append(lines[i])
                closing = lines[i].strip()
                i += 1
                if closing.startswith(marker[0] * len(marker)) and not closing.strip(marker[0]):
                    break
            continue

        if stripped.startswith("<"):
            while i < len(lines) and lines[i].strip():
                out.append(lines[i])
                i += 1
            continue

        if stripped.startswith(">"):
            indent = line[: len(line) - len(line.lstrip())]
            quoted: list[str] = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                inner = lines[i].strip()[1:]
                quoted.append(inner[1:] if inner.startswith(" ") else inner)
                i += 1
            for inner in wrap(quoted, width - len(indent) - 2):
                out.append(indent + (("> " + inner) if inner else ">"))
            continue

        if (
            not stripped
            or stripped.startswith(("#", "|"))
            or _RULE.match(line)
            or _LINK_DEFINITION.match(line)
            or _SETEXT.match(line)
        ):
            out.append(line)
            i += 1
            continue

        item = _LIST_ITEM.match(line)
        if item:
            first = item.group(1) + item.group(2) + item.group(3)
            rest = " " * len(first)
        else:
            first = rest = line[: len(line) - len(line.lstrip())]
        start = i
        i += 1
        while i < len(lines) and not _starts_block(lines[i]):
            i += 1
        block = lines[start:i]
        if any(b.endswith(("  ", "\\")) for b in block):
            out.extend(block)  # a hard line break: written as meant
            continue
        words = " ".join(b.strip() for b in block).split()
        if item:
            words = words[1:]  # the marker, already in `first`
        out.extend(_fill(words, first, rest, width))
    return out


def wrap_text(text: str) -> str:
    lines = text.split("\n")
    trailing = lines[-1] == ""
    if trailing:
        lines.pop()
    result = "\n".join(wrap(lines))
    return result + "\n" if trailing else result


def _git(*args: str, data: bytes | None = None) -> bytes:
    return subprocess.run(["git", *args], input=data, capture_output=True, check=True).stdout


def _wrapped(path: str) -> bool:
    return path.endswith(".md") and not path.startswith(EXCLUDED)


def tracked_pages() -> list[str]:
    return [p for p in _git("ls-files", "-z", "*.md").decode().split("\0") if p and _wrapped(p)]


def wrap_staged() -> list[str]:
    """Wraps each staged page in the index, and its working file when that
    matches the index. Returns the pages it changed."""
    changed = []
    staged = _git("diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR").decode()
    for path in filter(None, staged.split("\0")):
        if not _wrapped(path):
            continue
        before = _git("show", f":{path}").decode()
        after = wrap_text(before)
        if after == before:
            continue
        mode = _git("ls-files", "-s", "--", path).decode().split()[0]
        blob = _git("hash-object", "-w", "--stdin", data=after.encode()).decode().strip()
        _git("update-index", "--cacheinfo", f"{mode},{blob},{path}")
        try:
            with open(path, encoding="utf-8", newline="") as f:
                untouched = f.read() == before
        except FileNotFoundError:
            untouched = False
        if untouched:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(after)
        changed.append(path)
    return changed


def main(argv: list[str]) -> int:
    if argv == ["--staged"]:
        for path in wrap_staged():
            print(f"Wrapped {path}")
        return 0
    check = "--check" in argv
    paths = [a for a in argv if a != "--check"] or tracked_pages()
    unwrapped = []
    for path in paths:
        with open(path, encoding="utf-8", newline="") as f:
            before = f.read()
        after = wrap_text(before)
        if after == before:
            continue
        unwrapped.append(path)
        if not check:
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(after)
    if check and unwrapped:
        print("Not wrapped at 100 columns:", *unwrapped, sep="\n  ")
        print("Run: pixi run format")
        return 1
    for path in unwrapped:
        print(f"Wrapped {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
