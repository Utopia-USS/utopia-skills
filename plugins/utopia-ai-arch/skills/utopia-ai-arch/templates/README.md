# `.claude/` layer - copy-ready templates

This directory holds ready-to-copy file shapes for a Utopia Flutter project's `.claude/` layer (plus `CLAUDE.md` / `AGENTS.md` at repo root). Use it together with the parent **`utopia-ai-arch`** skill - the references under `../references/` are the authoritative guide for *how* to apply these shapes.

## Quick orientation

| What | Where |
|---|---|
| Map of templates → target paths + substitutions | [`TEMPLATES.md`](TEMPLATES.md) |
| Apply procedure (Phase 0–7) | [`../references/bootstrap-procedure.md`](../references/bootstrap-procedure.md) |
| Architectural rationale (two-layer model, routing, skill split, agent roster, hooks) | [`../references/`](../references/) - start with `layer-model.md` |
| Decision-log shape (rejected alternatives, toolchain canon, MCP assumption) | [`../references/architecture-doc.md`](../references/architecture-doc.md) |
| Per-bundle workflow extras (browser-testing, design, plan, ship, team) | [`workflow-templates/`](workflow-templates/) |

## What's in here

```
templates/
├── TEMPLATES.md                       map: each template → target path + substitutions
├── CLAUDE.md                          → <repo-root>/CLAUDE.md (fill in per Phase 5)
├── AGENTS.md  →  CLAUDE.md            symlink (preserve as symlink when copying)
├── conventions/                       module / pattern / cheatsheet authoring guides - REFERENCED from `claude-architecture.md` §3, never copied
├── claude-layer/                      copy into <repo-root>/.claude/ (minus refs/README.md), sed-replace <repo>
│   ├── settings.json
│   ├── docs/claude-architecture.md
│   ├── refs/README.md                 discipline doc for `.claude/refs/` - REFERENCED, never copied
│   ├── agents/REPO-{architect,maintainer,reviewer,precommit-auditor}.md
│   ├── commands/REPO-{implement,audit,audit-skills}.md
│   ├── scripts/REPO_{quality_check,skills_drift}.sh
│   └── skills/REPO-AREA/SKILL.md
└── workflow-templates/                opt-in bundles for browser-testing / design / plan / ship / team
```

## What gets copied vs what stays here

| Stays here (reference, never copy) | Copy per-repo (with substitution) |
|---|---|
| This `README.md` (you're reading the model) | `CLAUDE.md` → `<repo-root>/CLAUDE.md` |
| `conventions/{module,pattern,cheatsheet}-style.md` - foundation-level authoring guides | `AGENTS.md` → symlink to `CLAUDE.md` |
| `claude-layer/refs/README.md` - discipline doc for `.claude/refs/` | `claude-layer/docs/claude-architecture.md` → `<repo-root>/.claude/docs/` (drafted FIRST, before any other file) |
| Per-bundle `workflow-templates/<bundle>/README.md` - per-bundle adaptation notes | `claude-layer/agents/*`, `commands/*`, `scripts/*`, `settings.json`, `skills/REPO-AREA/SKILL.md` - substitute `<repo>` / `<REPO>` / `<repo-folder-name>` |

The conventions (`module-style.md`, `pattern-style.md`, `cheatsheet-style.md`) are explicitly **foundation-level** - duplicating them into a repo's `.claude/` invites drift. Cross-link from your `claude-architecture.md` §3 to the canonical path here.

## Substitution placeholders

Across all copied files:

| Find | Replace with | Example |
|---|---|---|
| `<repo>` | your project's lowercase prefix (short slug) | e.g. `aap` for the "acme-app-platform" repo |
| `<REPO>` | the prefix uppercased (env-var prefix) | `AAP_QUALITY_MODE` (from `<REPO>_QUALITY_MODE`) |
| `<project name>` | the human-readable project name | e.g. "Acme App Platform" |
| `REPO-AREA` (in skill directory names) | concrete area name | e.g. `aap-flutter`, `aap-backend` |
| `<repo-folder-name>` (in hook basename guard) | on-disk repo directory name | e.g. `acme-app-platform` |

**Prefix ≠ repo-folder-name.** They are independent and frequently differ - a repo whose folder is `acme-app-platform` may use the prefix `aap`. The hook's `basename "$repo_root"` match MUST use the folder name, not the prefix. If you substitute the prefix by mistake, the hook silently never fires. See [`../references/enforcement-hooks.md`](../references/enforcement-hooks.md) §"Scope guards".

## How to apply

Read [`../references/bootstrap-procedure.md`](../references/bootstrap-procedure.md) end-to-end before copying anything. Summary of the phases:

| Phase | What |
|---|---|
| 0 | **Gather** - domain risk, monorepo topology, tech stacks, external integrations (user-prompt), MCP servers, codegen surface, toolchain canon (FVM yes/no - binary), recent incidents |
| 1 | **Design the skill split** - POSITIVE + NEGATIVE applicability per skill; primitive sister vs deferred decision |
| 2 | **Draft `claude-architecture.md` FIRST** - before any other file. 9-section spine per [`architecture-doc.md`](../references/architecture-doc.md). Pre-populate §"Rejected alternatives" with the perennials. |
| 3 | **Copy and substitute** - per `TEMPLATES.md`; strip blueprint banners |
| 4 | **Wire `settings.json`** - `enabledPlugins: utopia-hooks@...`, `permissions.allow` (no `git push`), `hooks.PostToolUse` |
| 5 | **Trim `CLAUDE.md`** - fill the inventory tables; tight, no deep content |
| 6 | **Symlink `AGENTS.md → CLAUDE.md` and commit** - `ln -s CLAUDE.md AGENTS.md`; verify with `ls -la` |
| 7 | **Validate** - trigger each hook rule with a throwaway edit, run `<repo>_skills_drift.sh --all`, confirm description match fires per skill |

## What goes wrong if you skip Phase 0 or write the doc after the files

Both failure modes are catalogued in [`../references/evolution-and-drift.md`](../references/evolution-and-drift.md) and [`../references/bootstrap-procedure.md`](../references/bootstrap-procedure.md) §"Bootstrap-specific pitfalls". TL;DR: skill split, agent roster, command set, and hook scope are all functions of Phase 0 facts; the decision log narrates instead of decides when written after the files exist. Both are recoverable, both are avoidable.
