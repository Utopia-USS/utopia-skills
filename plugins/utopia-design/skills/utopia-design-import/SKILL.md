---
name: utopia-design-import
description: >
  Bring an external design source into a utopia_ui project's
  design/tokens.json - a Figma DTCG export, a foreign tokens.css / Tailwind
  @theme file, a Claude Design / claude.design handoff bundle directory, or a
  DESIGN.md file. Also applies when the project does not resolve utopia_ui
  yet, where it stops at its usage gate and surfaces install guidance
  instead of acting. Reads the source, maps its values onto the closed
  utopia token tree, produces a mapping proposal and diff, then applies
  through the tokens skill's edit-and-validate loop. Applies when: identifying an
  external source's type and parsing its values; mapping external values
  onto design/tokens.json paths; reporting unmapped external tokens or
  uncovered utopia slots as gaps; running a re-import 3-way diff against
  values already synced once. Concrete triggers: "import tokens", "Figma
  export", "tokens.css", "Tailwind theme", "design handoff", "DESIGN.md",
  "bring in a design". Does NOT cover hand-editing design/tokens.json without
  an external source (-> utopia-design-tokens), regenerating the Flutter
  theme or the HTML twin (-> utopia-design-sync), building screens from a
  design (-> utopia-design-screen), or a Figma write-API sync (out of v0
  scope - Figma is handled only via the DTCG file-export path). Layered on
  top of the upstream utopia-hooks plugin - stays silent on Screen/State/View
  / hooks / Dart conventions (foundation concerns).
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, utopia_ui, design-tokens, import, figma, dtcg, tailwind, design-handoff, three-way-diff, claude-design
---

# Skill: Utopia Design Import

## Overview

This skill brings an outside design source into a `utopia_ui` project. See
the frontmatter `description` above for the exact positive/negative
boundary. There is no import command: import is a skill-driven workflow that
reads an external source, maps its values onto the closed utopia token tree,
shows a proposal and diff for review, and only then applies the change by
editing `design/tokens.json` through the same gate **utopia-design-tokens**
uses. This skill owns the read-map-propose steps; it hands off the actual
write to that skill's edit loop.

## Usage Gate (do this first, non-negotiable)

Before touching anything, confirm the project actually resolves `utopia_ui`:
`pubspec.yaml` declares `utopia_ui:` directly, or `pubspec.lock` resolves it
transitively. This is the same gate **utopia-design-tokens** runs, because
there is nothing to import into without the library and its protocol.

- **If it resolves:** continue below.
- **If it does NOT resolve:** stop. Surface this install guidance to the
  user (show the commands; do not add the dependency to their pubspec
  yourself) instead of reading or mapping anything:
  ```bash
  flutter pub add utopia_ui
  flutter pub get
  ```
  Only proceed once the project resolves the package.

## The Import Workflow

1. **Identify the source type.** Figma DTCG export, foreign `tokens.css` /
   Tailwind `@theme` file, a Claude Design / claude.design handoff bundle
   directory, or a `DESIGN.md` file. See [sources.md][sources] for what each
   looks like on disk and where its values live.
2. **Parse and extract its values.** Read the source per its type-specific
   notes in [sources.md][sources]. Don't assume names or structure match the
   utopia tree - that's the next step's job.
3. **Map external values onto the closed utopia tree.** Match each external
   value to a `design/tokens.json` path; collect any external token with no
   matching slot as a GAP, and any utopia slot the source doesn't cover as
   an uncovered slot. See [mapping.md][mapping] for the matching priority,
   value-conversion rules, and gap-reporting discipline.
4. **Produce a mapping proposal and diff, then STOP for review.** Never
   write `design/tokens.json` first. Show a per-token current-value ->
   proposed-value table with its source, plus the gaps and uncovered
   slots, and wait for approval. See [three-way-diff.md][three-way-diff]
   for the exact proposal/diff format and how a re-import against an
   already-synced source is reconciled (conflict modes).
5. **On approval, apply.** Edit `design/tokens.json` following
   **utopia-design-tokens**'s
   [token-profile.md](../utopia-design-tokens/references/token-profile.md)
   shapes, recording sync metadata (`sourceRef`, `lastSyncedValue`,
   `lastSyncedAt`) on every token this import writes. Then run
   `validate_tokens` per that skill's
   [validation.md](../utopia-design-tokens/references/validation.md). This
   skill does not define its own write mechanics - it reuses
   **utopia-design-tokens**'s edit-and-validate loop as the apply gate.
6. **Regenerate surfaces separately.** Once the import lands and validates,
   regenerating the Flutter theme and the HTML twin is
   **utopia-design-sync**'s job, not this skill's. Hand off there; don't
   regenerate anything here.

## When to Apply

- A Figma DTCG token export needs to land in `design/tokens.json`
- A foreign `tokens.css` or Tailwind `@theme` file needs to be read into the
  utopia tree
- A Claude Design / claude.design handoff bundle directory needs its tokens
  and/or `DESIGN.md` mapped in
- A standalone `DESIGN.md` front matter needs to be imported
- Re-running an import against a source already synced once, to reconcile
  drift on both sides

## Out of Scope

- Hand-editing `design/tokens.json` with no external source behind the
  change -> use **utopia-design-tokens**
- Regenerating the Flutter theme or the HTML twin from tokens -> use
  **utopia-design-sync**
- Building or updating a screen from a design -> use **utopia-design-screen**
- A live Figma write-API sync - out of v0 scope; Figma is handled only
  through the DTCG file-export path, never a write-back integration

## Priority-Ordered Guidelines

| Priority | Reference | Impact | Description |
|----------|-----------|--------|-------------|
| 1 | [sources.md][sources] | CRITICAL | What each of the four source types looks like, where its values live, and how to extract them |
| 2 | [mapping.md][mapping] | CRITICAL | Matching external values onto the closed utopia tree, value conversion, and gap reporting |
| 3 | [three-way-diff.md][three-way-diff] | HIGH | The proposal/diff format shown before any write, sync metadata, and re-import conflict handling |

## Non-Negotiable Rules

- **Verify `utopia_ui` resolves before reading or mapping anything** (the
  usage gate above).
- **Never silent.** A mapping proposal and an explicit diff of what would
  change in `design/tokens.json` MUST be shown and approved BEFORE any write
  (SPEC.md section 6.2). This is the core contract of this skill.
- **Map onto the closed tree only.** External tokens with no utopia slot are
  reported as gaps, never invented as new token names (SPEC.md section 2.2).
- **Record 3-way-diff sync metadata** (`sourceRef`, `lastSyncedValue`,
  `lastSyncedAt`) on every token an import writes, so a later re-import can
  detect conflicts (SPEC.md sections 2.6, 6.2).
- **Default conflict mode is `ask`** - report the conflict, write nothing
  for that token. `theirs` / `ours` / `skip` apply only on an explicit
  choice, never as a silent default.
- **Apply through `validate_tokens`**, the same gate **utopia-design-tokens**
  uses. Never hand-edit the generated Flutter theme or twin CSS to make an
  import "work faster."
- **Preserve `$extensions` round-trip.** Foreign vendor namespaces (e.g.
  `com.figma.*`) stay untouched by any import edit (SPEC.md sections 2.1,
  2.6).

## Self-Audit Checklist

After running an import, verify:

1. A mapping proposal and an explicit diff were shown and approved before
   any write to `design/tokens.json`.
2. Every changed token traces to a specific external source value or an
   explicit conflict-mode decision - nothing changed without a reason.
3. Gaps (unmapped external tokens) and uncovered slots (utopia paths the
   source didn't touch) were both reported.
4. Sync metadata (`sourceRef`, `lastSyncedValue`, `lastSyncedAt`) was
   written on every token this import touched.
5. `validate_tokens` passes (or every reported finding has been addressed).
6. `$extensions` data - including foreign vendor namespaces - is preserved.

## See Also

- **utopia-design-tokens** - the edit-and-validate loop this skill hands off
  to for the actual write; its
  [token-profile.md](../utopia-design-tokens/references/token-profile.md) is
  the mapping target and its `validate_tokens` contract is the apply gate.
- **utopia-design-sync** - regenerate the Flutter theme and the HTML twin
  once an import lands and validates.
- **utopia-design-screen** - build screens from manifest components; not
  this skill's concern.
- **utopia-hooks** - owns app/state concerns (Screen/State/View, hooks, DI);
  this skill stays silent on all of it.

## Attribution

Built on [utopia_ui](https://pub.dev/packages/utopia_ui) and the Utopia
Design Protocol, by UtopiaSoftware.

[sources]: references/sources.md
[mapping]: references/mapping.md
[three-way-diff]: references/three-way-diff.md
