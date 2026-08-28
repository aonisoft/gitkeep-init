# gitkeep-init

Marks the **initial structure of a repository** by adding `.gitkeep` files in the
directories that would be empty in git, **understanding the `.gitignore`** by
itself (you don't need to tell it which directories to ignore).

## Quick start

### It depends on

- git (for `git check-ignore`)
- bash

### Installation

```bash
bash <(wget -qO- "https://raw.githubusercontent.com/aonisoft/gitkeep-init/main/install.sh")
source ~/.bashrc
```

> The `install.sh` clones the repo to `~/.gitkeep-init`, adds the line to your
> `~/.bashrc`, and leaves the `gitkp` command available from any
> directory, with tab autocompletion.

## Usage

```bash
gitkp run                       # creates the .gitkeep files
gitkp dry-run                   # shows what would be created, without touching anything
gitkp undo                      # removes the .gitkeep files that run created
gitkp run -c "init: add gitkeep"   # creates and commits with a custom message
gitkp help                      # general help
gitkp help run                  # help for a specific subcommand
```

### Subcommands

| Command | What it does |
|---|---|
| `run` | creates the `.gitkeep` files (default) |
| `dry-run` | shows what would be created, without modifying anything |
| `undo` | removes the `.gitkeep` files that `run` created |
| `help` | shows the help (of a subcommand if given) |

### Options

| Option | What it does |
|---|---|
| `-c, --commit [MESSAGE]` | commits the created `.gitkeep` files. Message optional: default if none given |
| `--force-root PATH` | forces a `.gitkeep` in the root of PATH even if its interior is trackable (repeatable) |

## How it decides what to mark

The tool **asks git** (`git check-ignore`) instead of looking at the filesystem,
so it replicates exactly what git would track:

- A directory is a **leaf** (gets a `.gitkeep`) if it has no subdirectories that
  git tracks.
- If a directory has subdirectories **all ignored** by the `.gitignore`, it
  would be empty in git → it is a leaf → it gets a `.gitkeep` in its root.
- If it has at least one trackable subdirectory → it is intermediate → its
  leaves are marked (recursively).
- `--force-root PATH` forces the `.gitkeep` in the root of PATH even if its
  interior is trackable.

Example: with `var/*` in the `.gitignore` and `!var/.gitkeep`, the tool marks
`var/.gitkeep` only (it doesn't go down into the ignored interior) — without
telling it anything.

## License

[MIT](LICENSE)

