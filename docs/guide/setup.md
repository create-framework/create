# Installation and setup

There are two ways to set up your first Create project:

1. [`create-cli`](#option-1-create-cli): recommended for most users.
2. [Plain pixi](#option-2-plain-pixi): for those who would rather manage the pixi project
   themselves.

Both need [pixi](https://pixi.sh), which this command installs:

```sh
curl -fsSL https://pixi.sh/install.sh | sh
```

## Option 1: create-cli

[`create-cli`](https://github.com/create-framework/create-cli) creates and runs Create projects.
This command installs it to `~/.pixi/bin`:

```sh
pixi global install create-cli --channel https://prefix.dev/create-framework/create
```

Make a project and run it:

```sh
create new my-project
cd my-project
create run
```

`create new` makes a pixi project with the `mojo` and `create` packages and a `main.mojo` to
start from, and `create run` runs it from anywhere inside the project.

## Option 2: Plain pixi

Without `create-cli`, set up the pixi project by hand. Create it with the MAX and Create conda
channels enabled:

```sh
pixi init my-project \
  -c https://conda.modular.com/max \
  -c https://prefix.dev/create-framework/create \
  -c conda-forge
```

Then `cd` into the project and add the `mojo` and `create` packages:

```sh
cd my-project
pixi add mojo create
```

Write `main.mojo`, then run it:

```sh
pixi run mojo run main.mojo
```
