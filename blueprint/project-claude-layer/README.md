# project-claude-layer — blueprint

Opinionated shape for a project's `.claude/` layer that sits on top
of the `utopia-hooks` foundation plugin. Internal blueprint, distilled
from concrete iterations on production monorepos and the trade-offs
that surfaced between them.

> **This is a blueprint, not a literal template.** You read the
> model, design your repo's skill split, and copy *the shapes* of
> files — not the files themselves verbatim. Skills, applicability
> scopes, references, and the architecture decision log are all
> per-repo work. Mechanical apply doesn't substitute for the
> architectural decision of how to slice your repo.

What gets copied vs what stays in the blueprint:

| Stays in blueprint (referenced, never copied) | Copied per-repo (adapted) |
|---|---|
| `README.md` (this file — the model) | `CLAUDE.md` (renamed, filled in) |
| `conventions/*.md` (authoring guides for module/pattern/cheatsheet) | `AGENTS.md` (symlink to CLAUDE.md) |
| `.claude/refs/README.md` (discipline doc for what goes in `.claude/refs/`) | `.claude/docs/claude-architecture.md` (per-repo decision log) |
| | `.claude/agents/*` (with `<repo>` replaced) |
| | `.claude/commands/*` (with `<repo>` replaced) |
| | `.claude/scripts/*` (with `<repo>` replaced) |
| | `.claude/settings.json` |
| | `.claude/skills/<repo>-<area>/...` (per-repo design) |
| | `.claude/refs/` (empty directory; you populate as cross-skill needs emerge) |

The repo's `.claude/docs/claude-architecture.md` records which
reference styles each skill uses and links **into the blueprint** for
the authoring guides — it does not copy them. One source of truth, no
drift between repos.

**The whole AI architecture lives under `.claude/`.** That includes
`.claude/docs/` (decision log, authoring helpers) and `.claude/refs/`
(cross-skill shared markdown). The repo-root `docs/` directory
remains free for genuinely non-Claude project documentation
(architecture diagrams, deployment runbooks, etc.) — orthogonal to
the AI layer. Earlier blueprint revisions placed `docs/` and `refs/`
at the repo root; that split made the AI architecture non-self-
contained and conflated agent-only meta with project-wide docs.

---

## 1. Two layers, hard separation

```
+---------------------------------------------------------------+
|  Foundation — utopia-hooks plugin                             |
|    Enablement: declared in repo's .claude/settings.json       |
|      (project scope — travels with the repo).                 |
|    Content: cached by CLI under ~/.claude/plugins/ (per user).|
|    Universal idioms: Screen/State/View, hooks, async, DI,     |
|    IList/IMap/ISet, strict analyzer, hook testing.            |
|    Repo-agnostic content. Knows nothing about your project.   |
+---------------------------------------------------------------+
                           ▲ referenced, never duplicated
+---------------------------------------------------------------+
|  Project — this repo's .claude/ (lives in the monorepo)       |
|    Owns concerns that exist only because of THIS project's    |
|    domain, topology, and team workflow.                       |
+---------------------------------------------------------------+
```

Project skills cross-link to foundation references; they never
restate foundation content.

---

## 2. Three independent routing mechanisms

There is no "router skill". Routing is solved by three complementary
mechanisms that already exist in the meta-model:

| Mechanism | Where | Always-on? | Best for |
|---|---|---|---|
| `CLAUDE.md` | Repo root | Yes (top-of-context) | Topology, skills inventory, foundation pointer |
| Hook (path → skill nudge) | `.claude/scripts/*_quality_check.sh` | Fire on tool call | Deterministic surfacing per file path |
| Skill description matching | `SKILL.md` frontmatter | Fire on relevance | Autonomous loading via explicit `applicability` |

Slash commands are added **only** when a workflow is multi-step
orchestration (e.g. code↔review loop). Slash commands are not
aliases to single agents — description matching auto-loads agents
when relevance is clear.

A "router skill" would either fire too broadly (loading itself
*instead* of the domain skill, leaving the agent with a map but no
content) or too narrowly (in which case the inventory belongs in
`CLAUDE.md`, which is always in context). Both cases lose to the
three-mechanism split.

---

## 3. Skill granularity — coherent body of knowledge

A skill is one autonomous unit of project knowledge with:

1. A frontmatter `description` that states **applicability scope** —
   both **positive** (where it applies) and **negative** (where it
   explicitly does NOT).
2. Content cohesive enough to plan or execute work in its scope
   without pulling in other skills as a precondition.
3. References under `references/` for progressive disclosure.

### What a skill is NOT

- **Not per-techstack by default.** Sometimes techstack is a natural
  boundary (Kotlin API ≠ Dart Flutter ≠ Next.js); often it isn't (a
  UI design system used by some apps but not others doesn't decompose
  along techstack lines). Granularity follows **content coherence**,
  not folder structure.

- **Not "cross-cutting" with no real applicability.** A skill whose
  applicability is "everywhere relevant" is a router skill in
  disguise. If you can't write a concrete positive+negative scope,
  the content doesn't belong in a skill — see §4.

- **Not a master + references monolith for the whole repo.** A
  single `<repo>` skill with all references inside competes with
  itself for description matching and forces all-or-nothing context
  loading.

### Master+references *inside* a skill is fine

Within a skill that has a coherent applicability scope (e.g. a
Flutter-heavy area covering activities, design-system, services,
models), `SKILL.md` can act as an internal index for `references/`.
That's progressive disclosure within bounded scope, not a router.

---

## 4. Where shared / cross-cutting content actually lives

The meta-model has **no global-references tier**. Every piece of
content lives in exactly one of three places:

| Location | Discoverability | When |
|---|---|---|
| **`CLAUDE.md`** | Always in context | Topology, skills inventory, foundation pointer, repo-wide commands. Tight — context budget. |
| **A skill's `references/`** | Progressive disclosure within the skill | Content used by exactly that skill. |
| **`.claude/refs/*.md`** | Passive — only loaded when a `SKILL.md` "See also" links to it | Cross-skill snippets too small to be a skill, with no autonomous applicability. |

There is no fourth bucket. In particular:

- No `<repo>-shared/` skill. "Shared" is not an applicability scope —
  it's an admission the skill has no real one. Such a skill loads at
  the wrong times and competes with the skills that consume it.
- No "global references" tier outside `.claude/`. Cross-skill
  markdown lives in `.claude/refs/`, deliberately separate from
  `.claude/docs/` (which holds decisions about the layer and
  per-repo authoring helpers, not content for the agent).
- No mixing of AI-layer meta with general project documentation.
  Repo-root `docs/` remains available for non-Claude docs
  (architecture diagrams, deployment runbooks, etc.) — keep that
  surface independent of `.claude/`.

### Discipline: where the cross-link sits

A cross-link must live **in `SKILL.md` itself**, not deep inside a
reference. `SKILL.md` always loads when the skill matches; references
are doc-on-demand. A buried cross-link is two hops from visibility
and gets lost.

---

## 5. Reference styles — three flavours

Inside a skill's `references/`, every file follows one of three
styles. Pick by asking what the agent needs to *do* with it:

| Suffix | Style | Lead with | Use when |
|---|---|---|---|
| `*-module.md` | Business module | User flow, business intent | Product feature where understanding *why this exists for the user* matters before touching code |
| `*-pattern.md` / `*-system.md` / `*-services.md` / `*-models.md` | Cross-cutting convention | Technical surface — rules, naming, APIs | Repo conventions with no product story |
| `*-cheatsheet.md` / `*-catalogue.md` / `*-map.md` | Flat lookup / catalogue | Inventory tables | Mapping what exists (components, tokens, icons) so the agent reuses instead of reinventing |

Detailed authoring conventions for each style live in
[`conventions/`](conventions/). When in doubt:

- Has a user flow → module.
- Has rules with reasoning → pattern.
- Has an inventory but no rules / flows → cheatsheet.

Module references must follow the **business intent + user flow
first** discipline (don't dump code; reference, don't reproduce).
See [`conventions/module-style.md`](conventions/module-style.md).

---

## 6. Agent roster

Every project gets the same four agents. Domain auditors are added
on a per-repo basis when there's a critical surface that warrants a
dedicated review pass.

| Agent | Role | Read-only? |
|---|---|---|
| `<repo>-architect` | Plans, splits work, identifies affected skills | Yes |
| `<repo>-maintainer` | Implements plans across skills | **No** (write) |
| `<repo>-reviewer` | Post-implementation classified review | Yes |
| `<repo>-precommit-auditor` | Staged-diff commit-readiness audit | Yes |
| `<repo>-<domain>-auditor` | Dedicated audit for critical domain (e.g. security) | Yes — per-repo |

The maintainer is the implementation half of the orchestrated
code↔review loop (`/<repo>-implement`). It is part of the standard
roster, not opt-in: if a repo doesn't want orchestration, it doesn't
invoke `/implement` — but the agent stays available so direct
delegations remain possible without ad-hoc subagent setup.

What the maintainer buys, concretely:

- **Context isolation.** File reads, intermediate analyzer output,
  exploration noise stays in the maintainer's window. Main context
  receives a concise diff.
- **Preloaded skills.** Frontmatter declares `skills:` — those are
  in the system prompt from the start, not subject to description
  matching.
- **Orchestrator coupling.** The code↔review loop has a write side
  by design. Without it the loop becomes a manual protocol that gets
  cut.
- **Parallel fan-out.** Architect can split work across multiple
  maintainer invocations when chunks are disjoint.

---

## 7. Slash commands — only for orchestration

| Command | Purpose |
|---|---|
| `/<repo>-implement` | Code↔review loop (architect → maintainer ↔ reviewer) |
| `/<repo>-audit` | Precommit gate via auditor |
| `/<repo>-audit-skills` | Drift scan over `.claude/**/*.md` |

Plain agent-aliases (`/<repo>-plan` → architect) are not added.
Description matching auto-loads the architect when the user asks for
a plan; the slash adds a layer for no benefit.

---

## 8. Hook — deterministic surface

`<repo>_quality_check.sh` runs on `Edit | Write | MultiEdit`. Two
jobs:

1. **Hard block on generated files** (`*.g.dart`, `*.freezed.dart`,
   `*.pb.dart`, etc.). Always exit 2.
2. **Path → skill nudges.** Map directory patterns to the skill whose
   conventions apply, mirroring each skill's `applicability`. Default
   `warn` (exit 1); `block` (exit 2) switchable via env var.

Plus two siblings:

- `<repo>_git_push_guard.sh` — pre-push branch allowlist.
- `<repo>_skills_drift.sh` — dead-link scan.

Hooks are **guarded**: each script proves it's in scope before doing
anything. Out-of-scope = silent `exit 0`. Foundation and project
hooks coexist without conflict.

---

## 9. `.claude/docs/claude-architecture.md` — decision log

Every repo using this blueprint has one. It documents:

1. **Skill split rationale** — why these skills, why these
   boundaries, why these applicabilities. Per-skill positive+negative
   scope.
2. **Enforcement mode** — warn default, block exceptions.
3. **Agent roster additions** — only domain auditors beyond the
   standard four (architect, maintainer, reviewer, precommit-auditor).
4. **Rejected alternatives** — designs that were considered and not
   taken, each with: alternative, case for, case against here,
   reversal criterion.

The Rejected alternatives section pays for itself. It's why future-you
doesn't re-litigate decisions, and why someone new can tell a
deliberate omission from an oversight.

---

## 10. Graduation gradient — how content matures

WIP content moves through a pipeline as it stabilises:

```
project memory (WIP vertical)
    ↓ vertical crystallises into a stable shape
references/<feature>-module.md (in the closest applicable skill)
    ↓ module grows beyond the skill's applicability
own skill (with explicit applicability scope)
```

Reverse is also valid: a skill that turned out to apply only to one
area collapses back into a `*-module.md` reference there.

---

## 11. Multi-platform agent files

Different agentic tools look for their context file under different
names (`CLAUDE.md` for Claude Code, `AGENTS.md` for Codex / OpenAI's
convention, others may follow). Maintaining duplicate files invites
drift — exactly the situation jolly currently has, where `AGENTS.md`
went stale relative to `CLAUDE.md` because they were independent
copies.

**Solution: one physical file, multiple paths via symlink.**

In the blueprint, `AGENTS.md` is a symlink to `CLAUDE.md`. When you
copy these into a new repo, the symlink survives — edit `CLAUDE.md`,
and the agent that reads `AGENTS.md` sees the same update.

Why symlink rather than hard link: **git preserves symlinks**
natively (as a special blob type). After clone, the symlink
re-creates itself pointing at the target. Hard links — which is
what jolly uses for `proto/classroom/classroom_data.proto` ↔
`core/proto/classroom_data.proto` — are not preserved by git;
they require a setup script and post-checkout hook to re-create
locally, and a clone gets two independent files that drift.

For agent-context files which are committed and shared, symlink
is the cleaner mechanism.

### Windows note

Symlinks on Windows require Developer Mode enabled (or admin
privileges) for `git checkout` to materialise them. If a contributor
ends up with a plain text file containing the path string instead
of a working symlink, they need to enable Developer Mode and re-run
`git checkout HEAD -- AGENTS.md`.

For repos with mixed-OS contributors where this is friction, fall
back to a `.claude/scripts/setup-agent-files.sh` that creates the
link locally, paired with a `post-checkout` hook. The blueprint
ships with the symlink — add the script only if needed.

### Cursor IDE — skill discovery

Cursor 3 (April 2026) ships native skills using the same `SKILL.md +
frontmatter (name, description)` format as Claude Code. Cursor's
default scan path is `.cursor/skills/<name>/SKILL.md`; it does **not**
read `.claude/skills/` automatically.

For Cursor users on a Claude-first repo, the cleanest single-source-
of-truth recipe is a directory symlink:

```
.cursor/skills → ../.claude/skills
```

Both clients read the same files. Rules (`.cursor/rules/*.mdc`) and
their long-form docs (`.cursor/docs/`) become redundant — their
content already lives in `.claude/skills/<area>/references/`.

**Don't commit this symlink.** Reasons:

- Windows clients without symlink support get a regular file
  containing the literal path string — Cursor sees a 18-byte file,
  not a directory, and silently fails to discover any skills.
- A committed symlink is one more thing to drift if the target
  layout changes — recreating it from a bootstrap script keeps the
  recipe in one place.

Recipe:

```gitignore
# .gitignore
.cursor/skills
```

```yaml
# whatever bootstrap your repo runs (melos, npm postinstall, make setup)
post: '[ -e .cursor/skills ] || ln -s ../.claude/skills .cursor/skills'
```

`.cursor/mcp.json` (Cursor-specific MCP server config) is unrelated
and stays committed. If you add Cursor subagents later, the same
recipe applies to `.cursor/agents → ../.claude/agents`.

**Verification (ask in Cursor after `bootstrap`):**
> "What do you know about \<one of your skill domains\>?"

A specific answer naming symbols from the referenced module ⇒ symlink
followed and skills discovered. A generic answer ⇒ Cursor didn't
follow the symlink; invert the direction (physical dir at
`.cursor/skills/`, symlink from `.claude/skills/`).

---

## 12. How to apply the blueprint to a new repo

This is not a `cp -r`. The blueprint is a model; applying it is a
short architectural exercise plus mechanical copying of file shapes.

1. **Read sections 1–10.** Especially §3 (skill granularity), §4
   (where shared content lives), §5 (reference styles), §6 (agent
   roster). These are the decisions you're about to make.

2. **Design your skill split.** What are the coherent bodies of
   knowledge in this repo? For each one, write a positive applicability
   scope and a negative applicability scope. If you can't write the
   negative scope, the skill is trying to be a router — split or
   merge until each skill has a real boundary.

3. **Draft `.claude/docs/claude-architecture.md`.** Fill in §2 (skill split
   table), §3 (which reference styles each skill will use), §8
   (rejected alternatives — what you considered but didn't pick).
   This is where the architectural decisions live.

4. **Copy the file shapes into your repo.** Working from the
   blueprint:

   ```bash
   # Files that come over (paths relative to your repo root):
   CLAUDE.md                              ← from blueprint/.../CLAUDE.md
   AGENTS.md                              ← symlink to CLAUDE.md
   .claude/docs/claude-architecture.md    ← from blueprint/.../.claude/docs/claude-architecture.md
   .claude/settings.json                  ← adjust hook paths
   .claude/agents/<repo>-{architect,maintainer,reviewer,precommit-auditor}.md
   .claude/commands/<repo>-{implement,audit,audit-skills}.md
   .claude/scripts/<repo>_{quality_check,git_push_guard,skills_drift}.sh
   .claude/skills/<repo>-<area>/SKILL.md  ← one per skill from your design
   .claude/refs/                          ← empty; populate as cross-skill needs emerge
   ```

   **If your team has Cursor users**, add the §11 recipe:

   ```bash
   # .gitignore (append)
   .cursor/skills

   # repo bootstrap hook (melos post / npm postinstall / make setup)
   [ -e .cursor/skills ] || ln -s ../.claude/skills .cursor/skills
   ```

5. **Replace placeholders.** Sed `<repo>` → your repo's prefix
   (`bp`, `jolly`, etc.), `<project name>` → human name. Strip the
   blueprint banner comments at the top of each file once filled in.

6. **Stays in the blueprint, never copied:**
   - `README.md` — read once, refer to it later
   - `conventions/{module,pattern,cheatsheet}-style.md` — referenced
     from `.claude/docs/claude-architecture.md` §3, not duplicated
   - `.claude/refs/README.md` — discipline doc; your repo's
     `.claude/refs/` is just the directory with content files as
     they're added

7. **Validate.** Trigger each hook rule with a throwaway edit. Run
   `/<repo>-audit-skills` to check for dead links. Open `CLAUDE.md`
   in IntelliJ and confirm the symlink-as-AGENTS.md works.

---

## 13. Expected result in a repo

The complete agentic surface for a repo has **two layers**: the
project layer (files inside the repo) and the foundation plugin
(declared at project scope in the repo's `.claude/settings.json`,
fetched and cached by the CLI under `~/.claude/plugins/`). The
declaration travels with the repo; the cached content is per-user
and managed by the CLI. Both layers are loaded into agent context
whenever you work in the repo.

Names below are illustrative — replace `myrepo` and `<area-N>` with
your own.

### Layer 1 — project layer (inside the repo)

```
myrepo/                                            (repo root)
├── CLAUDE.md                                      agent context (Claude Code reads this)
├── AGENTS.md                       ─symlink─→ CLAUDE.md  (Codex / OpenAI tools read this)
│
├── .cursor/                                       (optional) Cursor IDE compatibility — see §11
│   ├── mcp.json                                   Cursor-specific MCP server config (committed)
│   └── skills/                     ─symlink─→ ../.claude/skills  (gitignored, recreated by bootstrap hook)
│
├── .claude/                                       AI architecture — self-contained
│   ├── settings.json                              hooks wired to scripts below
│   ├── docs/
│   │   ├── claude-architecture.md                 per-repo decision log:
│   │   │                                            §2 skill split table
│   │   │                                            §3 reference styles in use (links into blueprint)
│   │   │                                            §4 agent roster additions
│   │   │                                            §5 enforcement mode
│   │   │                                            §8 rejected alternatives + reversal criteria
│   │   └── _module-template.md                    optional authoring helper for *-module.md refs
│   ├── refs/                                      cross-skill shared markdown
│   │   ├── proto-naming.md                        example: linked from myrepo-flutter and myrepo-api SKILL.md
│   │   └── env-config.md                          example: env table linked from services + deployment skills
│   │                                              (no README — that lives in the blueprint)
│   ├── agents/
│   │   ├── myrepo-architect.md                    read-only planner
│   │   ├── myrepo-maintainer.md                   write — implementer (used by /myrepo-implement)
│   │   ├── myrepo-reviewer.md                     read-only post-impl reviewer
│   │   ├── myrepo-precommit-auditor.md            read-only commit-readiness gate
│   │   └── myrepo-security-auditor.md             optional domain auditor — only if §4 says so
│   ├── commands/
│   │   ├── myrepo-implement.md                    /implement — code↔review loop
│   │   ├── myrepo-audit.md                        /audit — precommit gate
│   │   └── myrepo-audit-skills.md                 /audit-skills — drift scan
│   ├── scripts/
│   │   ├── myrepo_quality_check.sh                PostToolUse: path → skill nudges, block generated
│   │   ├── myrepo_git_push_guard.sh               PreToolUse: branch allowlist
│   │   └── myrepo_skills_drift.sh                 dead-link scanner
│   └── skills/
│       ├── myrepo-<area-1>/                       e.g. myrepo-flutter — Flutter-heavy area
│       │   ├── SKILL.md                           applicability + See also (.claude/refs/, related skills, utopia-hooks foundation)
│       │   └── references/                        per-skill agent-loaded content (no docs/ subdir here)
│       │       ├── <feature>-module.md            business module — user flow + intent (style: module)
│       │       ├── <topic>-pattern.md             cross-cutting convention (style: pattern)
│       │       └── <topic>-cheatsheet.md          inventory map (style: cheatsheet)
│       └── myrepo-<area-2>/                       e.g. myrepo-api — Kotlin Ktor backend (no utopia-hooks layer — not Flutter)
│           ├── SKILL.md
│           └── references/
│               └── <topic>-pattern.md
│
├── docs/                                          (optional) repo-root non-Claude project docs —
│   └── ...                                        architecture diagrams, deployment runbooks, etc.
│                                                  Independent of `.claude/docs/` above.
│
└── (rest of the repo — source code, etc.)
```

### Layer 2 — foundation plugin (project-scoped enablement, user-level cache)

The foundation plugin has **two physical aspects** that need to be
distinguished:

- **Enablement** — declared in `.claude/settings.json` via
  `enabledPlugins` (what plugins this scope wants active) and
  `extraKnownMarketplaces` (where to find them). This **is in the
  repo** and travels with the codebase.
- **Content** — fetched from the marketplace and cached by the CLI
  under `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.
  This is **user-level** (cannot be committed). It's an
  implementation detail of the CLI — you don't edit it by hand.

The repo declares *what* it needs; the CLI handles *fetching*. A
contributor cloning the repo and running Claude Code for the first
time gets prompted to install the declared plugin. From that point
on, agent context loads the plugin whenever the contributor works
in this repo.

This is why the blueprint's `.claude/settings.json` ships with:

```json
{
  "extraKnownMarketplaces": {
    "utopia-claude-skills": {
      "source": { "source": "github", "repo": "Utopia-USS/utopia-flutter-skills" }
    }
  },
  "enabledPlugins": {
    "utopia-hooks@utopia-claude-skills": true
  }
}
```

**Plugin scopes — pick deliberately:**

| Scope | Settings file | Use when |
|---|---|---|
| `project` | `.claude/settings.json` (committed) | Repo *requires* the plugin — every contributor on every machine. **This is the blueprint default for `utopia-hooks`.** |
| `user` | `~/.claude/settings.json` | You want it everywhere across all your repos, regardless of project declarations. |
| `local` | `.claude/settings.local.json` (gitignored) | You're trying it out in this repo without committing the choice. |

The blueprint defaults to `project` scope for the foundation because
the codebase *assumes* the foundation is present — agent skills
cross-link into it, hook conventions are taught only there. Making
that requirement repo-declared rather than per-contributor folklore
is the whole point.

**What the foundation contributes** (the cached content the CLI
manages — listed for reference, not as a path to edit):

```
utopia-hooks plugin
├── plugin manifest                                name, version, marketplace
├── hooks (PostToolUse)
│   └── quality_check.sh                           hook idiom enforcement: Screen/State/View, IList,
│                                                  widget extraction, TextEditingController, lambda style
│                                                  (guarded — silent exit outside Flutter+utopia_hooks projects)
└── skills/utopia-hooks/
    ├── SKILL.md                                   description matches on Flutter / hooks / state work
    └── references/
        ├── screen-state-view.md                   CRITICAL — Screen/State hook/View architecture
        ├── hooks-reference.md                     CRITICAL — full hook API by use case
        ├── global-state.md                        CRITICAL — HasInitialized, MutableValue, providers
        ├── async-patterns.md                      HIGH — useAutoComputedState / useSubmitState / streams
        ├── flutter-conventions.md                 HIGH — IList/IMap/ISet, lambdas, strict analyzer
        ├── di-services.md                         MEDIUM — service registration, useInjected
        ├── composable-hooks.md                    MEDIUM — widget-level hooks, useIf, useMap
        ├── multi-page-shell.md                    MEDIUM — shell / page composition
        ├── paginated.md                           MEDIUM — usePaginatedComputedState
        ├── complex-state-examples.md              MEDIUM — non-trivial state composition
        └── testing.md                             MEDIUM — SimpleHookContext, hook unit tests
```

**User-facing CLI operations** (when you need to inspect or override):

```bash
/plugin                           # interactive UI: discover, install, manage
/plugin install <name>@<marketplace> --scope project    # explicit project install
claude plugin list                                      # what's installed and at what scope
claude plugin update utopia-hooks                       # pull latest from marketplace
```

### How the layers compose at runtime

When you edit a Flutter file in `myrepo/`:

1. **Foundation hook** (`utopia-hooks/scripts/quality_check.sh`) fires
   on Edit/Write — enforces hook idioms, Screen/State/View shape,
   IList/IMap/ISet, lambda style. These rules are universal across
   Flutter projects; they belong here, not in the project layer.

2. **Project hook** (`myrepo/.claude/scripts/myrepo_quality_check.sh`)
   fires on the same Edit/Write — surfaces myrepo-specific skills
   by path (e.g. *"this is an activity widget — consult
   myrepo-flutter/references/activity-pattern.md"*) and hard-blocks
   edits to generated files.

3. **Description matching** loads relevant skills:
   - `myrepo-flutter` (description match on Flutter file paths)
   - `utopia-hooks` (description match on hook usage / state work)
   - Both load — they cover disjoint concerns and compose without
     conflict.

4. **Cross-link from project skill to foundation:**
   `myrepo-flutter/SKILL.md` "Relationship to the foundation" table
   delegates universal concerns (Screen/State/View, hooks, async)
   to `utopia-hooks` rather than restating them. The reference table
   lists `utopia-hooks:references/<file>.md` notation when an
   answer requires foundation context.

When you edit a Kotlin file in `myrepo/classroom-api/`: foundation
plugin's hook is **guarded** (`utopia_arch` declaration check) and
silently exits — Kotlin is outside its scope. Only `myrepo-api`
skill applies. The foundation/project split is enforced by hook
guards, not by trust.

Two directories under `.claude/` sit deliberately apart:

- **`.claude/refs/`** — content for the agent (cross-skill shared markdown).
- **`.claude/docs/`** — meta about the layer (decisions, architecture log,
  authoring helpers).

Mixing them invites the agent to load decision-log content as guidance, or
to skip shared markdown thinking it's internal docs. Both live under
`.claude/` so the AI architecture is one inspection target — repo-root
`docs/` (if present) holds non-Claude project docs and is orthogonal.

What's **not** in the repo (stays in the blueprint):

- `conventions/` — authoring guides for module/pattern/cheatsheet
  styles. Linked from `.claude/docs/claude-architecture.md` §3.
- `README.md` — the blueprint model. Linked from
  `.claude/docs/claude-architecture.md` header.

---

## 14. Blueprint directory layout

```
blueprint/project-claude-layer/
├── README.md                       this file — the model (NOT copied to repos)
├── CLAUDE.md                       blueprint shape for repo-root agent context
├── AGENTS.md                       symlink → CLAUDE.md
├── conventions/                    NOT copied — referenced from each repo's claude-architecture.md
│   ├── module-style.md
│   ├── pattern-style.md
│   └── cheatsheet-style.md
└── .claude/                        AI architecture — entirely under .claude/
    ├── settings.json               blueprint shape for hook wiring
    ├── docs/                       meta about the layer
    │   └── claude-architecture.md  blueprint shape for per-repo decision log
    ├── refs/                       shows the structure; only README is blueprint-side
    │   └── README.md               NOT copied — discipline doc, lives here
    ├── agents/                     four standard agents (REPO-prefixed)
    ├── commands/                   three standard commands
    ├── scripts/                    three guard / quality scripts
    └── skills/REPO-AREA/
        ├── SKILL.md                blueprint shape for a skill
        └── references/             empty — content is per-repo authorship
```

Each blueprint file carries a banner at the top reminding the reader
that it's a blueprint, not production. Once copied and adapted, the
banner is stripped.
