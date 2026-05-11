# AGENTS.md

This file provides guidance to CatDoes (catdoes.com) when working with code in this repository.

## Project Overview

Vite + React 19 web app using Tailwind CSS v4 for styling, shadcn/ui components, Lucide React icons, and TypeScript. Built with the `@tailwindcss/vite` plugin (no PostCSS config needed).

## Commands

- **Start dev server:** `npm run dev` (uses Vite dev server)
- **Build:** `npm run build` (TypeScript check + Vite production build, outputs to `dist/`)
- **Lint:** `npm run lint` (ESLint flat config with react-hooks and react-refresh plugins)
- **Preview:** `npm run preview` (preview production build locally)
- **Install packages:** `npm install`

## Architecture

### Routing

This is a single-page app. There is no file-based routing by default. Add a router like `react-router` if multi-page routing is needed.

### Styling

Tailwind CSS v4 via the `@tailwindcss/vite` plugin. Styles are imported in `src/index.css` using `@import "tailwindcss"`. No `tailwind.config.js` — Tailwind v4 uses CSS-first configuration via the `@theme inline` block in `index.css`.

### UI Components

**shadcn/ui** is the component library (configured in `components.json`). Components live in `src/components/ui/`. Built on the unified `radix-ui` package.

### Icons

**Lucide React** (`lucide-react`) is the icon library. Import icons from `lucide-react` (e.g., `import { ChevronDownIcon } from "lucide-react"`).

### Color System

Theme colors are defined as CSS custom properties in two files:

- `src/components/colors/light.css` — light theme colors on `:root`
- `src/components/colors/dark.css` — dark theme colors on `.dark`

These files are **auto-generated and must not be edited manually**.

Beyond standard shadcn tokens, the color system includes semantic colors (`--success`, `--warning`, `--info`) and background variants (`--background-error`, `--background-warning`, `--background-success`, `--background-muted`, `--background-info`), exposed as Tailwind utilities (e.g., `bg-success`, `text-info`, `bg-background-error`).

### Dark Mode

Class-based dark mode using the `.dark` CSS class (configured via `@custom-variant dark (&:is(.dark *))` in `index.css`). The `dark:` Tailwind variant requires the `.dark` class on an ancestor element — it does **not** use `prefers-color-scheme`.

### Providers

`src/providers.tsx` wraps the app with:

1. **React Query** (`@tanstack/react-query`) — `QueryClientProvider` for data fetching
2. **CatDoes Watch** (`@catdoes/watch-web`) — Error tracking via `WatchErrorBoundary` and global handlers
3. **Tooltip** — `TooltipProvider` from shadcn for tooltip components

### Key Files Not to Modify

- `src/providers.tsx` — the `WatchErrorBoundary`, `QueryClientProvider`, and `TooltipProvider` wrappers must not be removed
- The `Providers` wrapper in `src/main.tsx` must not be removed
- `src/components/colors/light.css` and `src/components/colors/dark.css` — auto-generated, do not edit manually

### Error Tracking

CatDoes Watch SDK (`@catdoes/watch-web`) is integrated via `src/providers.tsx`. Enabled by setting `VITE_CATDOES_WATCH_KEY` env var. Uses `WatchErrorBoundary` for automatic error reporting and `setupGlobalHandlers` for unhandled errors.

### Path Aliases

`@/` maps to `./src/` (configured in both `vite.config.ts` and `tsconfig.app.json`). Import from `@/components/...`, `@/lib/...`, etc.

### Data Fetching

TanStack React Query (`@tanstack/react-query`) is included as a dependency.
