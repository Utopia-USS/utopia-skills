---
name: utopia-ai-arch
description: >
  Create and maintain the Claude Code `.claude/` layer in Utopia Flutter projects -
  agents, skills, slash commands, enforcement hook scripts (PostToolUse /
  SessionStart), settings.json permissions, `.claude/refs/`, CLAUDE.md / AGENTS.md,
  and the `claude-architecture.md` decision log. Applies when bootstrapping a
  repo's AI architecture, adding or editing a skill / agent / slash command /
  hook script, recording a rejected alternative, auditing the layer for drift,
  splitting or graduating skill content, or diagnosing why the agent keeps
  forgetting or losing a project convention. Encodes the project-claude-layer
  blueprint plus invariants distilled from multiple production `.claude/` layers
  in Utopia repos. Layered on top of the upstream `utopia-hooks` plugin - stays
  silent on Flutter hook idioms / Screen-State-View / Dart conventions, and does
  NOT apply to writing Flutter app code itself (foundation concerns).
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: claude-code, ai-architecture, agents, skills, blueprint, project-layer, hooks, flutter
---

# utopia-ai-arch - Project `.claude/` Layer

## Overview

Holistic guide for the **AI architecture** of a Utopia Flutter project - everything under `.claude/` plus `CLAUDE.md` / `AGENTS.md`. Two layers: the **foundation** (the `utopia-hooks` plugin, ambient, repo-agnostic) and the **project** (your repo's `.claude/`, only what exists because of *this* project's domain, topology, and workflow). This skill teaches the project layer - how to **create** it from the blueprint, **maintain** it as the repo evolves, and avoid the drift modes that have actually happened in production repos.

Project skills cross-link to foundation references; they never restate foundation content. A skill whose description matches every Dart file but only adds project-specific content is a router-in-disguise - split or merge until each skill has a real positive AND negative scope.

## When to Apply

- Bootstrapping `.claude/` in a new Utopia repo
- Adding a new skill, agent, slash command, hook script, or `.claude/refs/` entry
- Editing an existing agent prompt, SKILL.md, or `claude-architecture.md`
- Reviewing whether a proposed agent / skill / command should exist at all
- Splitting a skill, graduating a memory entry into a reference, or deleting a stale skill
- Recording a rejected alternative or a new toolchain canon decision
- Auditing the layer for drift (`/<prefix>-audit-skills` style scans)
- Diagnosing why the agent keeps losing a convention while developing the project

## References

Full documentation with verbatim file skeletons and quoted invariants in [references/][references]:

| File | Impact | What it covers |
|------|--------|-------------|
| [layer-model.md][layer-model] | CRITICAL | Two-layer model, foundation-vs-project boundary, `.claude/refs/` vs `.claude/docs/` discipline |
| [agent-roster.md][agent-roster] | CRITICAL | 4-agent blueprint (architect / maintainer / reviewer / precommit-auditor), invariants per role, hand-off chain, frontmatter shape, when to add domain auditors or per-area maintainers |
| [skill-design.md][skill-design] | CRITICAL | Positive+negative applicability, no-router/no-shared rules, when to split a skill, primitive sister skills, `.claude/refs/` cross-link discipline, 3 reference styles (module / pattern / cheatsheet), graduation gradient |
| [enforcement-hooks.md][enforcement-hooks] | CRITICAL | `<prefix>_quality_check.sh` shape (contract / guards / generated-file block / path nudges / mode env var), `<prefix>_skills_drift.sh` shape, SessionStart hook criteria, why NO push-guard |
| [evolution-and-drift.md][evolution-and-drift] | CRITICAL | Operations on a live layer (graduate / split / collapse / delete a skill, add/remove path nudges, add a domain auditor mid-project) paired with the 21-symptom drift catalogue from production. Triggers for re-reading the architecture doc + audit grep one-liners |
| [slash-commands.md][slash-commands] | HIGH | 3-base commands (/implement, /audit, /audit-skills), implement-loop shape with retry cap = 2, never-commit/never-push, when to add `/plan` `/team` `/design` `/ship` |
| [architecture-doc.md][architecture-doc] | HIGH | `.claude/docs/claude-architecture.md` 9-section spine, rejected-alternative 4-field entry shape, toolchain canon, MCP-assumption rules |
| [claude-md.md][claude-md] | HIGH | What belongs in `CLAUDE.md` (always-loaded inventory) vs deep content (references), table shapes, `AGENTS.md` symlink convention and rationale |
| [bootstrap-procedure.md][bootstrap-procedure] | HIGH | Step-by-step "create the Claude layer for a new repo" - what to gather first, 7-step apply, validation checklist |
| [settings-json.md][settings-json] | MEDIUM | Canonical settings.json shape: `extraKnownMarketplaces`, `enabledPlugins`, `permissions.allow` (why git push is OFF), `hooks.PostToolUse` matcher, MCP wiring |

**Templates** for bootstrapping a new repo's `.claude/` layer live in [`templates/`][templates]; the map of what-goes-where + placeholder vocabulary is in [`templates/TEMPLATES.md`][templates-readme]. Read [`bootstrap-procedure.md`][bootstrap-procedure] before applying - Phase 0 (Gather) and Phase 1 (Design the skill split) come BEFORE any file copy.

## Quick Reference

Pointer-paragraph per critical area. Follow the link for the contract; don't extrapolate from the summary.

### Two-layer model → [layer-model.md][layer-model]

Foundation = `utopia-hooks` plugin (ambient, marketplace-installed, repo-agnostic). Project = `.claude/` in the repo (only domain / topology / workflow concerns). Project references foundation, never duplicates. `.claude/refs/` = content for the agent; `.claude/docs/` = meta about the layer - never mix.

### Agent roster → [agent-roster.md][agent-roster]

Four standard agents: `<prefix>-architect` (read-only planner), `<prefix>-maintainer` (write, only writer), `<prefix>-reviewer` (read-only post-impl review, output BLOCKER/WARN/NIT), `<prefix>-precommit-auditor` (read-only staged-diff gate). Each agent preloads `[<prefix>-<master-skill>, utopia-hooks]`. Domain auditor only with incident or threat-surface justification; per-area maintainers rejected unless ≥3-area PRs are routine.

### Skill design → [skill-design.md][skill-design]

Every skill needs positive AND negative applicability. "Cross-cutting" or "shared" is not a scope. Three reference styles: **module** (user-flow + business intent), **pattern** (rules with reasoning, why-first), **cheatsheet** (inventory tables). Graduation gradient: memory → `references/<feature>-module.md` → own skill. Reversible.

### Enforcement hooks → [enforcement-hooks.md][enforcement-hooks]

`<prefix>_quality_check.sh` is a PostToolUse hook on `Edit|Write|MultiEdit`. Contract: exit 0 silent, exit 1 warn, exit 2 block. Generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.pb*.dart`, `*.config.dart`) ALWAYS exit 2 regardless of mode. Guards prove scope (jq, .dart, pubspec, repo basename) BEFORE any nudging.

### Evolution & drift → [evolution-and-drift.md][evolution-and-drift]

The pillar this skill exists for. Operations on a live layer paired with the 21-symptom drift catalogue. Re-read `claude-architecture.md` before acting when: new techstack, new MCP, new external integration, recent incident, or a roster proposal.

## Diagnostic routing - when the agent is acting wrong

| Symptom | Start with |
|---------|------------|
| Agent loses conventions developing the project | [evolution-and-drift.md][evolution-and-drift] |
| A skill no longer fires / fires on the wrong files | [skill-design.md][skill-design] + [evolution-and-drift.md][evolution-and-drift] (symptom L) |
| `dart_fix` keeps bulldozing the user's WIP | [evolution-and-drift.md][evolution-and-drift] (symptom G) |
| Generated-file edits keep slipping through | [enforcement-hooks.md][enforcement-hooks] (hard-block contract) |
| MCP server referenced in agents but not installed | [evolution-and-drift.md][evolution-and-drift] (symptom P) + [settings-json.md][settings-json] |
| Worktrees silently producing no-op Dart edits | [evolution-and-drift.md][evolution-and-drift] (symptom H) |
| Stale `dart mcp-server` processes accumulating memory | [enforcement-hooks.md][enforcement-hooks] (SessionStart criteria) |
| Reviewer accepting blockers that don't cite a rule | [agent-roster.md][agent-roster] (reviewer invariants) |
| Hook never fires / fires in an unrelated repo | [enforcement-hooks.md][enforcement-hooks] (Scope guards) + [bootstrap-procedure.md][bootstrap-procedure] (validation checklist) |
| Skill `references/` accumulating cross-cutting content | [evolution-and-drift.md][evolution-and-drift] (symptom A) |
| "Should we add a `<prefix>-shared` skill?" / "a `git push` guard?" / "a 5th agent?" | [skill-design.md][skill-design] / [enforcement-hooks.md][enforcement-hooks] / [agent-roster.md][agent-roster] (each says NO - read why) |

For non-diagnostic lookups (adding a new skill / agent / command / hook, editing CLAUDE.md or the architecture doc), the References table above maps directly.

[references]: references/
[templates]: templates/
[templates-readme]: templates/TEMPLATES.md
[layer-model]: references/layer-model.md
[agent-roster]: references/agent-roster.md
[skill-design]: references/skill-design.md
[enforcement-hooks]: references/enforcement-hooks.md
[evolution-and-drift]: references/evolution-and-drift.md
[slash-commands]: references/slash-commands.md
[architecture-doc]: references/architecture-doc.md
[claude-md]: references/claude-md.md
[bootstrap-procedure]: references/bootstrap-procedure.md
[settings-json]: references/settings-json.md

## Non-Negotiable Rules (cross-cutting; ref files carry the rest)

- **Project references foundation, never duplicates.** Cross-link via `utopia-hooks:references/<file>.md`.
- **No router skill.** Routing is CLAUDE.md (always-on) + quality-check hook (deterministic path nudge) + per-skill description (probabilistic). A skill that "routes" to other skills loses both ways.
- **Every skill needs positive AND negative applicability.** Can't write the negative scope → it's a router; split or merge.
- **Maintainer is the only write-capable agent.** Reviewer, architect, precommit-auditor, domain auditors are read-only. Compromising this collapses the code↔review loop.
- **Reviewer runs on fresh context.** `/<prefix>-implement` withholds the maintainer's self-report. Don't leak reasoning across the boundary.
- **Retry cap = 2.** Maintainer → reviewer → maintainer → reviewer. Still failing? Hand both reports to the user. Scope stays constant across retries.
- **/implement never commits, never pushes.** Commit gate is `/<prefix>-audit`.
- **Generated files hook-blocked (exit 2, regardless of mode).** Always blocked. Regenerate via build_runner; never edit.
- **Prefix ≠ repo-folder-name; basename guard uses repo-folder-name.** Hook's `basename "$repo_root"` match MUST use the on-disk folder (e.g. `production-repo-A`), not the prefix (e.g. `<prefix>`). Otherwise the hook silently never fires.
- **No `git push` guard hook.** `permissions.allow` deliberately omits `git push` (every push prompts), GitHub branch protection covers the remote. Reintroduce only if a repo lacks both layers.
- **`AGENTS.md` is a symlink to `CLAUDE.md`.** Single source of truth. Hard links don't survive git; copies drift silently.
- **Don't reference an MCP server that isn't installed.** Allowlist pollution + agent prompts confused by absent tools.
- **Rejected alternatives section pays for itself.** Every removed/considered design choice gets the 4-field entry. Future-you re-litigates without it.
- **Comments respond to the code, not the prompt.** No `// Added per user request`, no `// FIXME from review feedback`, no `// AI-generated …`.

## Self-Audit (run after any `.claude/` change)

The diagnostic checklist is concentrated in [evolution-and-drift.md][evolution-and-drift] §"Self-audit checklist". The high-leverage 5 to verify before commit:

1. Does this artefact have a real positive AND negative applicability? → If not, it's a router-in-disguise.
2. Does it restate foundation conventions (Screen/State/View, hooks, IList rules)? → Move to cross-links into `utopia-hooks`.
3. Does a new path nudge match the surfaced skill's applicability EXACTLY and point at ≥2 references? → If not, the nudge surfaces wrong / no content.
4. Does `CLAUDE.md`'s inventory match `.claude/skills/` + `.claude/agents/` + `.claude/commands/` listings? → Run `/<prefix>-audit-skills`.
5. Does `claude-architecture.md` reflect the change (Skill split / Agent roster / Slash commands / Rejected alternatives - whichever applies)? → Update §Rollout status; if a rejected alternative was reversed, flip in place.

## Companion Plugins

- **[utopia-hooks](https://github.com/Utopia-USS/utopia-flutter-skills)** - the foundation this layer assumes. Always installed alongside.
- **[utopia-hooks-migrate-bloc](https://github.com/Utopia-USS/utopia-flutter-skills)** - orchestrated BLoC → utopia_hooks migration. Independent surface; not part of `.claude/` AI architecture.

## Attribution

Distilled from production `.claude/` layers across multiple Utopia Flutter repos. Built by UtopiaSoftware.
