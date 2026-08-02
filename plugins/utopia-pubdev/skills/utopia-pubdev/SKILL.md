---
name: utopia-pubdev
description: >
  Compose and standardize pub.dev READMEs for Dart/Flutter packages -
  brand-profile-driven header image and restrained badge row, house voice,
  section structure (minimal vs full tiers), a no-sponsor footer with sibling
  links, and a tool-agnostic "AI assistants" section. Resolves branding from
  the repo's docs/pubdev-brand.md, auto-applies the bundled Utopia profile in
  detected Utopia codebases, and interviews the user before composing when
  neither exists. Bundles the Utopia brand-chip header generator (package name
  to a Clay PNG via headless Chrome). Applies when creating or refreshing a
  package's README.md or its docs/header.png. NOT for app/screen code, Dart
  public API design, doc sites, or CHANGELOG/pubspec content.
---

# utopia-pubdev - package README & brand standard

The presentation layer for Dart/Flutter open-source packages: how a package
looks and reads on pub.dev and GitHub. Distilled from a 12-package
cross-analysis (bloc, riverpod, Very Good Ventures, dio, freezed, and the
Utopia flagships). The composition rules below are generic; everything
brand-specific - attribution, publisher, lints badge, header image, house
mark - comes from a **brand profile**, never from this file.

## When to apply

**Use when:** writing a new package README, refreshing a stub/boilerplate README,
adding or regenerating the header image, or adding the badge row / sibling
footer / AI-assistants section to a Dart/Flutter package.

**Do NOT use for:** Flutter app/screen code or Dart public-API design (that's the
package's own concern), the `.claude/` architecture layer (`utopia-ai-arch`),
doc-site content, or CHANGELOG/pubspec authoring.

## Brand profile - resolve FIRST

Before composing anything, resolve the brand profile, in this order:

1. **`docs/pubdev-brand.md` at the repo root** - the committed profile. Always
   wins when present, including in Utopia repos.
2. **Utopia detection** - the bundled [utopia-brand.md](references/utopia-brand.md)
   applies when the codebase is verifiably Utopia's: any **strong** signal
   (pubspec `repository`/`homepage` under `github.com/Utopia-USS`, or publisher
   `utopiasoft.io` in existing badges/READMEs), or **both weak** signals
   together (`utopia_` package-name prefix AND a `utopia_lints` dependency).
   A lone `utopia_` prefix is NOT enough - a fork keeps the prefix without the
   brand.
3. **Neither → stop and ask.** Never compose on invented branding. Derive what
   the repo already answers (org, repo URL, license, existing README
   conventions), then ask the user the remaining profile questions before
   continuing - the question list and file template are in
   [brand-profile.md](references/brand-profile.md) - and offer to save the
   answers as `docs/pubdev-brand.md` (the `pubdev-brand-setup` skill in this
   plugin is that interview).

The profile supplies: attribution line, pub.dev publisher domain, lints
package, badge palette, header-image policy, house mark, sibling sources, and
AI-assistants wording. Schema and template:
[brand-profile.md](references/brand-profile.md).

## Brand voice

Engineer-to-engineer, pragmatic, confident, calm. Code-first, why-before-how, zero
hype. Match Very Good Ventures' consistency and terseness; keep pedagogical
depth for flagship packages only.

- DO: open with one grounded sentence, then a working snippet; explain design
  choices plainly; right-size (utils stay short, flagships teach); 2nd person for
  instructions, 3rd for concepts.
- DON'T: "The goal of this package is to…", marketing adjectives, emoji in the H1,
  em dashes (use a hyphen instead), badge clutter, walls of prose before the first code block,
  invented API.

A **house mark** (an emoji or glyph the profile may define - Utopia's is the 👾
alien) is a sparing brand accent: a section heading or the Contributing line,
never the H1. No mark in the profile → no mark in the README.

Ground every API name, type, and example in the package's real source. Accurate
brevity beats impressive-but-wrong.

## README structure → [readme-structure.md](references/readme-structure.md)

Two layers: a **strict visual contract** (header + footer, identical across a
family's packages) and **content guidance** that right-sizes by tier (Minimal vs
Full). The reference carries the header/footer order, the always-present
`# package_name` H1 rule, when each body section is optional, and the
ref-style-links-at-bottom rule. Read it before composing.

## Header: image + badges

The **header image** follows the profile's policy: the Utopia profile generates
the brand chip (`docs/header.png` - see "Generating the header"); another org
ships its own asset or none at all. The rule is invariant: legible on both
pub.dev themes, generated or exported - never hand-drawn - flush-left at
natural width. Utopia's visual recipe: [brand-spec.md](references/brand-spec.md);
live gallery: [docs/gallery.html](docs/gallery.html).

Beneath it, a **restrained** badge row - not BLoC's 13. Default:
`pub version` · `publisher` · `license` · `style: <lints>`, with the publisher
domain and lints package taken from the profile (no source in the profile →
drop that badge, a shorter row is correct). Snippets + rules (and why
likes/points/popularity are skipped): [badges.md](references/badges.md).

## Footer (no sponsors)

Sponsor blocks belong to individual-maintainer OSS; company-backed packages use
the "company is the implicit backer" model - an attribution line from the
profile, never a sponsor block. A light **sibling list** (3-5 related packages,
not a 27-row table), the attribution line, then short Contributing + License.
Nothing forced; utils may keep only License. Shapes in
[readme-structure.md](references/readme-structure.md#footer).

## AI assistants section

Add it **only to packages that ship a dedicated skill or agent rules** - the
profile says which packages qualify and how they install (Utopia:
`AGENTS.md` + the skills marketplace). Keep it **tool-agnostic**, never branded
to one assistant. Packages without a skill get nothing here, not a generic
filler; a profile without an `ai_assistants` mechanism omits the section
entirely. Wording skeleton in
[readme-structure.md](references/readme-structure.md#ai-assistants).

## Generating the header image (Utopia profile only)

The chip generator is bundled in `scripts/` (needs `node` + `puppeteer-core` and
a local Chrome). From a repo root:

```sh
cd skills/utopia-pubdev/scripts
npm i puppeteer-core            # once
python3 generate.py --repo /path/to/repo     # discovers packages, writes <pkg>/docs/header.png + manifest.json
```

`generate.py` discovers publishable packages, renders each chip at its natural
width, and places `docs/header.png`. It does NOT edit READMEs - the `<img>` tag,
width, and the rest of the README follow [readme-structure.md](references/readme-structure.md).
Per-package details (display width etc.) land in the emitted `manifest.json`.
The generator renders the Utopia mark - do not run it for a non-Utopia profile.

## Foundation cross-link

This is presentation only. Package *content* and idioms come from the package
family's own foundation - for Utopia hook-based packages the voice and patterns
defer to
[`utopia-hooks`](https://github.com/Utopia-USS/utopia-flutter-skills/tree/main/plugins/utopia-hooks).
Do not restate a foundation's conventions here.
