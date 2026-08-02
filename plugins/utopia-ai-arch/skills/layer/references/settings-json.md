---
title: settings.json - Marketplace, Plugins, Permissions, Hooks
impact: MEDIUM
tags: settings, configuration, permissions, mcp, plugins, marketplace, hooks-wiring, project-scope
---

# `.claude/settings.json` - Marketplace, Plugins, Permissions, Hooks

## What this is

The wiring file. One JSON document at `.claude/settings.json`, committed to the repo, that declares:

1. **Marketplace** - where to fetch plugins from (`extraKnownMarketplaces`)
2. **Plugins** - which plugins are enabled for this repo (`enabledPlugins`)
3. **Permissions** - what Bash / MCP commands are auto-allowed without per-call prompts (`permissions.allow`)
4. **MCP servers** - which `mcp.json`-declared servers are enabled (`enabledMcpjsonServers` - optional)
5. **Hooks** - which scripts fire on which tool events (`hooks.PostToolUse`, etc.)

Everything else (model defaults, theme, UI prefs) lives elsewhere. `settings.json` is the contract the repo makes with Claude Code at session start. Project scope by default - travels with the repo, shared across contributors via git.

## When this applies

- Bootstrapping `.claude/` in a new repo (copy blueprint shape, edit per repo)
- Adding a Bash command to `permissions.allow`
- Wiring a new hook script
- Declaring an MCP server the repo will use
- Updating the marketplace URL if it moves
- Choosing between `settings.json` and `settings.local.json` for a setting

## Canonical shape

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "extraKnownMarketplaces": {
    "utopia-flutter-skills": {
      "source": {
        "source": "github",
        "repo": "Utopia-USS/utopia-flutter-skills"
      }
    }
  },
  "enabledPlugins": {
    "utopia-hooks@utopia-flutter-skills": true
  },
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git show:*)",
      "Bash(git fetch:*)",
      "Bash(git branch:*)",
      "Bash(git checkout:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git stash:*)",
      "Bash(gh pr view:*)",
      "Bash(gh pr list:*)",
      "Bash(gh pr diff:*)"
    ]
  },
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
}
```

Note: the blueprint and existing repos use both `utopia-flutter-skills` and `utopia-claude-skills` as marketplace names - the repo URL is what matters; the key is just a local name. Pick one and use it consistently. (repo-A uses `utopia-flutter-skills`; repo-B and repo-C use `utopia-claude-skills`. Either works - but when a marketplace repo is renamed, `source.repo` must be updated too; repo-B still points at the pre-rename URL, which only keeps working through GitHub's rename redirect.)

This canonical block matches the inline template at [`../templates/claude-layer/settings.json`](../templates/claude-layer/settings.json) exactly. Dart/Flutter toolchain permissions (fvm / melos) and `enabledMcpjsonServers` are per-repo extensions - see §"Extensions for Dart / Flutter repos" and §"MCP server declaration" below; never declare an MCP server that isn't installed.

## Plugin scope choice - project is the default for the foundation

Claude Code recognises three scopes for plugin enablement. Pick deliberately:

| Scope | File | When to use |
|-------|------|-------------|
| **project** | `.claude/settings.json` (committed) | The repo *requires* the plugin - every contributor on every machine. **Blueprint default for `utopia-hooks`.** |
| **user** | `~/.claude/settings.json` | You want it everywhere across all your repos, regardless of project declarations. |
| **local** | `.claude/settings.local.json` (gitignored) | You're trying it out in this repo without committing the choice. |

> "The blueprint defaults to `project` scope for the foundation because the codebase *assumes* the foundation is present - agent skills cross-link into it, hook conventions are taught only there. Making that requirement repo-declared rather than per-contributor folklore is the whole point." - blueprint README v1

**Why project scope for `utopia-hooks`.** A Utopia Flutter repo without the foundation loaded is missing context the skills assume - every project SKILL.md cross-links into `utopia-hooks:references/*.md`, and the foundation hook enforces idioms the project hook deliberately skips. Per-contributor folklore ("did you remember to install utopia-hooks?") fails silently. Project-scope declaration means the CLI prompts to trust and install on first repo open.

**Why not user scope.** User scope means "everywhere across all my repos". A contributor whose user-scope happens to include `utopia-hooks` gets the plugin loaded in repos that don't expect it (a Kotlin-only repo, an iOS-only repo). The plugin is guarded - it silently exits in non-Flutter scopes - but the per-session warm-up cost is paid for nothing.

**Why not local scope.** Local scope is for trial. Once the repo depends on the plugin, the declaration belongs in project scope so every contributor gets it.

## Marketplace declaration

```json
"extraKnownMarketplaces": {
  "utopia-flutter-skills": {
    "source": {
      "source": "github",
      "repo": "Utopia-USS/utopia-flutter-skills"
    }
  }
}
```

The key (`utopia-flutter-skills`) is a local label. The `source.repo` is the GitHub identifier the CLI fetches from. Once declared, plugins reference this marketplace with `@<key>`:

```json
"enabledPlugins": {
  "utopia-hooks@utopia-flutter-skills": true
}
```

If the marketplace URL changes, update `source.repo`. The CLI re-fetches on next session - no per-contributor migration needed.

## Permissions allowlist

`permissions.allow` is the list of Bash / MCP tool invocations Claude can run without a per-call user prompt. The default behaviour for un-allowed Bash is to prompt the user; the allowlist is the trust gate.

### The canonical Bash list

Every production repo's allowlist starts here:

```json
"Bash(git status:*)",
"Bash(git diff:*)",
"Bash(git log:*)",
"Bash(git show:*)",
"Bash(git fetch:*)",
"Bash(git branch:*)",
"Bash(git checkout:*)",
"Bash(git add:*)",
"Bash(git commit:*)",
"Bash(git stash:*)",
"Bash(gh pr view:*)",
"Bash(gh pr list:*)",
"Bash(gh pr diff:*)"
```

Source: inline template at [`../templates/claude-layer/settings.json`](../templates/claude-layer/settings.json) - same shape in repo-A, repo-B, repo-C.

**Why these and only these in the blueprint.** They're read-mostly (`status / diff / log / show / fetch / branch / checkout`) plus the two write-but-safe operations (`add`, `commit`, `stash`). `stash` is included because it's reversible. `commit` is included because the precommit-auditor agent gates commits via `/<prefix>-audit`. `gh pr view / list / diff` is read-only PR access for the architect / reviewer agents.

### Extensions for Dart / Flutter repos

Repos using FVM and melos extend with:

```json
"Bash(fvm dart:*)",
"Bash(fvm flutter:*)",
"Bash(fvm use:*)",
"Bash(dart pub get:*)",
"Bash(dart run build_runner:*)",
"Bash(dart format:*)",
"Bash(dart analyze:*)",
"Bash(dart test:*)",
"Bash(melos bootstrap:*)",
"Bash(melos run:*)"
```

The toolchain canon recorded in `claude-architecture.md` determines what to use - FVM yes/no, melos yes/no. Pick one form and apply it everywhere. See [architecture-doc.md](architecture-doc.md) §"Toolchain canon".

### Extensions for `gh` and remote workflows

```json
"Bash(gh pr create:*)",
"Bash(gh issue view:*)",
"Bash(gh issue list:*)",
"Bash(gh api:*)",
"Bash(gh auth status:*)"
```

Add `gh pr create` only when contributors expect agents to open PRs - without it the `gh pr create` invocation prompts each time.

### Per-repo additions

repo-A's `permissions.allow` adds `docker build/run/compose`, `git submodule`, `git rev-list`, `git rev-parse`, and Dart MCP entries (`mcp__dart__dart_format`, etc.). Repo-C adds `npm install / run` for the functions package. These are repo-specific - add what the team actually runs, not what they might.

### Why `git push` is deliberately OFF

`git push *` is **not** on the allowlist - every `git push` prompts the user (human is the gate), and GitHub branch protection covers the remote. A `PreToolUse` push-guard would duplicate both. Full rationale + reversal criterion: [enforcement-hooks.md](enforcement-hooks.md) §"Why NO `git push` guard hook".

### Don't allow arbitrary `Bash(*)`

❌ `"Bash(*)"` - allows every Bash invocation without prompt. Deletes the entire guard layer; `rm -rf` and `git push --force` both proceed silently.

✅ Specific allowlisted prefixes (`Bash(git diff:*)`, `Bash(fvm dart:*)`). The `:*` suffix allows any flags / args after the matched prefix.

## MCP server declaration

The `enabledMcpjsonServers` field activates MCP servers declared in a separate `mcp.json` file. **Only declare servers that are actually installed.**

```json
"enabledMcpjsonServers": [
  "<prefix>-dart",
  "<prefix>-chrome-devtools"
]
```

### The rule

> **Don't reference an MCP server that isn't installed.**

A declared-but-uninstalled server adds noise to the allowlist (the corresponding `mcp__<server>__*` permissions go nowhere) and confuses agents whose prompts reference tools they can't call.

### Precedent - repo-C's deliberate rejection

Repo-C deliberately does NOT declare a Dart MCP server, despite repo-B and repo-A both having one:

> "**Assume an MCP Dart server.** Alternative. Mirror repo-B's `mcp__<prefix>-dart__*` permissions and agent fallback tables. Case for. Faster iteration, structured diagnostics. Case against here. No MCP Dart server is configured for this repo. Listing permissions for a server that isn't installed pollutes the allowlist; agent prompts referencing absent tools confuse the model. Reversal criterion. A `mcp.json` with a Dart MCP entry lands → wire MCP-preferred / bash-fallback throughout." - `production-repo-C/.claude/docs/claude-architecture.md:147-152`

The cost of declaring an absent server is real: agent prompts written "use `mcp__<prefix>-dart__analyze_files` for analysis; bash `fvm dart analyze` as fallback" leak the absent tool into every relevant agent body. The model attempts the MCP call, it fails, the fallback runs anyway - wasted tokens, wasted turn.

### Where MCP-related permissions go

When the MCP server **is** installed, list its specific tools in `permissions.allow`:

```json
"mcp__<prefix>-dart__dart_format",
"mcp__<prefix>-dart__dart_fix",
"mcp__<prefix>-dart__pub",
"mcp__<prefix>-dart__pub_dev_search",
"mcp__<prefix>-dart__run_tests",
"mcp__<prefix>-dart__resolve_workspace_symbol"
```

Source: repo-A and repo-B `.claude/settings.json`.

Per-tool granularity (not `mcp__<prefix>-dart__*`) is the convention - explicit beats wildcard, and a new tool added upstream shouldn't auto-elevate without review.

### Where the MCP server itself is declared

`enabledMcpjsonServers` references servers from a sibling `mcp.json` (or `.mcp.json`) file. The `mcp.json` schema and per-server `command` / `args` are outside this skill's scope - see Claude Code MCP documentation. The settings.json wiring just says "enable these named servers".

## Hooks block

Wires `<prefix>_quality_check.sh` and `<prefix>_skills_drift.sh` to `PostToolUse` on edit operations.

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

### The matcher

`"Edit|Write|MultiEdit"` is the pipe-separated tool list. Project quality-check hooks rarely match anything else - the surface where path nudges matter is file edits.

A `Bash` matcher would fire on every shell command (too noisy for nudges). A `Read` matcher would fire on every file read (no edit to surface a skill for). Edits are the right scope.

### The command line

```
bash "${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_quality_check.sh"
```

`${CLAUDE_PROJECT_DIR}` is the Claude-set env var pointing at the repo root. Always use it - never hard-code an absolute path like `/Users/<name>/IdeaProjects/<repo>/...`, which breaks the moment a contributor checks out the repo to a different path.

The script path is repo-relative under `.claude/scripts/`. The bash invocation runs with stdin piped from Claude (containing the JSON payload with `.tool_input.file_path`).

### Multiple hooks under one matcher

Both scripts under one `matcher` block means both fire on every matching tool call. Each guards its own scope independently (`quality_check` short-circuits on non-`.dart`; `skills_drift` short-circuits on non-`.md`-under-`.claude`).

Production variance: repo-A wires both scripts; repo-B and repo-C wire only `quality_check` and run the drift scan via `/<prefix>-audit-skills` instead. Wiring both is the blueprint default - the drift script's hook mode costs one silent `exit 0` on out-of-scope edits.

### SessionStart hook (when justified)

A separate top-level key under `hooks`:

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

Only add when a measurable local-resource leak is observed - see [enforcement-hooks.md](enforcement-hooks.md) §"When to add a SessionStart hook" for the rule. Only one production repo currently uses this - see [enforcement-hooks.md](enforcement-hooks.md).

## `settings.local.json` - the un-committed override

A sibling file at `.claude/settings.local.json`, gitignored. Same JSON shape; values override the committed `settings.json`.

### When to use `settings.local.json`

| Use case | Why |
|----------|-----|
| Machine-local secrets | API tokens for personal MCP servers, contributor-specific test credentials. Never commit these. |
| Trying out a plugin | Enable a plugin at local scope to validate it before committing the choice. |
| Per-contributor preferences | A contributor wants stricter `<PREFIX>_QUALITY_MODE=block`; doesn't want to impose it on the team. |
| Experimental hook | A team member is iterating on a new hook script not yet ready for the team. |

### When NOT to use `settings.local.json`

| Anti-use | Why |
|----------|-----|
| Team-wide hook wiring | Will drift across contributors - some have it, some don't, the team can't reproduce each other's behaviour. |
| `permissions.allow` entries needed by every agent invocation | If one contributor's session lacks the permission, the agent fails on their machine and passes on others. Confusing. |
| Plugin enablement the codebase assumes | Same problem - codebase cross-links assume the plugin loaded; missing on one machine = broken context. |

Anything the **codebase** assumes belongs in `settings.json`. Anything the **contributor** prefers belongs in `settings.local.json`.

## Anti-patterns

### Allowing `git push` in `permissions.allow`

❌ `"Bash(git push:*)"` - defeats the human-as-gate model the blueprint relies on.

✅ Leave it off. Branch protection + per-call prompt is the two-layer guard. See [enforcement-hooks.md](enforcement-hooks.md) §"Why NO `git push` guard hook".

### Declaring an MCP that's not installed

❌ `"enabledMcpjsonServers": ["dart"]` when no `dart` server is configured in `mcp.json`. Agent prompts reference tools that fail. Either install the MCP or remove the declaration. Full symptom + reversal: [evolution-and-drift.md](evolution-and-drift.md) §P.

### Hard-coding absolute paths in the hooks block

❌ `"command": "bash /Users/alice/IdeaProjects/myrepo/.claude/scripts/myrepo_quality_check.sh"` - breaks the moment any other contributor checks out the repo.

✅ `"command": "bash \"${CLAUDE_PROJECT_DIR}/.claude/scripts/<prefix>_quality_check.sh\""` - the env var resolves correctly per session. Quote the path for filenames with spaces.

### Putting team-wide settings in `settings.local.json`

❌ A team member adds a critical permission or hook to `settings.local.json` because "I don't want to bother the team with a PR." Result: that contributor's session works; everyone else's doesn't.

✅ Team-wide settings → committed `settings.json`. Per-contributor settings → `settings.local.json`. The dividing line is "does the codebase assume this?"

### Permissions list that allows arbitrary `Bash(*)`

❌ `"Bash(*)"` in `permissions.allow`. Every Bash invocation runs without prompt, including destructive ones. Removes the entire guard layer.

✅ Specific allowlisted prefixes. The `:*` suffix matches any arguments after the prefix - that's the wildcard you want, not bare `*`.

### MCP wildcard permissions

❌ `"mcp__<prefix>-dart__*"` - allows every tool from that MCP server, including future tools added upstream without review.

✅ Per-tool entries. Explicit beats wildcard for security-adjacent allowlists.

### Skipping `$schema` for editor support

❌ Omitting the `"$schema"` line. Editors that support JSON Schema lose autocomplete + validation, contributors hand-edit and typo silently.

✅ Include `"$schema": "https://json.schemastore.org/claude-code-settings.json"`. Free correctness for zero cost.

### Drift between marketplace key and plugin reference

❌ `extraKnownMarketplaces` key is `utopia-flutter-skills`, but `enabledPlugins` references `utopia-hooks@utopia-skills`. The plugin won't load - the marketplace key has to match.

✅ Use the same name on both sides. If you rename one, rename both.

## See also

- [enforcement-hooks.md](enforcement-hooks.md) - what `<prefix>_quality_check.sh` and `<prefix>_skills_drift.sh` actually do; the no-push-guard rationale
- [layer-model.md](layer-model.md) - project scope vs user/local scope; foundation plugin assumption
- [bootstrap-procedure.md](bootstrap-procedure.md) - applying this shape to a new repo (which fields to fill, validation step)
- [architecture-doc.md](architecture-doc.md) - toolchain canon (FVM/melos) propagation to `permissions.allow`
- [claude-md.md](claude-md.md) - how the foundation install command surfaces in CLAUDE.md alongside the settings.json declaration
- Inline template: [`../templates/claude-layer/settings.json`](../templates/claude-layer/settings.json) - canonical shape; sed `<repo>` → project prefix, then commit
- Inline template map: [`../templates/TEMPLATES.md`](../templates/TEMPLATES.md) - target path + substitution columns
