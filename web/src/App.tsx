import { Github, ExternalLink, Copy, Check, Sun, Moon, Monitor } from "lucide-react";
import { useState, useEffect } from "react";

type Theme = "system" | "light" | "dark";

function useTheme() {
  const [theme, setTheme] = useState<Theme>(() => {
    return (localStorage.getItem("theme") as Theme) ?? "system";
  });

  useEffect(() => {
    const root = document.documentElement;
    const applyDark = (dark: boolean) => {
      root.classList.toggle("dark", dark);
    };

    if (theme === "system") {
      const mq = window.matchMedia("(prefers-color-scheme: dark)");
      applyDark(mq.matches);
      const handler = (e: MediaQueryListEvent) => applyDark(e.matches);
      mq.addEventListener("change", handler);
      return () => mq.removeEventListener("change", handler);
    } else {
      applyDark(theme === "dark");
    }
  }, [theme]);

  const setAndSave = (t: Theme) => {
    localStorage.setItem("theme", t);
    setTheme(t);
  };

  return { theme, setTheme: setAndSave };
}

const THEME_CYCLE: Theme[] = ["system", "light", "dark"];

const THEME_ICON: Record<Theme, React.ReactNode> = {
  system: <Monitor className="w-4 h-4" />,
  light: <Sun className="w-4 h-4" />,
  dark: <Moon className="w-4 h-4" />,
};

const THEME_LABEL: Record<Theme, string> = {
  system: "System",
  light: "Light",
  dark: "Dark",
};

export default function App() {
  const { theme, setTheme } = useTheme();

  const cycleTheme = () => {
    const next = THEME_CYCLE[(THEME_CYCLE.indexOf(theme) + 1) % THEME_CYCLE.length];
    setTheme(next);
  };

  return (
    <div className="min-h-screen bg-background text-foreground">

      {/* ── Floating theme toggle ── */}
      <button
        onClick={cycleTheme}
        title={`Theme: ${THEME_LABEL[theme]}`}
        className="fixed top-4 right-4 z-50 flex items-center gap-1.5 rounded-full border border-border bg-background px-3 py-1.5 text-xs text-muted-foreground hover:text-foreground hover:border-muted-foreground transition-colors cursor-pointer select-none"
      >
        {THEME_ICON[theme]}
        <span>{THEME_LABEL[theme]}</span>
      </button>

      <main className="max-w-[680px] mx-auto px-6 py-16 sm:py-24">

        {/* ── Header ── */}
        <header className="mb-14">
          <h1 className="text-3xl font-bold tracking-tight font-mono text-foreground mb-3">
            asdf
          </h1>
          <p className="text-base text-muted-foreground leading-relaxed">
            <span className="font-medium text-foreground">Agent Session &amp; Directory Forker</span>
            {" "}— a small bash wrapper for running coding agents across git worktrees.
          </p>
          <div className="mt-4">
            <a
              href="https://github.com/PHELAT/asdf"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 text-sm text-primary hover:underline underline-offset-4"
            >
              <Github className="w-3.5 h-3.5" />
              github.com/PHELAT/asdf
            </a>
          </div>
        </header>

        <hr className="border-border mb-14" />

        {/* ── Why ── */}
        <section className="mb-14">
          <h2 className="text-lg font-semibold text-foreground mb-4">Why</h2>
          <p className="text-sm text-muted-foreground leading-relaxed mb-4">
            Managing multiple in-flight coding tasks in parallel means juggling branches, uncommitted work, and agent context.{" "}
            <Mono>asdf</Mono>{" "}
            wraps git worktrees so each task lives in its own isolated directory, and your agent always starts in the right place.
          </p>
          <ul className="space-y-2.5">
            {[
              <>Open an agent session in any named worktree with one command.</>,
              <>Fork the current state of a worktree (including uncommitted edits) into a new branch.</>,
              <>Move between worktrees with <Mono>cd</Mono>, remove them with <Mono>rm</Mono>, and list them with their cached summaries.</>,
              <>Generate a cached <Mono>.wdid.md</Mono> ("What Did I Do") handoff note per worktree.</>,
            ].map((item, i) => (
              <li key={i} className="flex items-start gap-3 text-sm text-muted-foreground leading-relaxed">
                <span className="mt-0.5 text-primary font-mono text-xs select-none">—</span>
                <span>{item}</span>
              </li>
            ))}
          </ul>
        </section>

        <hr className="border-border mb-14" />

        {/* ── Install ── */}
        <section className="mb-14">
          <h2 className="text-lg font-semibold text-foreground mb-4">Install</h2>
          <CodeBlock lang="sh">{`curl -fsSL https://raw.githubusercontent.com/PHELAT/asdf/main/install.sh | sh`}</CodeBlock>
          <p className="mt-3 text-sm text-muted-foreground leading-relaxed">
            Installs to{" "}
            <Mono>~/.local/bin</Mono>, sets up shell completion automatically.
          </p>
        </section>

        <hr className="border-border mb-14" />

        {/* ── Commands ── */}
        <section className="mb-14">
          <h2 className="text-lg font-semibold text-foreground mb-4">Commands</h2>
          <div className="overflow-x-auto -mx-1">
            <table className="w-full text-sm border-collapse">
              <thead>
                <tr className="border-b border-border">
                  <th className="text-left font-medium text-foreground pb-2 pr-6 whitespace-nowrap">Command</th>
                  <th className="text-left font-medium text-foreground pb-2">Description</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {[
                  ["asdf [agent] [workspace]", "Run a coding agent in a workspace"],
                  ["asdf [workspace] cd", "Shell into a workspace"],
                  ["asdf [workspace] rm [--force]", "Remove a workspace; --force discards changes"],
                  ["asdf [workspace] fork <new>", "Fork a workspace with uncommitted changes"],
                  ["asdf list", "List worktrees with summaries"],
                  ["asdf wdid", "Show or generate .wdid.md for a workspace"],
                  ["asdf update", "Update the tool"],
                ].map(([cmd, desc]) => (
                  <tr key={cmd}>
                    <td className="py-2.5 pr-6 align-top">
                      <code className="font-mono text-xs text-foreground whitespace-nowrap">{cmd}</code>
                    </td>
                    <td className="py-2.5 align-top text-muted-foreground leading-relaxed">{desc}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <hr className="border-border mb-14" />

        {/* ── Examples ── */}
        <section className="mb-14">
          <h2 className="text-lg font-semibold text-foreground mb-4">Examples</h2>
          <CodeBlock lang="sh">{`asdf                            # default agent in local checkout
asdf codex my-feature           # codex in worktree "my-feature"
asdf claude my-feature -- --dangerously-skip-permissions
asdf my-feature fork my-feature-v2   # fork with uncommitted changes
asdf list                       # list worktrees with summaries
asdf wdid                       # show .wdid.md for current workspace`}</CodeBlock>
        </section>

        <hr className="border-border mb-14" />

        {/* ── Environment Variables ── */}
        <section className="mb-14">
          <h2 className="text-lg font-semibold text-foreground mb-4">Environment Variables</h2>
          <div className="overflow-x-auto -mx-1">
            <table className="w-full text-sm border-collapse">
              <thead>
                <tr className="border-b border-border">
                  <th className="text-left font-medium text-foreground pb-2 pr-4 whitespace-nowrap">Variable</th>
                  <th className="text-left font-medium text-foreground pb-2 pr-4 whitespace-nowrap">Default</th>
                  <th className="text-left font-medium text-foreground pb-2">Meaning</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {[
                  ["ASDF_DEFAULT_AGENT", "codex if installed, else claude", "Which agent to use when none is given"],
                  ["ASDF_WORKTREE_DIR", "../<repo>-worktrees", "Where new worktrees are created"],
                  ["ASDF_UPDATE_CHECK", "1", "Set to 0 to disable update warnings"],
                  ["ASDF_ANALYTICS", "1", "Set to 0 to disable anonymous analytics"],
                ].map(([variable, defaultVal, meaning]) => (
                  <tr key={variable}>
                    <td className="py-2.5 pr-4 align-top">
                      <code className="font-mono text-xs text-foreground whitespace-nowrap">{variable}</code>
                    </td>
                    <td className="py-2.5 pr-4 align-top">
                      <code className="font-mono text-xs text-muted-foreground whitespace-nowrap">{defaultVal}</code>
                    </td>
                    <td className="py-2.5 align-top text-muted-foreground leading-relaxed">{meaning}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <hr className="border-border mb-10" />

        {/* ── Footer ── */}
        <footer className="text-sm text-muted-foreground">
          Apache 2.0 License ·{" "}
          <a
            href="https://github.com/PHELAT/asdf"
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1 text-primary hover:underline underline-offset-4"
          >
            github.com/PHELAT/asdf
            <ExternalLink className="w-3 h-3" />
          </a>
        </footer>

      </main>
    </div>
  );
}

/* ── Small helpers ── */

function Mono({ children }: { children: React.ReactNode }) {
  return (
    <code className="font-mono text-xs bg-background-muted border border-border rounded px-1.5 py-0.5 text-foreground">
      {children}
    </code>
  );
}

function CodeBlock({ children, lang }: { children: string; lang?: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(children);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="rounded-md border border-border overflow-hidden">
      <div className="flex items-center justify-between px-4 py-1.5 bg-background-muted border-b border-border">
        <span className="text-xs font-mono text-muted-foreground">{lang ?? ""}</span>
        <button
          onClick={handleCopy}
          className="flex items-center gap-1.5 text-xs text-muted-foreground hover:text-foreground transition-colors cursor-pointer"
        >
          {copied ? (
            <>
              <Check className="w-3 h-3" />
              <span>Copied</span>
            </>
          ) : (
            <>
              <Copy className="w-3 h-3" />
              <span>Copy</span>
            </>
          )}
        </button>
      </div>
      <pre className="bg-background-muted px-4 py-4 overflow-x-auto">
        <code className="font-mono text-xs text-foreground leading-relaxed whitespace-pre">
          {children}
        </code>
      </pre>
    </div>
  );
}
