<!--
  BLUEPRINT FILE - not a production CLAUDE.md.

  Adapt per-repo when applying the utopia-ai-arch project layer.
  Replace <repo>, <REPO>, <project name>, <repo-folder-name>, <area-N>
  placeholders with concrete values; trim sections you don't need; add
  repo-specific commands. Strip this banner after substitution.
-->

# <project name>

<one-line tagline of what the repo is>

> This file is also accessible as `AGENTS.md` (symlink) for tools that follow
> the OpenAI / Codex convention. Edit `CLAUDE.md`; the symlink keeps both views
> in sync. See the `utopia-ai-arch` skill (`references/claude-md.md`,
> §"The AGENTS.md symlink") for the rationale.

## Monorepo / topology

```
<repo-folder-name>/
├── <area-1>/    # short description (techstack)
├── <area-2>/    # ...
└── ...
```

## Foundation

This repo's Claude layer is layered on top of the **utopia-hooks** plugin
(marketplace, declared at project scope in `.claude/settings.json` under
`extraKnownMarketplaces` + `enabledPlugins`). Project skills assume it's
installed - they do not restate hook idioms, Screen/State/View, async
patterns, DI, IList/IMap/ISet, or strict-analyzer style. See
[.claude/docs/claude-architecture.md](.claude/docs/claude-architecture.md)
for the layer model.

If the marketplace auto-prompt was bypassed:

```
/plugin marketplace add https://github.com/Utopia-USS/utopia-flutter-skills
/plugin install utopia-hooks@utopia-flutter-skills
```

## Required Setup

<bootstrap commands - melos / FVM / submodules, applying the toolchain canon
recorded in the architecture doc; cross-link the repo README if it carries
the full setup>

<!-- Optional section - add when the topology tree alone stops being enough. -->
## Repository Overview

<one paragraph>

| Workspace | Purpose |
|-----------|---------|
| `<area-1>/` | <one-line purpose> |

## Skills inventory

| Skill | Applicability | Fires on |
|---|---|---|
| `<repo>-<area-1>` | <positive scope> - NOT <negative scope> | <typical edits> |
| `<repo>-<area-2>` | ... | ... |

(Inventory only - descriptions live in each `SKILL.md` frontmatter.)

## Agents

| Agent | Role |
|---|---|
| `<repo>-architect` | Plans, splits work, identifies affected skills |
| `<repo>-maintainer` | Implements plans (write) - used by `/<repo>-implement` |
| `<repo>-reviewer` | Post-implementation classified review |
| `<repo>-precommit-auditor` | Staged-diff commit-readiness audit |
| `<repo>-<domain>-auditor` | <optional per-repo addition with one-line trigger> |

## Slash commands

| Command | Purpose |
|---|---|
| `/<repo>-implement` | Code↔review loop (architect → maintainer ↔ reviewer) |
| `/<repo>-audit` | Pre-commit audit via auditor |
| `/<repo>-audit-skills` | Drift scan over `.claude/**/*.md` + `CLAUDE.md` |

## Hooks & Enforcement

Configured in [.claude/settings.json](.claude/settings.json):

- **`PostToolUse`** on `Edit | Write | MultiEdit` → `<repo>_quality_check.sh`
  - Blocks edits to generated files (<extensions per repo>)
  - Warns on <repo-specific convention violations>
  - Surfaces references by path: <path → skill list>
- **`PostToolUse`** on `Edit | Write | MultiEdit` → `<repo>_skills_drift.sh`
  - Warns on dead markdown links in edited `.claude/**/*.md` or `CLAUDE.md`

Default mode: `warn`. Set `<REPO>_QUALITY_MODE=block` to make
non-generated-file violations blocking.

## When to Invoke

| Situation | Skill / references that fire | Agents to involve |
|---|---|---|
| <typical task A> | <skill + ref> | <agent or -> |
| <typical task B> | <skill + ref> | <agent or -> |

(The highest-leverage table in this file - add a row every time a typical
task gets mis-routed.)

## Common Commands

| Task | Command |
|---|---|
| Bootstrap workspace | <repo command, applying the toolchain canon> |
| Code generation | <repo command> |
| Static analysis | <repo command> |
| Tests | <repo command> |
| Format | <repo command> |

<!-- Optional section - cross-links to repo-root docs outside the Claude layer. -->
## Documentation

- [.claude/docs/claude-architecture.md](.claude/docs/claude-architecture.md) - Claude layer decision log
- [docs/<other>.md](docs/<other>.md) - <repo-specific design docs>

## Architecture decisions

See [.claude/docs/claude-architecture.md](.claude/docs/claude-architecture.md) -
skill split rationale, enforcement mode, agent roster, rejected alternatives,
reversal criteria, toolchain canon.
