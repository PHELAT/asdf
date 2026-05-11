# Agent Session & Directory Forker

A small bash wrapper for running coding agents (`codex`, `claude`) across git worktrees. Spin up parallel agent sessions in isolated checkouts, fork worktrees with uncommitted changes intact, and generate handoff summaries for resuming later.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/PHELAT/asdf/main/install.sh | sh
```

The installer places `asdf` in `${ASDF_INSTALL_DIR:-$HOME/.local/bin}` and sets up shell completion for zsh/bash automatically.

> If another `asdf` command already exists on your `PATH`, the installer falls back to `asdff` and prints a warning. You can force a name with `ASDF_INSTALL_NAME=asdf` or `ASDF_INSTALL_NAME=asdff`.

## Quick start

```sh
asdf                            # default agent in local checkout
asdf claude my-feature          # claude in worktree "my-feature"
asdf my-feature                 # default agent in "my-feature"
asdf my-feature cd              # shell into the worktree
asdf my-feature fork my-v2      # fork with uncommitted changes
asdf my-feature rm              # remove the worktree
asdf my-feature wdid            # show/generate handoff summary
asdf list                       # list worktrees with dates and summaries
asdf update                     # self-update
```

Anything after `--` is forwarded to the agent: `asdf claude my-feature -- --dangerously-skip-permissions`

## Agents

Supported: `codex`, `claude`. If none is specified, `asdf` uses `ASDF_DEFAULT_AGENT` if set, then `codex` if installed, then `claude`.

## Workspaces

- `local` — the current git checkout.
- Any other name — an existing worktree, or a new one created at `../<repo>-worktrees/<name>`.

```
parent/
  my-repo/                  # primary checkout
  my-repo-worktrees/
    feature-a/
    feature-b/
```

Override the location with `ASDF_WORKTREE_DIR`.

## Commands

| Command      | Description                                                                                                                                  |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| _(default)_  | Select a checkout and exec the agent.                                                                                                        |
| `wdid`       | Print the worktree's `.wdid.md` handoff summary (“What Did I Do”). Generates one via the agent if missing.                                   |
| `cd`         | Open an interactive shell in the selected checkout.                                                                                          |
| `rm`         | Remove a named worktree. The local, primary, and current checkouts are protected.                                                            |
| `fork <new>` | Create a new worktree from the current HEAD, copying staged, unstaged, and untracked files. Refuses to fork with unresolved merge conflicts. |
| `list`       | List worktrees newest-first with creation dates and summaries.                                                                               |
| `update`     | Self-update from the upstream repository.                                                                                                    |
| `version`    | Print version.                                                                                                                               |
| `help`       | Print usage.                                                                                                                                 |

When stdout is a terminal, `wdid` and `list` render Markdown with `glow`, `mdcat`, `bat`, or `less` (first found), falling back to plain text.

## Shell completion

The installer sets up completion automatically. For manual setup:

```sh
# zsh
eval "$(asdf --completion zsh)"

# bash
eval "$(asdf --completion bash)"
```

Completes workspace names, agents, and commands.

## jkl — Just Kickstart Locally ;)

An optional bash script that runs when `asdf` creates a new worktree (including via `fork`). Place a file named `jkl` at the repo root for setup tasks like copying `.env` files, symlinking `node_modules`, or running `npm install`.

Details and example

`asdf` looks for `jkl` in the new worktree first, then in the source checkout. For `fork`, it runs after uncommitted changes have been copied. If `jkl` exits non-zero, `asdf` aborts.

Environment variables passed to `jkl`:

| Variable              | Meaning                                         |
| --------------------- | ----------------------------------------------- |
| `ASDF_JKL_FILE`       | Absolute path to the `jkl` file being executed. |
| `ASDF_JKL_SOURCE_DIR` | Source checkout or worktree.                    |
| `ASDF_JKL_TARGET_DIR` | The newly created worktree.                     |
| `ASDF_JKL_WORKSPACE`  | The new worktree's name.                        |

The working directory is set to `ASDF_JKL_TARGET_DIR`.

```bash
#!/usr/bin/env bash
set -euo pipefail

for f in .env .env.local .vscode/settings.json; do
  if [ -f "$ASDF_JKL_SOURCE_DIR/$f" ] && [ ! -e "$ASDF_JKL_TARGET_DIR/$f" ]; then
    mkdir -p "$(dirname "$ASDF_JKL_TARGET_DIR/$f")"
    cp "$ASDF_JKL_SOURCE_DIR/$f" "$ASDF_JKL_TARGET_DIR/$f"
  fi
done

if [ -d "$ASDF_JKL_SOURCE_DIR/node_modules" ] && [ ! -e "node_modules" ]; then
  ln -s "$ASDF_JKL_SOURCE_DIR/node_modules" node_modules
fi

echo "kickstart for $ASDF_JKL_WORKSPACE done"
```

## Environment variables

Configuration reference

| Variable                 | Default                             | Meaning                                 |
| ------------------------ | ----------------------------------- | --------------------------------------- |
| `ASDF_DEFAULT_AGENT`     | `codex` if installed, else `claude` | Agent when none is given.               |
| `ASDF_DEFAULT_WORKSPACE` | `local`                             | Workspace when none is given.           |
| `ASDF_WORKTREE_DIR`      | `../<repo>-worktrees`               | Where new worktrees are created.        |
| `ASDF_UPDATE_CHECK`      | `1`                                 | Set `0` to disable update warnings.     |
| `ASDF_ANALYTICS`         | `1`                                 | Set `0` to disable anonymous analytics. |
| `ASDF_INSTALL_DIR`       | `$HOME/.local/bin`                  | Installer destination directory.        |
| `ASDF_INSTALL_NAME`      | `asdf` (or `asdff` fallback)        | Installer command name.                 |

## Requirements

- `bash`, `git`, `awk`, `sed`
- `codex` and/or `claude` on `PATH`
- Optional: `glow`, `mdcat`, or `bat` for rendered Markdown output
