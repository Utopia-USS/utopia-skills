<img src="docs/header.png" width="242" alt="Utopia AI Arch"/>

[![license: BSD-2-Clause][license_badge]][license_link]

# utopia-ai-arch

A Claude Code plugin that creates and maintains a Flutter repo's `.claude/` layer - agents, skills, slash commands, enforcement hook scripts, `settings.json` permissions, refs, CLAUDE.md / AGENTS.md, and the `claude-architecture.md` decision log.

The plugin itself ships no hooks, commands, or agents. Everything beyond the skill is blueprint content that the skill fills in and installs into the target repo.

## What's inside

The `utopia-ai-arch` skill, plus 10 reference files: the two-layer model, the 4-agent roster, skill design, enforcement hooks, evolution and drift (a 21-symptom catalogue distilled from production layers), slash commands, the architecture doc, CLAUDE.md conventions, the bootstrap procedure, and the `settings.json` shape.

And a `templates/` tree - the claude-layer blueprint:

- 4 agent templates: `<prefix>-architect` (read-only planner), `<prefix>-maintainer` (the only writer), `<prefix>-reviewer` (read-only post-implementation review, output classified BLOCKER / WARN / NIT), `<prefix>-precommit-auditor` (read-only staged-diff gate).
- 3 base command templates: `/<prefix>-implement`, `/<prefix>-audit`, `/<prefix>-audit-skills`.
- 2 hook scripts: `<prefix>_quality_check.sh` (Dart conventions + generated-file guard) and `<prefix>_skills_drift.sh` (dead markdown links across `.claude/**/*.md` and CLAUDE.md).
- A `settings.json` shape, an area-skill template, and reference-style conventions (module / pattern / cheatsheet).
- 5 opt-in workflow bundles: plan, team, design, ship, browser-testing.

## Installation

```bash
# Claude Code
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-ai-arch@utopia-flutter-skills
```

No external tools required. (The blueprint hooks it writes into a repo use bash, `jq`, and `git` - a target-repo concern.)

## Usage

**Bootstrapping a new repo's layer** follows the phased procedure: gather context, design the skill split, draft `.claude/docs/claude-architecture.md` first, copy the template shapes and fill the placeholders, wire `settings.json`, trim CLAUDE.md to an inventory, symlink `AGENTS.md` to it, validate.

**Maintaining a live layer** is the day-to-day half: graduate, split, or delete skills as they drift, add path nudges to the quality-check hook, and record rejected alternatives in the decision log so they stay rejected.

**Diagnosing misbehavior** goes through the drift catalogue - the hook that never fires, the skill that stopped triggering, the agent that keeps forgetting a convention.

The hook contract the skill teaches is fixed:

```
exit 0  silent
exit 1  warn
exit 2  block
```

Generated files (`*.g.dart`, `*.freezed.dart`, `*.gr.dart`, `*.pb*.dart`, `*.config.dart`) always exit 2, regardless of mode.

## Related plugins

| Plugin | What it adds |
|---|---|
| [utopia-hooks](../utopia-hooks/) | The foundation this layer assumes - always installed alongside |
| [utopia-hooks-migrate-bloc](../utopia-hooks-migrate-bloc/) | A shipped example of the agent / command / hook shape this skill teaches |
| [utopia-design](../utopia-design/) | The standalone design plugin; a design workflow bundle also ships in these templates |
| [utopia-cms](../utopia-cms/) | Another layered plugin over the same foundation |

Built by [UtopiaSoftware](https://utopiasoft.io).

## Contributing

👾 Issues and PRs welcome - skills are designed to be forked: copy one into your own Claude Code or Codex setup, tweak the rules, ship it.

## License

BSD 2-Clause - see [LICENSE](../../LICENSE).

[license_badge]: https://img.shields.io/badge/license-BSD--2--Clause-2E8B57.svg
[license_link]: ../../LICENSE
