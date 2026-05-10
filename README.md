# Agent Session & Directory Forker

`asdf` is a small bash wrapper for running coding agents (`codex`, `claude`) across git worktrees. It lets you spin up parallel agent sessions in isolated checkouts, fork worktrees with their uncommitted changes intact, summarize past work, and bootstrap fresh worktrees with a kickstart script.

## Why

When you have several in-flight ideas, debugging branches, or experimental refactors, juggling them in a single checkout is painful. `asdf` makes it cheap to:

- Open an agent session in any named worktree with one command.
- Fork the current state of a worktree (including uncommitted edits) into a new branch.
- Move between worktrees with `cd`, remove them with `rm`, and list them with their cached summaries.
- Generate a cached `.wdid.md` ("What Did I Do") handoff note per worktree so future-you (or another agent) can resume quickly.

## Install

Place the `asdf` script anywhere on your `PATH` and make it executable.

```sh
chmod +x asdf
ln -s "$PWD/asdf" /usr/local/bin/asdf
```

Run `asdf` from anywhere inside a git repository.

## Usage

```
asdf [agent] [workspace] [-- agent-args...]
asdf [workspace] [-- agent-args...]
asdf [agent] [workspace] wdid [-- agent-args...]
asdf wdid [-- agent-args...]
asdf [agent] [workspace] cd
asdf [workspace] cd
asdf cd
asdf <workspace> rm
asdf <workspace> fork <new-workspace>
asdf list
asdf help
```

### Agents

Supported agents: `codex`, `claude`.

If no agent is given, `asdf` uses `ASDF_DEFAULT_AGENT` if set, otherwise `codex` when installed, falling back to `claude`.

### Workspaces

- `local` selects the current git checkout.
- Any other name selects an existing worktree, or creates one at `../<repo-name>-worktrees/<name>` if it does not exist yet.

### Examples

```sh
asdf                                                # default agent in local checkout
asdf codex                                          # codex in local checkout
asdf claude                                         # claude in local checkout
asdf codex my-feature                               # codex in worktree "my-feature"
asdf claude my-feature -- --dangerously-skip-permissions
asdf my-feature                                     # default agent in "my-feature"
asdf wdid                                           # show or generate .wdid.md for local
asdf codex my-feature wdid                          # show or generate .wdid.md in "my-feature"
asdf cd                                             # shell into local
asdf my-feature cd                                  # shell into the worktree
asdf my-feature rm                                  # remove the worktree
asdf my-feature fork my-feature-v2                  # fork the worktree (with uncommitted changes)
asdf list                                           # list worktrees with summaries
```

## Commands

### Run an agent (default)

Selects a checkout, `cd`s into it, and `exec`s the agent. Anything after `--` is forwarded to the agent verbatim.

### `wdid`

Prints `.wdid.md` from the selected checkout. If the file does not exist, `asdf` runs the selected agent headlessly to create it, then prints it.

The summary is cached. Once `.wdid.md` is present, `wdid` prints it without regenerating. Delete `.wdid.md` and re-run to regenerate.

When standard output is a terminal, the file is rendered with `glow`, `mdcat`, `bat`, or `less` (whichever is found first), falling back to plain `cat`.

### `cd`

Enters the selected checkout in a new interactive shell (uses `$SHELL`, falling back to `/bin/sh`). Exit the shell to return to where you were.

### `rm`

Removes the explicitly named worktree. The local checkout, the primary checkout, and the current checkout are all protected. Run `rm` from a different checkout if you want to remove the one you are currently in.

### `fork <new-workspace>`

Creates `<new-workspace>` as a new branch and worktree starting from the selected worktree's current `HEAD`. After the worktree is created, `asdf` copies over staged changes, unstaged changes, and untracked files from the source. It refuses to fork when the source has unresolved merge conflicts.

### `list` / `ls`

Lists git worktrees. If a worktree's `.wdid.md` has an `## Implementation Summary` section, that section is shown indented beneath the entry.

When standard output is a terminal, the list output is rendered as Markdown with `glow`, `mdcat`, or `bat` (whichever is found first), falling back to plain text. Piped output stays plain for scripts.

### `help`

Prints usage information.

## jkl - Just Kickstart Locally ;)

`jkl` is an optional bash script that runs whenever `asdf` creates a new worktree (either by normal first-time use or via `fork`). It is meant for the small, repetitive setup chores that git itself does not carry across worktrees.

### How it is found

`asdf` looks for a file literally named `jkl` at the root of the new worktree first, then at the root of the source checkout. If neither exists, the kickstart step is skipped silently.

For `fork`, `jkl` runs **after** uncommitted changes have been copied from the source worktree, so the script sees the same dirty state you forked from.

If `jkl` exits non-zero, `asdf` aborts and reports the failure for that worktree.

### Environment variables passed to `jkl`

| Variable              | Meaning                                         |
| --------------------- | ----------------------------------------------- |
| `ASDF_JKL_FILE`       | Absolute path to the `jkl` file being executed. |
| `ASDF_JKL_SOURCE_DIR` | Checkout or worktree used as the source.        |
| `ASDF_JKL_TARGET_DIR` | The newly created worktree being set up.        |
| `ASDF_JKL_WORKSPACE`  | The new worktree's name.                        |

The script's working directory is set to `ASDF_JKL_TARGET_DIR` before execution.

### What to put in `jkl`

Typical uses include:

- Copying git-ignored files such as `.env`, local secrets, or editor configs from the source.
- Running `npm install`, `bundle install`, `cargo fetch`, or similar bootstrap commands.
- Symlinking shared caches (`node_modules`, `.venv`, build artifacts) from the source worktree.
- Creating local databases, fixtures, or scratch directories.
- Printing a short reminder of "what to do next" in this fresh worktree.

### Example `jkl`

```bash
#!/usr/bin/env bash
set -euo pipefail

# Bring over local-only files from the source worktree.
for f in .env .env.local .vscode/settings.json; do
  if [ -f "$ASDF_JKL_SOURCE_DIR/$f" ] && [ ! -e "$ASDF_JKL_TARGET_DIR/$f" ]; then
    mkdir -p "$(dirname "$ASDF_JKL_TARGET_DIR/$f")"
    cp "$ASDF_JKL_SOURCE_DIR/$f" "$ASDF_JKL_TARGET_DIR/$f"
  fi
done

# Reuse the existing node_modules instead of reinstalling.
if [ -d "$ASDF_JKL_SOURCE_DIR/node_modules" ] && [ ! -e "node_modules" ]; then
  ln -s "$ASDF_JKL_SOURCE_DIR/node_modules" node_modules
fi

echo "kickstart for $ASDF_JKL_WORKSPACE done"
```

## Environment variables

| Variable                 | Default                                  | Meaning                                                                     |
| ------------------------ | ---------------------------------------- | --------------------------------------------------------------------------- |
| `ASDF_DEFAULT_AGENT`     | `codex` if installed, otherwise `claude` | Which agent to use when none is given.                                      |
| `ASDF_DEFAULT_WORKSPACE` | `local`                                  | Which workspace to use when none is given.                                  |
| `ASDF_WORKTREE_DIR`      | `../<repo-name>-worktrees`               | Where new worktrees are created. Relative paths resolve from the repo root. |

## How worktrees are laid out

By default, named worktrees live next to the primary checkout:

```
parent/
  my-repo/                      # primary checkout
  my-repo-worktrees/
    feature-a/
    feature-b/
```

Override the container with `ASDF_WORKTREE_DIR`:

```sh
ASDF_WORKTREE_DIR=/path/to/worktrees asdf codex my-feature
```

## Requirements

- `bash`, `git`, `awk`, `sed`.
- `codex` and/or `claude` on `PATH` for running agents.
- Optional: `glow`, `mdcat`, or `bat` for prettier `list` and `wdid` outputs.
