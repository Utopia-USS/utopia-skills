---
title: Agent Roster - The Blueprint Four (and When to Extend)
impact: CRITICAL
tags: agents, architect, maintainer, reviewer, auditor, roster, prompt-style
---

# Agent Roster - The Blueprint Four (and When to Extend)

## What this is

Every Utopia project ships **exactly four standard agents**, named with the repo prefix. One write-capable implementer; three read-only postures. This is the blueprint. Departures from it (a fifth agent, per-area maintainers, posture-only rosters) require documented justification - they have been tried and rejected enough times that "let's add an agent" is the wrong default.

```
┌──────────────────┐    plan     ┌──────────────────┐    diff     ┌──────────────────┐
│ <prefix>-        │────────────►│ <prefix>-        │────────────►│ <prefix>-        │
│  architect       │             │  maintainer      │  fresh ctx  │  reviewer        │
│  (read-only)     │◄────────────│  (WRITE - only)  │             │  (read-only)     │
└──────────────────┘  retry ≤ 2  └──────────────────┘             └──────────────────┘
                                                                            │
                                                                  user      ▼
                                                              ┌──────────────────┐
                                                              │ <prefix>-        │
                                                              │  precommit-      │
                                                              │  auditor         │
                                                              │  (read-only)     │
                                                              └──────────────────┘
```

## When this applies

- Adding, removing, or renaming an agent
- Editing an agent prompt (frontmatter or body)
- Recording an agent decision in `claude-architecture.md` §"Agent roster"
- Designing the orchestration shape of a new slash command (`/<prefix>-implement`-class) - see [slash-commands.md](slash-commands.md)
- Reviewing an agent invocation for scope violations (architect implementing, reviewer editing, etc.)

## The four standard agents

### 1. `<prefix>-architect` - Planner (read-only)

| Field | Value |
|-------|-------|
| Tools | `Read, Grep, Glob, Bash` |
| Skills (frontmatter) | `[<prefix>-<master-skill>, utopia-hooks]` (plus domain skills when relevant) |
| Model | `inherit` |
| Invoked when | A change touches more than one skill's applicability scope, changes a shared contract (proto / schema / public API), or adds a new code-gen surface |
| Output | A scoped plan: affected files, affected skills, decision points |

**Invariants:**

- "You plan; you do not implement." - never edit code.
- "Every chunk must name the skill whose `applicability` it falls into. If no skill applies, that's a finding - escalate, don't invent one." (blueprint `REPO-architect.md` §Invariants)
- Explicit prohibition on inventing skills or proposing a "shared" / router skill.
- Hand-off: produces a spec → main context or `<prefix>-maintainer` executes; stops at the plan boundary.

### 2. `<prefix>-maintainer` - Implementer (the only writer)

| Field | Value |
|-------|-------|
| Tools | Default (`Read, Edit, Write, MultiEdit, Grep, Glob, Bash`) |
| Skills (frontmatter) | `[<prefix>-<master-skill>, utopia-hooks]` (plus the consumed skills for the area) |
| Model | `inherit` |
| Invoked when | Implementing an architect plan or a scoped task. Used by `/<prefix>-implement`. |
| Hand-off | To `<prefix>-reviewer` for post-implementation review |

**Invariants:**

- "After each logical change set: run static analysis. Block on errors (do not continue with red analyzer)." (blueprint `REPO-maintainer.md` §Invariants)
- "Surface blockers back to the planner; do not invent design decisions."
- "Generated files … are regenerated, not edited. The hook hard-blocks edits - do not work around it."
- "Stay within the architect's scope. If a change requires touching surfaces outside the plan, surface it instead of expanding silently."
- **Reviewer-facing rule:** "If you find yourself writing 'the reviewer should be OK with this because X', that X belongs in the code or in a warning, not as a hint to the reviewer." (`production-repo-B/.claude/agents/<prefix>-maintainer.md:225-227`)
- **`dart_fix` discipline:** never run `mcp__<prefix>-dart__dart_fix` project-wide as a mandatory step. It bulldozes the user's WIP. Run only on a narrow set of files in the change.

**Self-report shape - REQUIRED, parsed by `/<prefix>-implement`** (handed to the main context - NOT to the reviewer):

```
## status        - success / partial / needs_human
## files_touched
## commit_message_draft
## analyze       - baseline / current / delta
## output_hygiene - debug prints, scaffolding, AI-cruft comments stripped
## regen         - codegen ran (yes/no); files
## warnings      - caveats for the user
## out_of_scope_observations  - for the main context only, NOT the reviewer
```

> "When `/<prefix>-implement` invokes the reviewer, it withholds this self-report on purpose - the reviewer must verify the diff from scratch, not from your reasoning." (`production-repo-B/.claude/agents/<prefix>-maintainer.md:222-227`)

**This is a contract, not a suggestion.** The orchestrator slash command (`/<prefix>-implement`) parses these section headers to (a) extract `files_touched` + `commit_message_draft` + `analyze` for the reviewer's fresh-context input, and (b) surface `warnings` + `out_of_scope_observations` to the user. A maintainer that returns free-form prose breaks the loop. Production precedents: `production-repo-B/.claude/agents/<prefix>-maintainer.md:192-220`, `production-repo-C/.claude/agents/<prefix>-maintainer.md:99-129`. The maintainer template at [`../templates/claude-layer/agents/REPO-maintainer.md`](../templates/claude-layer/agents/REPO-maintainer.md) includes this block - preserve it verbatim during substitution.

### 3. `<prefix>-reviewer` - Post-implementation reviewer (read-only)

| Field | Value |
|-------|-------|
| Tools | `Read, Grep, Glob, Bash` |
| Skills (frontmatter) | `[<prefix>-<master-skill>, utopia-hooks]` (plus consumed-area skills) |
| Model | `inherit` |
| Invoked when | After maintainer hand-off (step 4 of `/<prefix>-implement` loop) |
| Inputs received | `files_touched`, `proposed_commit_message`, `baseline_analyze` - and nothing else from the maintainer |
| Output | Classified list: `BLOCKER`, `WARN` (written `SHOULD-FIX` in some repos), `NIT` |

**Invariants:**

- Read-only: "Do not edit product code." (`production-repo-B/.claude/agents/<prefix>-reviewer.md:111-112`)
- **Blockers must cite a skill rule.** "If you cannot point to a non-negotiable rule in `<prefix>` or `utopia-hooks`, downgrade to WARN." (`production-repo-B/.claude/agents/<prefix>-reviewer.md:123-124`)
- "Do not invent fixes that aren't grounded in a skill or foundation rule."
- "Do not duplicate the precommit auditor's job - your scope is correctness and convention, not commit-readiness hygiene."
- **Independence is the reviewer's only superpower** - does not see the maintainer's self-report, reasoning, or warnings.

### 4. `<prefix>-precommit-auditor` - Commit-readiness gate (read-only)

| Field | Value |
|-------|-------|
| Tools | `Read, Grep, Glob, Bash` |
| Skills (frontmatter) | `[<prefix>-<master-skill>, utopia-hooks]` |
| Model | `inherit` |
| Invoked when | Via `/<prefix>-audit` immediately before `git commit` |
| Inputs | `git diff --staged` ONLY |
| Output | `COMMIT-OK` / `COMMIT-FIX-FIRST` / `COMMIT-BLOCK` (variants: READY / NEEDS FIX / BLOCKED) |

**What it checks:**

- Debug artifacts (`print`, `console.log`, fresh `TODO(self)`)
- Generated-file edits leaking past the hook
- Package-import violations
- Skill-specific naming (e.g. domain entity codes, `*Ref` suffixes)
- Scaffolding comments (`// placeholder`, `// TODO ai`)
- AI-cruft comments (see [evolution-and-drift.md](evolution-and-drift.md))
- Formatter regressions
- `CLAUDE.md` / `.claude/docs/` drift - skill table internally consistent

**What it explicitly does NOT check:**

- Correctness, regressions, test coverage → reviewer's job
- Architecture / cross-skill impact → architect's job

## Frontmatter shape (canonical)

```yaml
---
name: <prefix>-<role>
description: |
  <one-line WHEN to invoke - not WHAT I am>
tools: Read, Grep, Glob, Bash   # omit for maintainer (default = write-enabled)
skills:
  - <prefix>-<master-skill>
  - utopia-hooks
  - <other-domain-skill>        # when relevant to the agent's posture
model: inherit
---
```

**Why `skills:` preloading.** Frontmatter-loaded skills are in the agent's system prompt from the start - not subject to description matching. This is why all four agents preload `<prefix>` master + `utopia-hooks` deterministically.

**Why `model: inherit`.** The agent runs at whatever model the user's session uses (Opus, Sonnet). Lets you upgrade by changing one place, never the agents.

## Description-as-router

> "Description as router. Frontmatter `description` is the only signal for auto-invocation - written as *WHEN to apply*, not *WHAT I am*." - `production-repo-A/.claude/docs/claude-architecture.md:67-70`

❌ `description: "Reviews code for correctness and conventions."` (WHAT)
✅ `description: "Use after maintainer completes a change set - diff review against <prefix> + utopia-hooks rules; produces BLOCKER / WARN / NIT."` (WHEN)

The description has to be precise enough that the main context auto-delegates correctly when "review this change" comes up, and silent when it shouldn't.

## When to extend the roster

The default is **four**. Adding a fifth agent requires a written justification in `claude-architecture.md` §"Agent roster".

### Add a domain auditor (`<prefix>-<domain>-auditor`) WHEN:

- The project's primary risk surface is **crypto, native FFI, RLS / multi-tenant data isolation, push-payload confidentiality, or auth**
- AND there's a recent incident OR a documented threat-surface rationale that says "the standard reviewer doesn't catch this"

**Precedent (DO add):** repo-A's `<prefix>-security-auditor` for security-sensitive code - native crypto FFI, key-exchange primitives, row-level-security bypass risk. The four standard agents all route to it for security-sensitive paths (it's the 5th, added on top of the standard roster). (`production-repo-A/.claude/docs/claude-architecture.md:121`)

**Precedent (DO NOT add):** repo-B and repo-C both considered domain auditors and rejected them. "No recent incident has cost enough to warrant a dedicated read-only pass. The standard reviewer + precommit auditor cover these surfaces today." (`production-repo-B/.claude/docs/claude-architecture.md:148-152`)

**Reversal criterion:** A real cost-bearing incident, or a clearly-out-of-scope audit checklist that the reviewer can't carry without bloating its prompt.

### Do NOT add per-area maintainers (e.g. `<prefix>-phone-maintainer`, `<prefix>-backend-maintainer`) UNLESS:

- ≥3-area PRs in a single branch are **routine**, not occasional
- AND the parallelism payoff outweighs the description-matching noise across a larger roster

**Precedent (rejected):** repo-A tried four per-area maintainers (`<prefix>-area1-maintainer`, `<prefix>-area2-maintainer`, `<prefix>-area3-maintainer`, `<prefix>-area4-maintainer`). Reverted.

> "Typical work is ticket-scoped and single-area. … Parallelism payoff triggers on a small fraction of tasks, while the cost - noisier description-matching across a larger roster, heavier `/<prefix>-team` protocol, higher onboarding surface, more to audit for drift - is paid on every turn." - `production-repo-A/.claude/docs/claude-architecture.md:222-223`

**The "parallel" alternative without splitting maintainers:** batch multiple `Agent` calls to `<prefix>-maintainer` in a single assistant message - one per disjoint chunk. The architect's plan splits the work; the orchestrator fans out.

### Do NOT add posture-only rosters (no write-capable maintainer).

The code↔review loop *requires* a write side. Removing the maintainer to make every Agent invocation predictable breaks the orchestration model and forces ad-hoc `general-purpose` subagents that lack preloaded skills.

> "Ad-hoc `general-purpose` subagents work but lack preloaded domain skills, so each invocation pays a context warm-up cost the blueprint avoids by design." - `production-repo-A/.claude/docs/claude-architecture.md:227-231`

### Do NOT add hygiene / doc-drift / "eng-manager" agents.

The primary failure mode (dead links, stale SKILL.md) is caught **deterministically** by `<prefix>_skills_drift.sh` + `/<prefix>-audit-skills`. A probabilistic agent is strictly weaker than a script that always runs.

> "A probabilistic agent is strictly weaker than a script that always runs." - `production-repo-A/.claude/docs/claude-architecture.md:244`

### Do NOT add release-playbook agents for low-cadence procedures.

Agent cost amortizes over too few invocations. Write a playbook skill loaded on demand.

## Agent body - common sections

Every agent body, in this order:

1. **One-paragraph framing** - what this agent does, not what it is.
2. **Tools** - list (or "default" for maintainer).
3. **Scope (positive / negative)** - when this agent runs vs when it doesn't.
4. **Inputs / outputs** - what it accepts, what it produces.
5. **Hand-offs** - who it calls next, what shape of message.
6. **Invariants** - rules it must follow; rules it must NOT violate.
7. **Comment style** (maintainer + reviewer + auditor only) - see "Comment-style block" below.
8. **Anti-patterns** - known failure modes.

## Comment-style block (maintainer / reviewer / auditor)

The repo-A and repo-B maintainers inline a comment-style section. It is repeated in the reviewer and precommit-auditor to make the rule independently enforceable. Verbatim core rules:

- "If the comment wouldn't make sense to a reader who has never seen this conversation, PR, or review thread - delete it." (`production-repo-A/.claude/agents/<prefix>-maintainer.md:188-189`)
- Always-bad examples (treat as BLOCK in review): `// Added per user request for <TASK-ID>`, `// FIXME from the review feedback`, `// This handles the case where Ben mentioned in Slack`, `// Removed the bool flag - see commit`, `// AI-generated layout for the new flow`.
- Inline `//` for genuine WHY (subtle invariants, workarounds for specific bugs); `///` for public API doc comments; never for narrating WHAT the code does or referencing the prompt.

## Anti-patterns

(Cross-layer drift - reviewer leakage from maintainer self-report, slash-wrapping a single agent, per-area maintainers, AI-cruft comments - lives in [evolution-and-drift.md](evolution-and-drift.md) §K, §R, §D, §J. Below: roster-specific.)

### Architect implementing

The architect plans. If you find an architect's plan returns "I made the changes," the agent's scope is broken. Read-only tools (`Read, Grep, Glob, Bash`) enforce this at the tool level.

### "Just one more agent" creep

Each agent adds description-matching noise. Every new agent should have a §"Agent roster" entry in `claude-architecture.md` justifying its existence. If you can't write the justification, the agent shouldn't exist.

### Frontmatter without `model: inherit`

Hard-coding `model: opus` means the user can't downgrade to sonnet for cost. The standard is `inherit`.

### Description that explains what the agent IS

`description: "A reviewer agent for the codebase."` is not a router signal - the main context can't decide when to delegate. Use WHEN ("Use after maintainer completes a change set …").

## See also

- [slash-commands.md](slash-commands.md) - `/<prefix>-implement` retry cap and fresh-context discipline
- [skill-design.md](skill-design.md) - applicability scopes referenced by `skills:` frontmatter preload
- [architecture-doc.md](architecture-doc.md) - §"Agent roster" entry shape; §"Rejected alternatives" entries for per-area maintainers and eng-manager
- [evolution-and-drift.md](evolution-and-drift.md) - AI-cruft comments, `dart_fix` bulldoze, reviewer-leakage drift modes; when to graduate a domain auditor mid-project
