<!--
  BLUEPRINT FILE — not a production CLAUDE.md.

  Adapt per-repo when applying the project-claude-layer blueprint.
  Replace <repo>, <project name>, <area-N> placeholders with concrete
  values; trim sections you don't need; add repo-specific commands.
  See blueprint/project-claude-layer/README.md for the model.
-->

# <project name>

<one-line tagline of what the repo is>

> This file is also accessible as `AGENTS.md` (symlink) for
> tools that follow the OpenAI / Codex convention. Edit `CLAUDE.md`;
> the symlink keeps both views in sync. See blueprint README §11.

## Monorepo / topology

```
<repo>/
├── <area-1>/    # short description (techstack)
├── <area-2>/    # ...
└── ...
```

## Foundation

This repo's Claude layer is layered on top of the **utopia-hooks**
plugin. Project skills assume it's enabled — they do not restate hook
idioms, Screen/State/View, async patterns, or universal Flutter
conventions. See `.claude/docs/claude-architecture.md` for the layer
model.

The plugin is **declared at project scope** in `.claude/settings.json`
(`enabledPlugins` + `extraKnownMarketplaces`). When you first open
this repo with Claude Code, the CLI prompts you to trust and install
the declared plugin — no manual install step needed beyond accepting
the prompt. Run `/plugin` if you need to inspect or update later.

## Skills inventory

| Skill | Applicability | When it fires |
|---|---|---|
| `<repo>-<area-1>` | <positive scope> — NOT <negative scope> | <typical edits> |
| `<repo>-<area-2>` | ... | ... |

(Inventory only — descriptions live in each `SKILL.md` frontmatter.)

## Agents

| Agent | Role |
|---|---|
| `<repo>-architect` | Plans, splits work, identifies affected skills |
| `<repo>-maintainer` | Implements plans (write) — used by `/<repo>-implement` |
| `<repo>-reviewer` | Post-implementation classified review |
| `<repo>-precommit-auditor` | Staged-diff commit-readiness audit |
| `<repo>-<domain>-auditor` | Optional dedicated auditor (per repo decision) |

## Slash commands

| Command | Purpose |
|---|---|
| `/<repo>-implement` | Orchestrate code↔review loop |
| `/<repo>-audit` | Precommit audit |
| `/<repo>-audit-skills` | Drift scan over `.claude/**/*.md` |

## Shared references

`.claude/refs/` holds cross-skill markdown consumed by 2+ skills
(linked from each consuming `SKILL.md` "See also"). `.claude/docs/`
holds decisions about the layer (architecture log) and per-repo
authoring helpers (templates) — not loaded as agent guidance.

The whole AI architecture lives under `.claude/`. Repo-root `docs/`
remains free for non-Claude project documentation if needed.

## Common commands

<repo-wide build / test / format commands — keep tight>

## Architecture decisions

See `.claude/docs/claude-architecture.md` for the decision log: skill split
rationale, enforcement mode, agent roster additions, rejected
alternatives, reversal criteria.
