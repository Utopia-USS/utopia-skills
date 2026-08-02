---
name: brand-setup
description: >
  Set up or update a repo's pub.dev branding profile - derives what the repo
  already answers (org, repo URL, publisher, lints, existing README
  conventions), interviews the user for the gaps, and writes
  docs/pubdev-brand.md for the utopia-pubdev:readme README standard to consume.
  Applies when a non-Utopia Dart/Flutter repo adopts the README standard, when
  the utopia-pubdev:readme skill finds no profile, or when an existing profile
  needs changing. NOT needed in Utopia codebases (the bundled Utopia profile
  auto-applies) and NOT for composing the README itself (that's
  utopia-pubdev:readme).
---

# utopia-pubdev:brand-setup - branding profile interview

One-time per repo: produce `docs/pubdev-brand.md`, the brand profile the
`utopia-pubdev:readme` README standard reads. Schema, field semantics, and the
file template live in
[brand-profile.md](../readme/references/brand-profile.md) - this skill is the
flow that fills it in.

## Flow

1. **Check what already applies.**
   - `docs/pubdev-brand.md` exists → update mode: show the current profile,
     ask what changes, edit only that.
   - The repo is detected as Utopia's (rule in
     [brand-profile.md](../readme/references/brand-profile.md#resolution-order))
     → say so; the bundled profile already applies. Only write a file if the
     user explicitly wants an override.

2. **Derive before asking.** From the repo, not the user:
   - `org` + `repo_org` - pubspec `repository`/`homepage`, the git remote.
   - `publisher` - existing pub.dev badges/links in READMEs, or the pub.dev
     page of an already-published package from this repo.
   - `lints` - a shared `*_lints` / analysis-options dependency across
     packages.
   - `header_image` + badge conventions - what existing READMEs already do.

3. **Ask only the gaps - in one message, not a drip.** Attribution wording,
   publisher (if underivable; `none` is a fine answer), lints package or none,
   header-image policy (`asset` or `none` - the Utopia chip generator is
   Utopia-only), house mark or none, sibling selection, AI-assistants
   mechanism or none. Never invent a value: an unverifiable publisher or lints
   package becomes `none`, which simply drops that badge.

4. **Confirm once, then write.** Echo the full assembled profile (derived +
   answered) for a single confirmation, then write `docs/pubdev-brand.md` from
   the template in
   [brand-profile.md](../readme/references/brand-profile.md#file-template).
   Committing stays with the user.

5. **Hand off.** README composition itself is the `utopia-pubdev:readme`
   skill - the freshly written profile now resolves first, so it picks the
   branding up automatically.

## Rules

- One profile per repo, applied to every package in it - branding is a family
  property. Don't offer per-package profiles.
- The profile holds brand facts, not composition rules. Structure, tiers, and
  badge policy stay in the standard's references; don't copy them into the
  profile file.
- License is never a profile field - the standard reads each package's LICENSE
  file directly.
