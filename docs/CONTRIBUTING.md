# Contributing to the documentation

How Create's documentation is built and published: the site, the user guide, and the API reference
generated from the docstrings. How to write it, here and everywhere else, is the [prose
style](../CONTRIBUTING.md#prose-style) in the main contributing guide.

The documentation site, [create-framework.org](https://create-framework.org/), is built from this
repo by `pixi run docs`, so a change and its documentation land together.
[scripts/docs.py](../scripts/docs.py) stages its pages:

- **Home** is the [README](../README.md), and the **user guide** is [guide/](guide/README.md). Write
  their links for GitHub, relative to the file: the site keeps links between its pages, copies
  images in, and points everything else (an example, a source file) at GitHub, at the commit built.
- The **API reference** is [reference/](reference/README.md), generated from the docstrings by `mojo
  doc`. It is committed, so it reads on GitHub as well as on the site. Never edit it by hand: after
  changing a docstring or the public surface, run `pixi run reference` and commit what changed. CI's
  `linux-docs` regenerates it and fails when the committed copy differs.

How the reference is laid out decides how a docstring should be written:

- **Each subpackage has a page**, headed by the package's own docstring. It lists what the package's
  `__init__.mojo` imports, grouped into types, traits, functions and constants, in import order
  within each group. So the public surface and the reference can't disagree.
- **Each type, trait and function has a page of its own.** The package's page lists it by the first
  line of its docstring, so write that line to make sense on its own. A constant has no page of its
  own; it is documented on the package's page.
- **A type's page groups its members** into constants, fields, constructors, methods and special
  methods (the dunders). A static method is listed as a constructor only when its signature ends in
  `-> Self`, so declare a factory's return type as `Self`, not by the type's name.
- **A function's overloads share one page.** Consecutive overloads with the same documentation are
  shown as one block of signatures.

Write Markdown without minding line length: the pre-commit hook wraps prose at 100 columns
([scripts/wrap_markdown.py](../scripts/wrap_markdown.py)), never splitting a word, and leaves code,
tables, HTML and headings as written. `pixi run format` wraps every page by hand.

A new guide page needs an entry in `nav` in [zensical.toml](../zensical.toml). The reference's nav
is generated: `docs.py` writes the config the site is built from to `build/docs/zensical.toml`, with
a page for every subpackage, type and function added.

The site is published in two versions, picked by a selector in its header: `/latest/`, the newest
release and what the root redirects to, and `/main/`, under a banner saying it is unreleased.
[scripts/docs_site.py](../scripts/docs_site.py) (`pixi run docs-site`) builds both. It builds the
release from a worktree of the release's tag, with that tag's own environment and scripts, and then
adds the version selector. [.github/workflows/docs.yml](../.github/workflows/docs.yml) publishes
them on every push to `main` and after every release. A docs fix after a release reaches `/latest/`
with the next release.
