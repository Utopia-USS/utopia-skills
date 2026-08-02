---
title: CLAUDE.md & AGENTS.md - Top-of-Context Inventory + Symlink
impact: HIGH
tags: claude-md, agents-md, symlink, inventory, routing, when-to-invoke
---

# CLAUDE.md & AGENTS.md - Top-of-Context Inventory + Symlink

## What this is

`CLAUDE.md` lives at the repo root. It is **always loaded into the agent's top of context** at every turn - unlike skills, which load on description match, and references, which load only when a skill points to them. That privileged position makes it the right place for **routing** content: what skills exist, what agents exist, what commands exist, where to send the agent for each kind of task.

`AGENTS.md` at the repo root is a **symlink to `CLAUDE.md`**. Same file, different filename - so non-Anthropic tools that follow the OpenAI / Codex convention (Codex, Cursor's agent surface where it asks, etc.) read the same content without a second copy to maintain.

> "This file is also accessible as `AGENTS.md` (symlink) for tools that follow the OpenAI / Codex convention. Edit `CLAUDE.md`; the symlink keeps both views in sync." - `production-repo-B/CLAUDE.md:6-8`

`CLAUDE.md` is **an inventory and a routing map**, not a knowledge base. Deep content belongs in skill references. If you find yourself writing a paragraph in `CLAUDE.md` that explains HOW to do something, the paragraph belongs in a skill reference and the `CLAUDE.md` row belongs in the "When to Invoke" table that routes to it.

## When this applies

- **Bootstrapping a new repo** - write `CLAUDE.md` after the architecture doc is drafted (so its inventory tables match the decisions). Symlink `AGENTS.md` in the same commit.
- **Adding a skill** - append a row to §"Skills inventory" and one or more rows to §"When to Invoke".
- **Adding an agent** - append a row to §"Agents".
- **Adding a slash command** - append a row to §"Slash commands".
- **Adding a path nudge in the hook** - extend §"Hooks & Enforcement".
- **Editing the "When to Invoke" routing table** - this is the most-frequent edit; the table evolves with every new typical-task pattern the team encounters.
- **Trimming bloat** - if `CLAUDE.md` is over ~300 lines, content has leaked from references and needs to flow back out.

## What belongs in CLAUDE.md

The inventory. Specifically:

### Repository overview

One paragraph: what the repo is. Then a workspace table:

```markdown
| Workspace | Purpose |
|-----------|---------|
| `<area-1>/` | Mobile app (iOS / Android) |
| `admin/` | Admin web portal (Flutter web) |
| `<area-2>/` | Companion device app |
| ...      | ... |
```

- pattern from `production-repo-A/CLAUDE.md:52-63`. One line per workspace. **Long descriptions belong in a skill module-ref** that owns that workspace.

### Foundation

One paragraph reminding the agent that the project layers on top of `utopia-hooks`, with the install command as a fallback for setups where the marketplace auto-prompt was bypassed:

> "This repo's Claude layer is layered on top of the **utopia-hooks** plugin (marketplace, enabled in `.claude/settings.json`). Project skills assume it's installed - they do not restate hook idioms, Screen/State/View, async patterns, DI, IList/IMap/ISet, or strict-analyzer style. See `.claude/docs/claude-architecture.md` for the layer model." - `production-repo-C/CLAUDE.md:33-38`

Optional install-command block if the auto-prompt fails (repo-A's pattern):

```
/plugin marketplace add https://github.com/Utopia-USS/utopia-flutter-skills
/plugin install utopia-hooks@utopia-flutter-skills
```

- `production-repo-A/CLAUDE.md:30-33`. **Do not restate what utopia-hooks teaches** - one line describing the foundation's scope is enough; the foundation owns the content.

### Required Setup

Bootstrap commands - melos, FVM, submodules - one short paragraph plus one code block. Pattern (`production-repo-A/CLAUDE.md:22-44`):

```markdown
Standard Flutter setup (FVM, submodules, melos) per [README.md](README.md).

The `utopia-hooks` Claude Code plugin is declared in
[`.claude/settings.json`](.claude/settings.json) under
`extraKnownMarketplaces` + `enabledPlugins`. ...
```

Cross-link to the repo `README.md` for the full setup if the repo has one.

### Claude Skills inventory

Table with three columns: `Skill | Kind | Fires on` (repo-A) or `Skill | Applicability | Fires on` (repo-B, repo-C).

**Descriptions live in each `SKILL.md` frontmatter, not here.** This is an inventory - agent goes to the named skill for content.

```markdown
| Skill            | Applicability                                                  | Fires on                              |
|------------------|---------------------------------------------------------------|---------------------------------------|
| `<prefix>`          | Flutter apps (`app/`, `admin/`), design system, domain flows - NOT `backend/` Kotlin, NOT `landing/` Next.js | Flutter widget / service / model edits |
| `<prefix>-api`      | backend (Ktor gRPC, Kotlin) - NOT Flutter, NOT landing | Kotlin edits under `backend/` |
| `browser-testing`| Chrome MCP automation against the web build                    | When driving the browser via Chrome MCP |
| `<prefix>-design`   | Design→code from <design-tool> (MCP) or claude.design ...      | Paper MCP usage, handoff bundle       |
```

- `production-repo-B/CLAUDE.md:48-53` (workspace names genericised). **The "Applicability" column includes the NEGATIVE scope** - it mirrors the SKILL.md frontmatter's "Applicability - NEGATIVE: NOT …" line. This is what stops the agent loading the wrong skill.

### Claude Agents

Table - `Agent | Role | Tools | When` (repo-A's exhaustive form) or `Agent | Role` (repo-B's minimal form):

```markdown
| Agent                     | Role                                                |
|---------------------------|-----------------------------------------------------|
| `<prefix>-architect`      | Plans, splits work, identifies affected skills      |
| `<prefix>-maintainer`     | Implements plans (write) - used by `/<prefix>-implement` |
| `<prefix>-reviewer`       | Post-implementation classified review               |
| `<prefix>-precommit-auditor` | Staged-diff commit-readiness audit               |
```

If the repo adds a domain auditor (repo-A's `<prefix>-security-auditor`), it gets a row plus a one-line "When" describing its trigger surface. Full invariants live in `agents/<name>.md` - the CLAUDE.md row is just the routing signal.

### Slash Commands

Table - `Command | Purpose`:

```markdown
| Command                | Purpose                                              |
|------------------------|------------------------------------------------------|
| `/<prefix>-implement`  | Code↔review loop (architect → maintainer ↔ reviewer) |
| `/<prefix>-audit`      | Pre-commit audit via auditor                         |
| `/<prefix>-audit-skills`| Drift scan over `.claude/**/*.md` + `CLAUDE.md`     |
```

- `production-repo-C/CLAUDE.md:65-69`. Same shape across repos; only the prefix changes (and any additions per [slash-commands.md](slash-commands.md)).

### Hooks & Enforcement

Short paragraph + bullet list of what each script blocks / warns / surfaces. Cross-link to `.claude/settings.json`. Repo-A's is exemplary:

> "Configured in `.claude/settings.json`:
>
> - **`PostToolUse`** on `Edit | Write | MultiEdit` → `<prefix>_quality_check.sh`
>   - **Blocks** edits to generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`, `*.pb*.dart`)
>   - **Warns** on relative Dart imports in `lib/`
>   - **Surfaces** references by path: …
> - **`PostToolUse`** on `Edit | Write | MultiEdit` → `<prefix>_skills_drift.sh`
>   - **Warns** on dead markdown `[text](path)` links …"

- `production-repo-A/CLAUDE.md:176-191`

### When to Invoke

`Situation | Skill / references that fire | Agents to involve` - the routing table. **The highest-leverage section in `CLAUDE.md`.** Time spent here is time spent routing every future task correctly.

```markdown
| Situation | Skill / references that fire | Agents to involve |
|-----------|-------------------------------|-------------------|
| Any Dart / Flutter edit in `<area-1>/` / `admin/` / `<area-2>/` / `<area-3>/` | **`utopia-hooks`** (always) + `<prefix>` master skill | - |
| Add a new screen in `<area-1>/` / `admin/` / `<area-2>/` | **`utopia-hooks`**, `<prefix>` (→ `components.md`, `tokens.md`) | - |
| Edit `<crypto-package>/`, `packages/<crypto-pkg>/`, `packages/<kem-pkg>/` | `<prefix>` (FFI binding style → `ffi-conventions.md`) + sister `<prefix>-security` (E2E audit → `e2e-encryption.md`) | `<prefix>-security-auditor` |
| Plan any cross-package feature | - | `<prefix>-architect` via [/<prefix>-plan](.claude/commands/<prefix>-plan.md) |
| Pre-commit gate on staged diff | - | `<prefix>-precommit-auditor` via [/<prefix>-audit](.claude/commands/<prefix>-audit.md) |
| ... | ... | ... |
```

- `production-repo-A/CLAUDE.md:131-157`. Each row is a typical task pattern the agent should know how to route. The middle column lists which skills (and which specific reference files within them) the agent should consult; the right column names which agent (if any) to delegate to.

**The table grows with the team.** Every time a typical task gets mis-routed, the fix is a new row.

### Common Commands

Table - `Task | Command` - scoped to the repo's actual workflow. Bootstrap, codegen, analyze, test, build, format. Repo-C's minimal shape:

```markdown
| Task                              | Command                                              |
|-----------------------------------|------------------------------------------------------|
| Bootstrap workspace               | `melos bootstrap`                                    |
| Code generation (freezed, json, localization) | `fvm dart run build_runner build --delete-conflicting-outputs` (run inside the package) |
| Static analysis (Dart)            | `fvm dart analyze` (authoritative)                   |
| Tests                             | `fvm flutter test` (per package)                     |
| Format Dart                       | `fvm dart format`                                    |
| Functions build (TS)              | `cd functions && npm run build`                      |
```

- `production-repo-C/CLAUDE.md:73-80`. **Apply the toolchain canon here** (FVM yes/no - see [architecture-doc.md](architecture-doc.md) §"Toolchain canon"). If `bash dart analyze` is in this table when the toolchain canon says `fvm dart analyze`, the commands fail silently against the system Dart and the doc is lying.

### Documentation

Cross-links to repo-root docs that aren't part of the Claude layer:

```markdown
- [.claude/docs/claude-architecture.md](.claude/docs/claude-architecture.md) - Claude layer architecture, decisions, concrete shape, rejected alternatives
- [docs/architecture.md](docs/architecture.md) - System topology + key-exchange sequence diagrams
- [docs/data_exchange.md](docs/data_exchange.md) - Message semantics (at-least-once, dedup, delete-after-process)
```

- `production-repo-A/CLAUDE.md:233-236`. Distinguish: `.claude/docs/` is decision-log; repo-root `docs/` is system design.

## What does NOT belong in CLAUDE.md

- **Pattern / module / cheatsheet content.** Those live in `.claude/skills/<area>/references/`. If `CLAUDE.md` is teaching the agent "how to write a hook", the rule belongs in `utopia-hooks` or the pattern reference.
- **Decision-log content.** Decisions, rejected alternatives, reversal criteria all live in `.claude/docs/claude-architecture.md`. The CLAUDE.md is the inventory of the layer; the architecture doc is the *justification* of the layer.
- **Cross-skill shared markdown.** That's `.claude/refs/<shared-doc>.md`, linked from each consuming `SKILL.md`'s "See also".
- **Code samples beyond brief command lines.** A `bash` codeblock for `melos bootstrap` is fine. A 20-line Dart example illustrating a pattern is not - that's a pattern reference.
- **Per-skill non-negotiable rules.** Those live in each `SKILL.md`. Putting them in `CLAUDE.md` makes the rule global when it isn't.

> "Inventory only - descriptions live in each `SKILL.md` frontmatter." - `production-repo-C/CLAUDE.md:48`, `production-repo-B/CLAUDE.md:55`

## Canonical shape skeleton

The order MUST be the order shown. Production samples deviate (repo-A opens with "Design Invariants"; repo-B and repo-C omit Required Setup / Repository Overview / When to Invoke and stay minimal). The universal core across all three: topology, Foundation, the Skills / Agents / Slash commands inventories, Common Commands, Architecture decisions. The rest is repo-A-grade structure worth adding as the repo grows - When to Invoke pays for itself first.

```markdown
# <Repo Name>

<One-line tagline of what the repo is.>

> This file is also accessible as `AGENTS.md` (symlink) for tools that follow
> the OpenAI / Codex convention. Edit `CLAUDE.md`; the symlink keeps both views
> in sync. See the `utopia-ai-arch` skill (`references/claude-md.md`,
> §"The AGENTS.md symlink") for the rationale.

## Monorepo / topology

```
`<repo>`/
├── `<area-1>`/    # short description (techstack)
├── `<area-2>`/    # ...
└── ...
```

## Foundation

This repo's Claude layer is layered on top of the **utopia-hooks** plugin
(marketplace, enabled in `.claude/settings.json`). Project skills assume it's
installed - they do not restate hook idioms, Screen/State/View, async patterns,
DI, IList/IMap/ISet, or strict-analyzer style. See
[.claude/docs/claude-architecture.md](.claude/docs/claude-architecture.md) for the
layer model.

## Required Setup

<bootstrap commands - melos, FVM, submodules, plugin install fallback>

## Repository Overview

<one paragraph + workspace table>

| Workspace | Purpose |
|-----------|---------|
| `<workspace>` | <one-line purpose> |

## Skills inventory

| Skill | Applicability | Fires on |
|---|---|---|
| `<prefix>-<area>` | <positive scope> - NOT <negative scope> | <typical edits> |

(Inventory only - descriptions live in each `SKILL.md` frontmatter.)

## Agents

| Agent | Role |
|---|---|
| `<prefix>-architect` | Plans, splits work, identifies affected skills |
| `<prefix>-maintainer` | Implements plans (write) - used by `/<prefix>-implement` |
| `<prefix>-reviewer` | Post-implementation classified review |
| `<prefix>-precommit-auditor` | Staged-diff commit-readiness audit |
| `<prefix>-<domain>-auditor` | <optional per-repo addition with one-line trigger> |

## Slash commands

| Command | Purpose |
|---|---|
| `/<prefix>-implement` | Code↔review loop (architect → maintainer ↔ reviewer) |
| `/<prefix>-audit` | Pre-commit audit via auditor |
| `/<prefix>-audit-skills` | Drift scan over `.claude/**/*.md` + `CLAUDE.md` |

## Hooks & Enforcement

Configured in [`.claude/settings.json`](.claude/settings.json):

- **`PostToolUse`** on `Edit | Write | MultiEdit` → `<prefix>_quality_check.sh`
  - Blocks edits to generated files (<list per repo>)
  - Warns on <repo-specific convention violations>
  - Surfaces references by path: <path → skill table>
- **`PostToolUse`** on `Edit | Write | MultiEdit` → `<prefix>_skills_drift.sh`
  - Warns on dead markdown links in edited `.claude/**/*.md` or `CLAUDE.md`

Default mode: `warn`. Set `<PREFIX>_QUALITY_MODE=block` to make non-generated-file
violations blocking.

## When to Invoke

| Situation | Skill / references that fire | Agents to involve |
|---|---|---|
| <typical task A> | <skill + ref> | <agent or -> |
| <typical task B> | <skill + ref> | <agent or -> |
| ...               | ...           | ...           |

## Common Commands

| Task | Command |
|---|---|
| Bootstrap workspace | <repo command, applying toolchain canon> |
| Code generation | <repo command> |
| Static analysis | <repo command> |
| Tests | <repo command> |
| Format | <repo command> |

## Documentation

- [.claude/docs/claude-architecture.md](.claude/docs/claude-architecture.md) - Claude layer decision log
- [docs/<other>.md](docs/<other>.md) - <repo-specific design docs>

## Architecture decisions

See [.claude/docs/claude-architecture.md](.claude/docs/claude-architecture.md) -
skill split rationale, enforcement mode, agent roster choices, rejected
alternatives, reversal criteria, toolchain canon.
```

## The AGENTS.md symlink

`AGENTS.md` is a real symlink to `CLAUDE.md`. Same content, different path. Verified in production:

```
lrwxr-xr-x@ 1 user             staff  9  Apr 29 14:50  production-repo-B/AGENTS.md -> CLAUDE.md
lrwxr-xr-x@ 1 user             staff  9  Apr 29 00:45  production-repo-C/AGENTS.md -> CLAUDE.md
```

(`ls -la` output - note the `l` filetype and the `-> CLAUDE.md` target).

### Operations

```bash
cd <repo-root>
ln -s CLAUDE.md AGENTS.md
git add CLAUDE.md AGENTS.md
git commit -m "AGENTS.md symlink for OpenAI/Codex tooling"
```

Verification (do this whenever you suspect drift):

```bash
ls -la AGENTS.md
# Expected: lrwxr-xr-x ... AGENTS.md -> CLAUDE.md
```

If the output is `-rw-r--r--` (regular file) and a byte count instead of `-> CLAUDE.md`, the symlink was lost - replaced by a copy at some point. Recreate immediately:

```bash
rm AGENTS.md
ln -s CLAUDE.md AGENTS.md
```

### Why symlink, not copy

Copies drift. Two files, two truths. Every edit to `CLAUDE.md` is a follow-up edit to `AGENTS.md` that nobody remembers; tools reading one see fresh content while tools reading the other see stale. The drift is silent - neither tool flags it.

**Concrete evidence - repo-A currently has this drift.** As of the last check:

```
-rw-r--r--@ 1 user             staff  16574  May 11 22:59  production-repo-A/AGENTS.md
```

It's a regular file, not a symlink. `wc -l` shows `CLAUDE.md` at 248 lines, `AGENTS.md` at 246 - already two lines apart. The blueprint explicitly anticipated this drift mode:

> "Maintaining duplicate files invites drift - exactly the situation repo-B currently has, where `AGENTS.md` went stale relative to `CLAUDE.md` because they were independent copies." - blueprint README v1 (written before repo-B's fix)

Repo-B fixed it by re-creating the symlink; repo-A is still in this drift state. Either case is a known anti-pattern, and the diagnosis is one `ls -la` away.

### Why symlink, not hard link

> "git preserves symlinks natively (as a special blob type). After clone, the symlink re-creates itself pointing at the target. Hard links … are not preserved by git; they require a setup script and post-checkout hook to re-create locally, and a clone gets two independent files that drift." - blueprint README v1

Symlink is the simpler, git-native mechanism. Hard links sound symmetric but require a setup script and a post-checkout hook in every clone - exactly the friction that produces drift.

### Windows note

> "Symlinks on Windows require Developer Mode enabled (or admin privileges) for `git checkout` to materialise them. If a contributor ends up with a plain text file containing the path string instead of a working symlink, they need to enable Developer Mode and re-run `git checkout HEAD -- AGENTS.md`." - blueprint README v1

For mixed-OS teams where this is friction, the fallback is `.claude/scripts/setup-agent-files.sh` + a `post-checkout` hook. The blueprint ships the symlink directly; add the script only if needed.

### Cursor IDE - no extra symlink

Cursor reads `.claude/skills/` directly. Earlier blueprint revisions prescribed `.cursor/skills → ../.claude/skills`; **that step is retired** (blueprint README v1). `.cursor/mcp.json` is unrelated and stays committed where it exists.

Cross-link to [bootstrap-procedure.md](bootstrap-procedure.md) for the Phase 6 step where the symlink is created.

## Operational rules

### 1. Every skill / agent / command in `.claude/` must appear in the corresponding CLAUDE.md table.

Otherwise `<prefix>-precommit-auditor` flags drift (see [agent-roster.md](agent-roster.md) §"What it checks") - `.claude/` doc drift is in its scope. The two should be **identical inventories**. If they aren't, one of them is lying.

### 2. CLAUDE.md is for routing, not content.

If you find yourself writing a paragraph that explains HOW to do something, the paragraph belongs in a skill reference. The `CLAUDE.md` row belongs in the "When to Invoke" table that routes to the reference.

### 3. The "When to Invoke" table is the highest-leverage section.

Spend time there. It routes the agent for every task it sees. Add a row every time a typical task gets mis-routed.

### 4. Foundation reference is single-sourced.

One paragraph + one install command, in the `## Foundation` section. The agent shouldn't see the foundation's content restated; the foundation owns it. Restating it makes the foundation feel optional when it isn't.

> "A Claude config for this repo that does not integrate `utopia-hooks` is missing the foundation the codebase is written on - treat its absence as a defect, not as a simpler, self-contained alternative." - `production-repo-A/CLAUDE.md:13`

### 5. Keep CLAUDE.md short.

Production sample line counts (at distillation time):

| Repo | CLAUDE.md lines |
|---|---|
| production-repo-C | ~90 |
| production-repo-B | ~150 |
| production-repo-A | ~250 |

Past ~250 lines, content has typically leaked from references. Past ~300 lines, it's almost certainly leaking. Scan for paragraphs that explain mechanisms (those move to references) and tables that mirror references (those collapse into single-row pointers).

## Drift symptoms specific to CLAUDE.md

These are the things to scan for during a CLAUDE.md audit. Each has been observed in production:

- **Skill table lists a skill that no longer exists at `.claude/skills/<name>/`.** Fix: delete the row, or restore the skill if it was deleted by mistake.
- **Agent table lists an agent that no longer exists at `.claude/agents/<name>.md`.** Fix: delete the row.
- **"When to Invoke" routes to skills no longer present.** Fix: delete the row, or rewrite to route to the replacement skill.
- **`AGENTS.md` is a copy, not a symlink** - drift is inevitable. The repo-A and pre-fix-repo-B precedents are both real. Fix: `rm AGENTS.md && ln -s CLAUDE.md AGENTS.md`.
- **Paragraphs of HOW-TO content** - pattern or module material in `CLAUDE.md`. Fix: move to the appropriate skill reference; replace with a "When to Invoke" row that routes there.
- **Restated foundation conventions** - `CLAUDE.md` teaching Screen/State/View or `IList` rules. Fix: collapse to "see `utopia-hooks`" with the foundation pointer.
- **Long CLAUDE.md (>~300 lines)** - content leaked from references. Fix: scan for the longest sections; move the deepest content out.
- **Toolchain canon ambiguity** - `Common Commands` table mixing `dart` and `fvm dart`. Fix: apply the canon recorded in the architecture doc uniformly.
- **Skill table rows with no NEGATIVE scope.** Without the NOT-clause the agent can't tell a misfire from a fit. Fix: copy the SKILL.md frontmatter's negative scope into the table cell.

Cross-link to [evolution-and-drift.md](evolution-and-drift.md) for the catalogue covering the whole layer.

## Anti-patterns

(AGENTS.md drift to a copy is [evolution-and-drift.md](evolution-and-drift.md) symptom + canonical fix at §"The AGENTS.md symlink" above. MCP-not-installed copy-paste is §P. Below: CLAUDE.md-specific.)

### CLAUDE.md restating Screen/State/View, IList rules, hook idioms

Foundation territory. Restating makes the foundation feel optional; the cross-link to `utopia-hooks` is the contract - restatement is silent divergence. **Fix:** delete the restatement; keep the single `## Foundation` paragraph pointing at utopia-hooks.

### CLAUDE.md containing module-level user flows

A "How activities work" / "Game flow lifecycle" section deep in `CLAUDE.md` is module-ref material - belongs in `skills/<prefix>/references/<feature>-module.md`. **Fix:** lift to a module ref; add a "When to Invoke" row routing to it.

### "When to Invoke" table missing rows for newly-added skills/agents

The new skill exists but the routing table doesn't mention it. Auto-routing falls back to description matching alone - fine for some skills, brittle for path-tight ones. **Fix:** every new skill / agent / command lands with at least one "When to Invoke" row in the same change.

### Common Commands table with commands that don't actually work in this repo

`melos bootstrap` in a repo without melos. `fvm dart` in a repo without FVM. `mcp__<prefix>-dart__*` in a repo where the MCP isn't installed. **Fix:** every command in the table is run-verified before landing the edit; cross-check against §"Toolchain canon" and §"MCP assumption" in the architecture doc.

### Long CLAUDE.md (>~300 lines)

Content has leaked from references. Top-of-context budget is finite; bloating CLAUDE.md pushes useful context out. **Fix:** scan the longest section; if it's not inventory/routing, move it to a skill reference and replace with a one-line pointer.

### Repeating the architecture doc

CLAUDE.md isn't the place to re-explain rejected alternatives or reversal criteria. The §"Architecture decisions" section is one paragraph pointing at the architecture doc, not a summary (`production-repo-C/CLAUDE.md:87-89`).

## See also

- [layer-model.md](layer-model.md) - the two-layer model the `## Foundation` paragraph refers to
- [agent-roster.md](agent-roster.md) - the standard four, mirrored in §"Agents"
- [skill-design.md](skill-design.md) - applicability scopes, mirrored as the §"Skills inventory" Applicability column
- [slash-commands.md](slash-commands.md) - 3-base + additions, mirrored in §"Slash commands"
- [enforcement-hooks.md](enforcement-hooks.md) - hook scripts and modes referenced from §"Hooks & Enforcement"
- [architecture-doc.md](architecture-doc.md) - the decision log; CLAUDE.md mirrors its §2 / §4 / §6 inventories
- [settings-json.md](settings-json.md) - the file CLAUDE.md cross-links from §"Hooks & Enforcement"
- [bootstrap-procedure.md](bootstrap-procedure.md) - Phase 5 (CLAUDE.md trim) + Phase 6 (AGENTS.md symlink)
- [evolution-and-drift.md](evolution-and-drift.md) - updating inventory tables as the layer evolves; AGENTS-as-copy, long CLAUDE.md, stale routing rows
- Inline template: [`../templates/CLAUDE.md`](../templates/CLAUDE.md) - canonical shape to copy and substitute
- Inline template: [`../templates/AGENTS.md`](../templates/AGENTS.md) - real symlink → `CLAUDE.md`, preserve as symlink when copying
- Inline template map: [`../templates/TEMPLATES.md`](../templates/TEMPLATES.md) - target paths + substitutions
