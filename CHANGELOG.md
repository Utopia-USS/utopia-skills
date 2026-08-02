# Changelog

Per-plugin versions live in each plugin's `.claude-plugin/plugin.json`; the marketplace version tracks
the repo as a whole. Entries below cover shipped changes since the previous bump of each component.

## Marketplace 0.10.0

- Palette-friendly skill names: skills no longer repeat their plugin prefix. New invocations:
  `utopia-design:{tokens,sync,import,screen,component}`, `utopia-pubdev:{readme,brand-setup}`,
  `utopia-ai-arch:layer`. `utopia-hooks:utopia-hooks` and `utopia-cms:utopia-cms` stay (single-skill
  plugins keep the plugin name, matching upstream convention).
- Migrate-bloc sub-agents prefixed (`migrate-inventory`, `migrate-foundation`, `migrate-global-state`,
  `migrate-screen`, `migrate-review`) so they cannot collide with a consumer repo's own agents.
- Every plugin manifest gains a `displayName`.
- Anonymization: third-party package/vendor names from the README cross-analysis removed from skill
  content; the standard's lessons and data points remain, unattributed.

## utopia-design 0.3.0

- Skills renamed to `tokens`, `sync`, `import`, `screen`, `component` (were `utopia-design-*`).
  Cross-references, session priming, and the plugin README updated; smoke suite green.

## utopia-pubdev 0.3.0

- Skills renamed: `utopia-pubdev` -> `readme`, `pubdev-brand-setup` -> `brand-setup`.
- Research-citation names scrubbed from the standard's prose (see Marketplace 0.10.0).

## utopia-ai-arch 0.3.0

- Skill renamed: `utopia-ai-arch` -> `layer`.

## utopia-hooks-migrate-bloc 0.4.0

Field-driven redesign after the Hacki stress test (5 attempts, Phase A-only outcomes, two branches
ending in a commit named "hell"). Deal-breakers fixed:

- **Service extraction (Phase A0).** When domain logic lives in the Cubit itself (no service has it),
  the `migrate-global-state` agent returns `needs_service_extraction` + a service sketch instead of
  duplicating business logic into the hook; new `extract_service` mode produces a behavior-preserving
  `refactor: extract <XService>` commit first. New reference section in `global-state-migration.md`.
- **Deferred provider registration.** Phase A no longer registers states in `_providers.dart` -
  `HookProviderContainer` builds providers eagerly, so early registration ran hook + old Cubit side by
  side (double fetches/subscriptions). The entry now lands with the first migrated consumer screen
  (orchestrator step 2a, with post-apply stem verification; review §J split into Phase A/B expectations).
- **Behavioral gate.** `flutter test` baseline at startup, "zero new failures" gate per batch, §4g
  manual smoke checklist surfaced in the final report; new Exit Gate item in SKILL.md.
- **Staged god-screen protocol.** Oversized screens (Cubit > ~600 LoC, manifest > ~12 files) get a
  multi-commit staged plan (`migrate-prep:` commits + final rewiring) instead of a one-shot migration.
- **Deterministic Phase B ordering** (simple before complex, enforced by the orchestrator) and
  crash-recovery Step 0 (dirty-tree reconciliation before inventory).
- **Enforcement hook actually reaches the model:** `screen_gate.sh` moved from the exit-code contract
  (exit 1 stderr never reached Claude - the gate was a silent no-op in default mode) to PostToolUse
  JSON output (`additionalContext` in warn mode, `decision: block` in block mode).
- Harness drift: Dart MCP probe is ToolSearch-aware (deferred MCP tools no longer read as "missing"),
  `TodoWrite` -> `TaskCreate`/`TaskUpdate`, stale `MultiEdit` matcher dropped, orchestrator no longer
  pinned to sonnet (inherits session model), `migrate-global-state`/`migrate-screen`/`migrate-review`
  moved to opus.
- New `--finalize` mode: reviewed cleanup commits removing deprecated Cubits, BLoC packages,
  BlocObserver, plus a repo-wide exit-gate sweep.
- Review hardening: red size thresholds are hard fails (including Phase A globals - a 550-line 1:1
  Bloc port must not pass again); per-commit full `migrate-inventory` re-runs replaced by deterministic
  MIGRATION.md edits (full re-scans only at phase boundaries).
- Inventory MIGRATION.md template fully in English; global states now tracked as
  `registered` / `pending registration`.
- Cross-session work log: `MIGRATION.md` gains an append-only `## Session journal` section
  (preserved by inventory like Skipped); the orchestrator appends a resume brief per session
  (Step 8b) - migrations spanning many sessions no longer re-derive context.

## utopia-hooks-migrate-bloc 0.3.0

- The five sub-agents renamed with the `migrate-` prefix; orchestrator and docs updated.

## utopia-hooks 0.4.2, utopia-cms 0.3.1, utopia-dart-lsp 0.1.2, utopia-reviews 0.1.1

- `displayName` added to plugin manifests; utopia-reviews swept for em dashes (130 across skills,
  references and commands, plus the manifest descriptions) and its Codex manifest synced to 0.1.1.

## Marketplace 0.9.0

- `utopia-pubdev` entry description and version synced to the generalized plugin (0.2.0).

## utopia-pubdev 0.2.0

- The README standard is no longer Utopia-only: composition rules stay generic and all
  brand values move to a **brand profile**. Resolution order: a committed
  `docs/pubdev-brand.md` always wins; a detected Utopia codebase gets the bundled Utopia
  profile; with neither, the skill interviews the user before composing.
- New `brand-setup` skill: derives what the repo already answers, asks only the
  gaps, and writes `docs/pubdev-brand.md`.
- New references: `brand-profile.md` (schema, resolution order, Utopia detection - a lone
  `utopia_` prefix is not enough, forks keep the prefix without the brand) and
  `utopia-brand.md` (the extracted Utopia profile). `readme-structure.md` and `badges.md`
  parameterized on the profile; `brand-spec.md` and the chip generator stay Utopia-only.

## Marketplace 0.8.0

- Per-plugin READMEs with generated brand-chip headers for all 7 plugins.
- Root README: `utopia-dart-lsp` added to the plugin table and install block; `utopia-design` tile added.
- Marketplace metadata (`description`, `version`) hoisted from `metadata` to top level.
- `utopia-dart-lsp` entry no longer duplicates the `lspServers` block (plugin.json is the authority).
- Marketplace entry descriptions for `utopia-ai-arch` and `utopia-hooks-migrate-bloc` synced to their
  canonical plugin.json descriptions.
- CI workflow running `claude plugin validate --strict` and the utopia-design hook smoke suite.

## utopia-hooks 0.4.1

- SKILL.md description gains an explicit negative-scope clause (migration and CMS concerns route to
  their sibling plugins).
- `scripts/session_start.sh` is executable again; unwired `scripts/dart_analyze.sh` removed.
- SessionStart hook also fires on forked sessions (`fork` matcher source).
- Delivers the 2 doc commits shipped since 0.4.0.

## utopia-cms 0.3.0 (Codex manifest sync)

- `.codex-plugin/plugin.json` version aligned to 0.3.0.
- The PostToolUse quality gate now fails loudly (stderr + exit 1) when `jq` is missing instead of
  silently disabling itself.
- SKILL.md description gains a negative-scope clause; version-pinned prose de-pinned.
- SessionStart hook also fires on forked sessions.

## utopia-ai-arch 0.2.1

- Em-dash sweep across the skill, references and templates (house style: hyphens).
- The plan/ship/team workflow command templates are now reachable from the bundle inventories.

## utopia-hooks-migrate-bloc 0.2.6

- `/utopia-hooks-migrate-bloc:migrate` loads its skill via `${CLAUDE_PLUGIN_ROOT}` (was a
  repo-root-relative path that failed for installed users).
- All cross-plugin `../../../utopia-hooks/...` markdown links replaced with install-safe references
  resolved per the skill's "Resolving reference paths" section; pseudo-scheme link removed.
- The dart-analyze fallback uses the plugin's own bundled script.
- Em-dash sweep (including user-visible hook strings); sub-agent count corrected in the orchestrator.

## utopia-pubdev 0.1.1

- The skill now practices its own no-em-dash rule (H1 and body sweep).
- Prescribed attribution line unified to "Built by UtopiaSoftware".

## utopia-dart-lsp 0.1.1

- Braced `${CLAUDE_PLUGIN_ROOT}` in the LSP launch args (documented substitution form).

## utopia-design 0.2.0

- First version bump since the scaffold: delivers the full run of post-scaffold corrections
  (CLI pinning, validate_twin auto-partial mode, gap-reporting corrections, skills-review fixes).
- All five skill descriptions compressed under the 1024-char validation limit with the negative-scope
  clause intact.
- SKILL.md files state where the protocol documents (SPEC.md / VERSIONING.md) live and how to proceed
  when they are absent.
- plugin.json description synced to the marketplace entry (includes the utopia-design-component skill).
- SessionStart hook also fires on forked sessions.
