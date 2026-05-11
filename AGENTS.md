# AGENTS.md

This file provides guidance to CatDoes (catdoes.com) when working with code in this repository.

## Project Overview

This is a monorepo containing two targets:

1. **`.` (root)** — The `asdf` bash CLI tool itself
2. **`web/`** — A static landing page for the `asdf` tool

---

## Target: CLI Tool (`.`)

`asdf` is a bash-based CLI tool that manages git worktrees for coding agents (like codex or claude), allowing developers to juggle multiple in-flight tasks in isolated environments. It automates worktree creation, switching, cleanup, and state-preserving forks.

### Commands

- **Run Agent:** `asdf [agent] [workspace] [-- agent-args...]` — Run a coding agent in a workspace (default: local checkout). Passes args after -- to the agent.
- **Shell into Workspace:** `asdf [workspace] cd` — Shell into a workspace.
- **Remove Workspace:** `asdf [workspace] rm` — Remove a workspace/worktree.
- **Fork Workspace:** `asdf [workspace] fork <new-workspace>` — Fork an existing workspace (including uncommitted changes) into a new one.
- **List Workspaces:** `asdf list` — List existing worktrees with creation dates and implementation summaries.
- **Generate/View Summary:** `asdf wdid` — Show or generate a .wdid.md file for a workspace.
- **Update Tool:** `asdf update` — Update the asdf executable.
- **Shell Completion:** `asdf --completion bash|zsh` — Generate shell completion scripts.

### Architecture

The project is primarily a bash-based CLI tool. The core logic resides in the `asdf` script. It relies on standard Unix tools (`bash`, `git`, `awk`, `sed`) to manage git worktrees.

- **Git Worktrees:** Uses `git worktree` to isolate different coding tasks/contexts.
- **Kickstart Mechanism (`jkl`):** Automatically executes a `jkl` script in the root of newly created or forked worktrees for environment setup (e.g., symlinking dependencies, copying env files).
- **Analytics:** Includes a Cloudflare Worker-based analytics setup (`analytics/worker.js`) to track usage.
- **Configuration:** No heavy configuration; uses environment variables (`ASDF_DEFAULT_AGENT`, `ASDF_WORKTREE_DIR`, etc.) for customization.

### Key Files

- `asdf` — Main CLI script
- `install.sh` — Installer script (downloads, validates, installs to `~/.local/bin`)
- `version.txt` — Current version string
- `analytics/worker.js` — Cloudflare Worker for usage analytics

---

## Target: Landing Page (`web/`)

A minimal, static landing page for the `asdf` tool. Notion/Japanese aesthetic — reads like a beautifully typeset markdown file.

### Stack

- **Framework:** Vite + React + TypeScript
- **Styling:** Tailwind CSS v4
- **Components:** shadcn/ui (available but minimally used)
- **Icons:** lucide-react

### Structure

```
web/
  src/
    App.tsx          — Single-file landing page (all content and components)
    components/
      colors/
        light.css    — Light mode color palette
        dark.css     — Dark mode color palette
  index.html         — Sets page <title>
```

### Key Patterns

- **Single page, single file:** All content lives in `web/src/App.tsx`. There is no routing.
- **Helper components:** `Mono` (inline code) and `CodeBlock` (fenced code block with copy button) are defined at the bottom of `App.tsx`.
- **Color palette:** Warm paper tone background (`#FAFAF9`), near-black text (`#1C1917`), stone-based muted tones. Set via `light.css` / `dark.css`.
- **Copy button:** `CodeBlock` uses `useState` + `navigator.clipboard` for a 2-second "Copied" confirmation.
- **No routing, no state management, no backend** — purely static.