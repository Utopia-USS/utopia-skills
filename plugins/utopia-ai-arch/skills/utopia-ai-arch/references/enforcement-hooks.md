---
title: Enforcement Hooks - quality_check, skills_drift, SessionStart
impact: CRITICAL
tags: hooks, posttooluse, sessionstart, quality-check, skills-drift, guards, generated-files, path-nudges, push-guard
---

# Enforcement Hooks - `quality_check`, `skills_drift`, SessionStart

## What this is

The hook script layer of `.claude/`. **Two scripts are standard**:

1. **`<prefix>_quality_check.sh`** - `PostToolUse` on `Edit|Write|MultiEdit`. Hard-blocks generated-file edits, surfaces path → skill nudges, surfaces relative-import violations.
2. **`<prefix>_skills_drift.sh`** - `PostToolUse` on the same matcher (hook mode) plus a `--all` full-scan mode. Reports dead markdown links inside `.claude/**/*.md` + repo-root `CLAUDE.md`.

A third script (`<prefix>_session_setup.sh` / `dart_mcp_setup.sh`) is **optional** - `SessionStart` only, only when a measurable local-resource leak has been observed. Repo-B's precedent below.

The project hooks coexist with the foundation hook (provided by the `utopia-hooks` plugin - universal idioms / Screen-State-View / IList enforcement). Each layer's hook proves it's in scope before doing anything; out-of-scope is a silent `exit 0`. They are **disjoint by path/file-type**, not by mutual exclusion.

> "Hooks from different layers coexist without conflict." - `production-repo-A/.claude/docs/claude-architecture.md:75`

## When this applies

- Adding or editing a project hook script
- Adding a path → skill nudge to `<prefix>_quality_check.sh`
- Debugging why a hook fires (or fails to fire) in scope
- Considering a new `SessionStart` hook for a resource concern
- Considering a `PreToolUse` `git push` guard (read the rejection section before doing this)
- Bootstrapping `.claude/` for a new repo from the blueprint
- Auditing the `<prefix>_quality_check.sh` nudges against the skill roster after a skill split / rename

## `<prefix>_quality_check.sh` - the contract

### Inputs / outputs

| Channel | Shape |
|---------|-------|
| stdin | JSON containing `.tool_input.file_path` (the path Claude is editing) |
| env | `<PREFIX>_QUALITY_MODE` - `"warn"` (default) or `"block"` |
| stdout | unused (don't write here - Claude doesn't see it) |
| stderr | human-readable summary; Claude sees this on exit 1 / 2 |
| exit 0 | silent - out of scope or clean |
| exit 1 | warn - user sees stderr, Claude continues |
| exit 2 | block - Claude sees stderr and must address before continuing |

> "stdin: JSON with `{.tool_input.file_path}`. env `<PREFIX>_QUALITY_MODE`: 'warn' (default, exit 1) or 'block' (exit 2). Note: edits to *.g.dart / *.freezed.dart ALWAYS exit 2 regardless of mode. exit 0: silent success (or out of scope). exit 1: warn - user sees stderr, Claude continues. exit 2: block - Claude sees stderr and must address." - `production-repo-A/.claude/scripts/<prefix>_quality_check.sh:8-15`

### The mode env var

`<PREFIX>_QUALITY_MODE` defaults to `warn`. Setting it to `block` upgrades every non-generated-file nudge to a blocking exit-2. The default is `warn` because:

- Nudges are advisory by design - they surface a skill; they don't replace it firing through description matching.
- Treating advisory output as blocking trains agents to silence the hook (`# noqa`-style workarounds), defeating the purpose.
- `block` mode exists for CI-grade pipelines where any drift should fail the session, not interactive use.

> "All other rules are `warn` (exit 1). Mode switch via env var (`<PREFIX>_QUALITY_MODE=block`) for CI-grade use later." - `production-repo-A/.claude/docs/claude-architecture.md:122`

### Generated-file edits are blocked regardless of mode

The generated-file extension check runs **before** any other guard (before pubspec walk, before `.dart` check, before mode read). It always emits exit 2.

**Why first?** A misread JSON payload, a missing `pubspec.yaml`, or an unrelated workspace can short-circuit the script to exit 0 before reaching the generated-file branch - and a silently-permitted `*.g.dart` edit is the single failure mode most likely to cause user pain (regenerator overwrites the manual change; or worse, doesn't, and the file diverges from its `.dart` source).

## Scope guards (mandatory, in this order)

Every quality-check script proves it's in scope **before** doing any real work. The canonical order:

```bash
set -u

mode="${<PREFIX>_QUALITY_MODE:-warn}"
violations=()

# 1. jq must be available - the parser this script depends on.
command -v jq >/dev/null 2>&1 || exit 0

# 2. Read the stdin JSON payload.
payload="$(cat)"
file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[[ -z "$file" ]] && exit 0

# 3. Generated-file hard block - runs BEFORE other guards.
case "$(basename "$file")" in
  *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|\
  *.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart)
    {
      echo "<prefix>_quality_check: BLOCK - attempted edit to generated file"
      echo "  $file"
      echo ""
      echo "Generated files must not be edited manually. Regenerate with:"
      echo "  <repo-specific build_runner command>"
    } >&2
    exit 2
    ;;
esac

# 4. File must exist and be .dart (adjust extension per repo).
[[ -f "$file" ]] || exit 0
[[ "$file" == *.dart ]] || exit 0

# 5. Walk to nearest pubspec.yaml (workspace package root).
dir="$(cd "$(dirname -- "$file")" && pwd)"
project_root=""
while [[ "$dir" != "/" && -n "$dir" ]]; do
  if [[ -f "$dir/pubspec.yaml" ]]; then
    project_root="$dir"
    break
  fi
  dir="$(dirname -- "$dir")"
done
[[ -z "$project_root" ]] && exit 0

# 6. Walk to repo root (.git).
repo_root=""
dir="$project_root"
while [[ "$dir" != "/" && -n "$dir" ]]; do
  if [[ -e "$dir/.git" ]]; then
    repo_root="$dir"
    break
  fi
  dir="$(dirname -- "$dir")"
done
[[ -z "$repo_root" ]] && exit 0

# 7. Confirm we're inside THIS repo (basename match against repo folder).
[[ "$(basename "$repo_root")" == "<repo-folder-name>" ]] || exit 0

repo_rel="${file#$repo_root/}"
```

### Why each guard exists

| Guard | Why |
|-------|-----|
| `command -v jq` | The script parses stdin JSON with jq. Without jq, attempting to parse would fail loudly mid-script. `exit 0` on absence is fail-open - Claude continues, the user isn't blocked by a missing dev dependency. |
| `[[ -z "$file" ]]` | A malformed payload or a tool call without a `file_path` (e.g. some bash invocations) is out of scope. Silent. |
| Generated-file branch BEFORE other guards | A `*.g.dart` edit must block even if the workspace lookup fails. Order matters - the hard block is unconditional. |
| `[[ -f "$file" ]]` | Skip if the file doesn't exist (the edit may still be planned, or it was a `Write` to a path that hasn't materialised). |
| `[[ "$file" == *.dart ]]` | Project hook's scope is Dart. Adjust per repo (`.kt`, `.ts`, etc.) only when there are real nudges to add. |
| pubspec walk | Confirms the file lives inside a Dart workspace package - not in `docs/`, `assets/`, generated-output-only dirs, or unrelated subtrees. |
| `.git` walk | Locates the repo root for the basename match and relative-path computation. |
| **Basename match against `<repo-folder-name>`** | **The hook fires across every project Claude has open at once.** Without this guard, editing a Dart file in `~/IdeaProjects/some-other-repo/lib/main.dart` would trigger `<prefix>_quality_check.sh` (it's the same script under `~/IdeaProjects/production-repo-A/.claude/scripts/`, but Claude points the hook at `${CLAUDE_PROJECT_DIR}`). The basename guard is the cheapest reliable scope check. |

> "Only fire inside the production-repo-B repo: `[[ \"$(basename \"$repo_root\")\" == \"production-repo-B\" ]] || exit 0`" - `production-repo-B/.claude/scripts/<prefix>_quality_check.sh:76-77`

## Generated-file hard block - the extensions list

Extensions vary per project depending on which codegen surfaces ship in the repo. Always exit 2; always print a remediation hint pointing at the repo's actual build-runner command.

| Repo | Extensions blocked | Remediation command |
|------|--------------------|---------------------|
| production-repo-A | `*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.config.dart`, `*.pb.dart`, `*.pbenum.dart`, `*.pbjson.dart`, `*.pbserver.dart` | `dart run build_runner build --delete-conflicting-outputs --workspace` |
| production-repo-B | `*.pb.dart`, `*.pbenum.dart`, `*.pbjson.dart`, `*.pbserver.dart`, `*.freezed.dart`, `*.g.dart`, `*.gr.dart`, `*.config.dart` | `melos run build_runner:build` |
| production-repo-C | `*.freezed.dart`, `*.g.dart`, `*.config.dart` | `fvm dart run build_runner build --delete-conflicting-outputs` (run inside affected package) |

Add an extension to the blocked list **as soon as** the corresponding codegen is in the repo's pubspec. The cost of a missed extension is silent divergence between source and generated output.

```bash
case "$(basename "$file")" in
  *.g.dart|*.freezed.dart|*.gr.dart|*.config.dart|\
  *.pb.dart|*.pbenum.dart|*.pbjson.dart|*.pbserver.dart)
    {
      echo "<prefix>_quality_check: BLOCK - attempted edit to generated file"
      echo "  $file"
      echo ""
      echo "Generated files must not be edited manually. Regenerate with:"
      echo "  <repo-specific build_runner command>"
    } >&2
    exit 2
    ;;
esac
```

**Per-project divergence on remediation command** - repo-A uses bare `dart run build_runner ... --workspace`, repo-B uses `melos run build_runner:build`, repo-C uses `fvm dart run ...`. The toolchain canon (FVM yes/no, melos yes/no, workspace flag) is recorded once in `claude-architecture.md` and propagated everywhere. See [architecture-doc.md](architecture-doc.md) for the canon discipline.

## Universal Dart finding - relative imports in `lib/`

A repo-wide convention surfaced explicitly even though the analyzer also catches it (`always_use_package_imports`). Why duplicate the check?

- The analyzer fires at static-analysis time; the hook fires at edit time, before the analyzer ever runs.
- The hook nudge gives a one-line WHY, in stderr, where Claude sees it immediately - vs. an analyzer warning the agent might overlook in a longer report.
- The script is two cheap lines.

```bash
if [[ "$repo_rel" == lib/* || "$repo_rel" == */lib/* ]]; then
  if grep -qE "^import[[:space:]]+['\"](\.\./|\./)" "$file"; then
    add "uses relative Dart import - repo convention requires 'package:...' imports (always_use_package_imports)"
  fi
fi
```

> "uses relative Dart import - repo convention requires 'package:...' imports (always_use_package_imports)" - `production-repo-A/.claude/scripts/<prefix>_quality_check.sh:98`

## Path → skill nudges

Mirrors each skill's `applicability` from `claude-architecture.md` §"Skill split". Each `case "$repo_rel" in` block matches a set of paths and surfaces the matching skill / references in stderr.

```bash
# Example - adapt paths and skill names per repo.
case "$repo_rel" in
  <area-1-paths>)
    add "<area-1> edit - consult <prefix>-<area-1> skill (references/<feature>-module.md)"
    ;;
esac

case "$repo_rel" in
  <area-2-paths>)
    add "<area-2> edit - consult <prefix>-<area-2> skill"
    ;;
esac
```

### The rule for adding a nudge

> **Add a nudge ONLY when the surface owns ≥2 references the agent should consult.** Don't nudge at "no content yet".

**Expected granularity in a mature repo.** A bootstrap hook may start with 0-1 nudges (one for the master skill). As `references/` files accumulate, the hook should grow to **typically 4-8 nudges** - one per distinct surface that has earned ≥2 references. Production examples:

- **repo-A**: 5+ nudges covering UI paths, state files, security-sensitive crypto/FFI paths, <crypto-service>, RLS-protected backend paths
- **repo-B**: 5 nudges covering domain proto+UI, design-system / app-wide UI, services, models, proto edits
- **repo-C**: 7 nudges covering real-time-DB game-state paths, design-system, app/admin UI surfaces, content packs, services, models, IAP

At bootstrap, add a nudge only for skills launching with ≥2 references (usually just the master skill) and delete the unused case blocks from the template. A two-year-old hook with one nudge means either references didn't accumulate (suggesting the skill itself is thin) or the hook has not been maintained (`evolution-and-drift.md` §5.1 "Adding a path nudge incrementally"). Production maturity = surface coverage matches the actual reference inventory.

Quoted in both production repos that explicitly considered extending their hook to a primitive sister skill:

> "Adding a nudge that points at 'no content yet' wastes a hook firing." - `production-repo-B/.claude/docs/claude-architecture.md:177` and `production-repo-C/.claude/docs/claude-architecture.md:144`

**Why.** A nudge has a budget - a single stderr line Claude reads while processing the edit. Spending that budget on "go consult a skill with one paragraph of placeholder content" trains Claude to weight nudges lower, which hurts the *other* nudges that point at real material.

**Reversal criterion.** When the primitive sister skill (e.g. `<prefix>-api`, `<prefix>-functions`) accumulates 2+ reference docs, extend the hook with its path nudges.

### A nudge must match the skill's applicability exactly

If `<prefix>-design-system` has `applicability: paths under packages/core/lib/widget/`, but the hook nudge fires on `packages/app/lib/screen/*`, the wrong skill is surfaced - the agent sees the nudge, loads the skill, and finds rules that don't apply. See [skill-design.md](skill-design.md) §"Skill description that fires on the wrong files".

### Example nudge - repo-A's security path

```bash
case "$repo_rel" in
  packages/<crypto-pkg>/lib/src/ffi/*|\
  packages/<crypto-pkg>/lib/src/executor/*|\
  <crypto-package>/lib/service/crypto*|\
  <crypto-package>/lib/service/contact/key/*|\
  core/lib/service/crypto/*|\
  core/lib/model/crypto/*)
    add "security-sensitive path - consult sister skill <prefix>-security (references/{e2e-encryption,supabase-rls,platform-storage}.md) and <prefix> (FFI binding style → references/ffi-conventions.md) before merging"
    ;;
esac
```

> Source: `production-repo-A/.claude/scripts/<prefix>_quality_check.sh:108-118`

Surface guard, then nudge - the case body never does more than `add "..."`. Heavy work belongs elsewhere.

## Report block

The script ends with:

```bash
if [[ ${#violations[@]} -eq 0 ]]; then
  exit 0
fi

{
  echo "<prefix>_quality_check: ${#violations[@]} nudge(s) in ${repo_rel}"
  for v in "${violations[@]}"; do
    echo "  - $v"
  done
  echo ""
  echo "(mode: $mode - set <PREFIX>_QUALITY_MODE=block to make non-generated-file nudges blocking)"
  echo "(foundation conventions are enforced by the upstream utopia-hooks plugin)"
} >&2

if [[ "$mode" == "block" ]]; then
  exit 2
else
  exit 1
fi
```

The trailing "foundation conventions are enforced by the upstream utopia-hooks plugin" line is **load-bearing** - it tells Claude not to re-flag foundation idioms when reviewing the violations. Without it the agent's instinct is to "fix" missing Screen/State/View when the project hook only flagged a relative import.

## `<prefix>_skills_drift.sh` - the contract

A pure dead-link scanner over `.claude/**/*.md` + repo-root `CLAUDE.md`.

### Modes

Two invocations:

```bash
# Full-scan mode (used by /<prefix>-audit-skills)
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_skills_drift.sh" --all

# Hook mode (PostToolUse on Edit|Write|MultiEdit - reads stdin JSON, scans the edited file only)
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_skills_drift.sh"
```

> "`<prefix>_skills_drift.sh --all` - Full scan across .claude/ + CLAUDE.md. Emits findings to stderr; exit 1 if any dead link, 0 if clean. `<prefix>_skills_drift.sh` - PostToolUse hook mode - reads JSON from stdin, scans the edited file only." - `production-repo-A/.claude/scripts/<prefix>_skills_drift.sh:8-15`

### What it scans

For each in-scope file, every `](target)` link is extracted; non-existent targets are reported to stderr.

### Resolution rules

- `target` starting with `/` → resolved against repo root (`$CLAUDE_PROJECT_DIR`)
- Anything else → resolved against the file's directory
- Trailing `#anchor` is stripped before existence check
- Reference-style links (`[label]: target` at line start) are also scanned

### Skipped (by design - keep signal high)

| Skip rule | Why |
|-----------|-----|
| `http://`, `https://`, `mailto:`, `tel:`, `ftp://`, `ssh://` | Not local filesystem targets - out of scanner scope |
| `\` prefix (regex escapes like `\.\./|\./`) | False positives from documentation about paths |
| Target containing `|` or `*` | Regex / glob metacharacters, not real paths |
| Bare placeholder words (`path`, `target` - no `/` and no `.`) | Pedagogical placeholders, not real links |
| Inside triple-backtick fenced code blocks | Documentation examples often show illustrative paths that don't exist |
| Files whose basename starts with `_` | Template files; their links are illustrative |

> "Out of scope for v1 (by design, to keep signal high): bare path references in prose / code fences, command examples, orphan skills (exist but unreferenced), frontmatter lint. Add incrementally after tuning signal/noise." - `production-repo-A/.claude/scripts/<prefix>_skills_drift.sh:20-25`

### Exit codes

| Exit | Meaning |
|------|---------|
| 0 | Clean - no broken links found, or file is out of scope |
| 1 | Drift found - broken links reported on stderr (warn) |
| 2 | Drift found AND `<PREFIX>_QUALITY_MODE=block` |

### Output shape

```
<rel-path>:<lineno> - broken link: <target>
<rel-path>:<lineno> - broken link: <other-target>

<prefix>_skills_drift: 2 broken reference(s) across .claude/ + CLAUDE.md
```

Hook mode wires the same scan against a single file:

```bash
case "$file" in
  */.claude/*.md|*/CLAUDE.md) ;;
  *) exit 0 ;;
esac
```

### Out of scope for v1 (don't expand into)

- Bare path references in prose (e.g. "see `lib/foo.dart`" without `](...)`)
- Command examples (`melos run X`, `fvm flutter Y`)
- Orphan skills - a SKILL.md that exists but isn't referenced anywhere
- Frontmatter lint (required fields, applicability presence)

Adding any of these expands the false-positive surface. Tune signal/noise on the v1 dead-link scan first; expand incrementally.

## When to add a `SessionStart` hook

**Default: don't.** A SessionStart hook runs on every session open, regardless of scope. The cost is paid on every session; the benefit must be commensurate.

### The rule

Add a SessionStart hook **only when a measurable local-resource leak is observed** that can't be remediated by user action at reasonable cadence.

### The repo-B precedent

`production-repo-B/.claude/scripts/dart_mcp_setup.sh` is the only SessionStart hook across the three production repos. It exists because:

> "Each Claude Code session spawns its own `dart mcp-server`, which in turn spawns a `dart language-server` (~2.5GB resident). On clean `/exit` they cascade away. On a Claude crash the children orphan to init and accumulate. Forgotten Claude windows also hold their full analyzer - the team was reporting ~40GB after a day of work." - `production-repo-B/.claude/scripts/dart_mcp_setup.sh:4-9`

The trigger was **team-reported ~40GB memory at end of workday**. Not theoretical leak; observed cost on real machines.

### What the repo-B hook does

```
SessionStart →
  1. Kill Claude top-level processes older than $<PREFIX>_MCP_STALE_HOURS (default 4h),
     other than the session running this hook. Their dart mcp-server +
     language-server cascade away with them. Transcripts stay on disk -
     recover with `claude --resume <uuid>`.
  2. Reap any leftover orphaned dart mcp-server / language-server (PPID == 1)
     from earlier crashes.
  3. Warn to stderr when too many live Claude sessions are running.
```

### Invariants

| Invariant | Why |
|-----------|-----|
| **Always exit 0** | A transient failure here must never block a session start. The hook is a janitor, not a gate. |
| **Never kill own session** | Walks up from `$$` collecting Claude PIDs; the kill loop skips those. The hook running inside a session must not kill the session. |
| **Recovery hint in the kill log** | Killed sessions list their `--resume <uuid>` so the user can recover transcripts. |
| **Dry-run env var** | `<PREFIX>_MCP_DRY_RUN=1` lets the user see what would be killed without killing - useful for first-run vetting in a new repo. |
| **Stale threshold tunable** | `<PREFIX>_MCP_STALE_HOURS=4` default; team-local override via shell rc. |

### Why other repos don't have this hook

repo-A and repo-C observed the same Dart analyzer cost but **haven't reported the cumulative leak**. The hook is repo-local because:

- It's only worth its run-time when the leak is real
- Team workflows differ - a team that always `/exit` cleanly never triggers the orphan path
- The kill threshold and "too many sessions" warning are calibrated to one team's machines

Don't blindly copy this hook to a new repo. Validate the leak first.

## Why NO `git push` guard hook (rejected alternative)

**The alternative considered.** A `PreToolUse` hook matching `Bash` that inspects the command for `git push` and blocks pushes to protected branches (`master`, `main`, `develop`, `staging`).

**Why rejected - two existing layers already cover it.**

1. **`permissions.allow` deliberately omits `git push`.** Every `git push *` invocation prompts the user for permission. The user is the gate.
2. **GitHub branch protection** on `master` / `main` / `staging` covers the remote. A force-push that slipped past the local prompt would still fail at GitHub.

A `PreToolUse` push-guard duplicates both **and runs on every Bash invocation** (every `git status`, every `ls`, every `melos run`). The matcher cost is real; the benefit is zero given the two existing layers.

Precedent: explicitly rejected in `production-repo-A/.claude/docs/claude-architecture.md:123`, `production-repo-B/.claude/docs/claude-architecture.md:109-113` (a push-guard existed and was removed as redundant once the two layers were in place), and `production-repo-C/.claude/docs/claude-architecture.md:106-108` (never added - recorded as unnecessary from day one).

**Reversal criterion.** A repo with **neither** a `permissions.allow` exclusion **nor** GitHub branch protection. In that case the guard plugs a real hole. Until then, it's overhead.

## Guarded hooks coexist - foundation + project

The foundation hook (shipped by the `utopia-hooks` plugin) and the project hook (`<prefix>_quality_check.sh`) both fire on `Edit|Write|MultiEdit`. They don't conflict because:

- **Disjoint scope.** Foundation matches on `*_state.dart`, `*_screen.dart`, `*_view.dart` for hook / Screen-State-View idioms. Project matches on repo-specific paths (`packages/<crypto-pkg>/lib/src/ffi/`, `<crypto-package>/lib/service/crypto*`, `<area-flutter>/lib/ui/lesson/activity/*`, etc.). A file that triggers both → both fire, surfacing disjoint nudges.
- **Silent on out-of-scope.** Foundation's guard checks `utopia_arch` declaration in the pubspec - silent exit 0 on Kotlin / TypeScript / non-Flutter Dart. Project's basename guard means it stays silent outside this repo's folder.

> "**Layers enforce disjoint patterns.** Foundation hooks match on `*_state.dart`, `*_screen.dart`, `*_view.dart`. Project hooks match on `*.g.dart`, `packages/<crypto-pkg>/lib/src/ffi/`, `<crypto-package>/lib/service/crypto*`. If a file triggers both, both fire - that's fine." - `production-repo-A/.claude/docs/claude-architecture.md:91-94`

Refer the reader to the foundation plugin without restating its content - see the `utopia-hooks` plugin description for what the foundation hook enforces.

## Hook wiring in `settings.json`

The hooks block in `.claude/settings.json`:

```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Edit|Write|MultiEdit",
      "hooks": [
        {
          "type": "command",
          "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_quality_check.sh\""
        },
        {
          "type": "command",
          "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_skills_drift.sh\""
        }
      ]
    }
  ]
}
```

Two entries under one matcher block means **both scripts fire on every `Edit|Write|MultiEdit`** - quality_check on the edited file, skills_drift in hook-mode on the same file (silent unless the file is markdown under `.claude/` or `CLAUDE.md`).

Production variance: repo-A wires both scripts; repo-B and repo-C wire only `quality_check` and run the drift scan via `/<prefix>-audit-skills` instead. Wiring both is the blueprint default - hook mode costs one silent `exit 0` on out-of-scope edits.

A SessionStart hook (when justified - see repo-B precedent above) wires under a separate top-level key:

```json
"hooks": {
  "PostToolUse": [ ... ],
  "SessionStart": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_session_setup.sh\""
        }
      ]
    }
  ]
}
```

See [settings-json.md](settings-json.md) for the full settings shape.

## Anti-patterns

(For the push-guard hook and primitive-skill nudges - catalogued in [evolution-and-drift.md](evolution-and-drift.md) symptoms §O and §S, and in §"Why NO `git push` guard hook" above. For a hook that never fires or fires in an unrelated repo, re-check §"Scope guards" and the bootstrap validation checklist.)

### Allowing generated-file edits in `block` mode by mistake

❌ Generated-file check happens **after** the mode read, e.g. `if [[ "$mode" == "block" ]]; then ... exit_for_violations; fi` runs first, and the generated-file branch is gated by it.

✅ Generated-file check is **first**, **always exits 2**, regardless of mode. The mode env var only controls non-generated-file nudges.

### Hook script that exits non-zero without writing to stderr

❌ `exit 1` with no preceding `echo "..." >&2`. Claude sees a non-zero exit but no message - silent failure mode. Always write a human-readable summary to stderr before a non-zero exit.

### Hook script doing real work BEFORE its scope guards

❌ Grepping the file for content, running `dart analyze`, or hitting an HTTP endpoint at the top of the script - then later checking `[[ -f "$file" ]]` or the basename match. Guards first, always. Out-of-scope must cost ~10ms of guard logic, not the real work.

### One quality-check script doing both nudges and dead-link scanning

❌ Cramming the markdown-link scan into `quality_check.sh`. `.dart` edits run dead-link logic; `.md` edits run import / nudge logic. ✅ Two separate scripts wired under the same `PostToolUse` matcher - each guards its own scope independently.

### Treating `block` mode as the default

❌ Setting `<PREFIX>_QUALITY_MODE=block` in shell rc by default. Every nudge becomes blocking - agents learn to silence the hook. Default is `warn`; reserve `block` for CI-grade pipelines or specific high-confidence rules.

### Adding a SessionStart hook on speculation

❌ Adding a Dart MCP cleanup hook "in case the team has the same problem as repo-B". Wait for the leak to be observed and measured. Until then it's premature optimization that runs every session-open.

## See also

- [layer-model.md](layer-model.md) - foundation + project hook coexistence rule
- [skill-design.md](skill-design.md) - path nudges must match skill applicability exactly; primitive-skill rule
- [settings-json.md](settings-json.md) - hooks-block wiring, why `git push` is off the allowlist
- [bootstrap-procedure.md](bootstrap-procedure.md) - validation step ("trigger each hook rule with a throwaway edit")
- [evolution-and-drift.md](evolution-and-drift.md) - adding a path nudge incrementally as a skill matures; `dart_fix` bulldoze, generated-file leakage, stale processes
- [architecture-doc.md](architecture-doc.md) - recording hook-related rejected alternatives (push-guard, primitive nudges)
- Foundation plugin hook: `utopia-hooks` (provides the universal Flutter / hooks idiom enforcement)
- Inline templates: [`../templates/claude-layer/scripts/REPO_quality_check.sh`](../templates/claude-layer/scripts/REPO_quality_check.sh) and [`REPO_skills_drift.sh`](../templates/claude-layer/scripts/REPO_skills_drift.sh) - sed `<repo>` → project prefix, `<REPO>` → env-var prefix, fill in path-nudge case branches per skill, set basename guard to repo folder name
