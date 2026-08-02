# Changelog

Per-plugin versions live in each plugin's `.claude-plugin/plugin.json`; the marketplace version tracks
the repo as a whole. Entries below cover shipped changes since the previous bump of each component.

## Marketplace 0.9.0

- `utopia-pubdev` entry description and version synced to the generalized plugin (0.2.0).

## utopia-pubdev 0.2.0

- The README standard is no longer Utopia-only: composition rules stay generic and all
  brand values move to a **brand profile**. Resolution order: a committed
  `docs/pubdev-brand.md` always wins; a detected Utopia codebase gets the bundled Utopia
  profile; with neither, the skill interviews the user before composing.
- New `pubdev-brand-setup` skill: derives what the repo already answers, asks only the
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
