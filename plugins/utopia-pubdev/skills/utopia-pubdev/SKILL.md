---
name: utopia-pubdev
description: >
  Compose and standardize pub.dev READMEs for Utopia Dart/Flutter packages -
  the brand-chip header, house voice, section structure (minimal vs full tiers),
  a restrained badge set (incl. style: utopia_lints), a no-sponsor footer with
  sibling links, and a tool-agnostic "AI assistants" section. Bundles the
  brand-chip header generator (package name to a Clay PNG via headless Chrome).
  Applies when creating or refreshing a Utopia package's README.md or its
  docs/header.png. NOT for app/screen code, Dart public API design, doc sites,
  or CHANGELOG/pubspec content.
---

# utopia-pubdev - package README & brand standard

The presentation layer for Utopia open-source packages: how a package looks and
reads on pub.dev and GitHub. Distilled from our own best READMEs (utopia_hooks,
utopia_cms) plus Riverpod, BLoC, and Very Good Ventures.

## When to apply

**Use when:** writing a new package README, refreshing a stub/boilerplate README,
adding or regenerating the brand-chip header image, or adding the badge row /
sibling footer / AI-assistants section to a Utopia package.

**Do NOT use for:** Flutter app/screen code or Dart public-API design (that's the
package's own concern - for hook-based packages defer to
`utopia-hooks:SKILL.md`), the `.claude/` architecture layer (`utopia-ai-arch`),
doc-site content, or CHANGELOG/pubspec authoring.

## Brand voice

Engineer-to-engineer, pragmatic, confident, calm. Code-first, why-before-how, zero
hype. Match Very Good Ventures' consistency and terseness; keep our pedagogical
depth on flagship packages only.

- DO: open with one grounded sentence, then a working snippet; explain design
  choices plainly; right-size (utils stay short, flagships teach); 2nd person for
  instructions, 3rd for concepts.
- DON'T: "The goal of this package is to…", marketing adjectives, emoji in the H1,
  em dashes (use a hyphen instead), badge clutter, walls of prose before the first code block,
  invented API.

The 👾 alien is the house mark (it leads our plugin / marketplace descriptions). Use it
sparingly as a brand accent - a section heading or the Contributing line - never in the H1.

Ground every API name, type, and example in the package's real source. Accurate
brevity beats impressive-but-wrong.

## README structure → [readme-structure.md](references/readme-structure.md)

Two layers: a **strict visual contract** (header + footer, identical across packages)
and **content guidance** that right-sizes by tier (Minimal vs Full). The reference
carries the header/footer order, the always-present `# package_name` H1 rule, when each
body section is optional, and the ref-style-links-at-bottom rule. Read it before composing.

## Header: brand chip + badges

The **brand chip** (`docs/header.png`) is the hero and the thing that makes a
package readable on both pub.dev themes - generate it, never hand-draw it
(see "Generating the header"). Visual recipe: [brand-spec.md](references/brand-spec.md);
live gallery (the chip across all packages, light + dark): [docs/gallery.html](docs/gallery.html).

Beneath it, a **restrained** badge row - not BLoC's 13. Default:
`pub version` · `license` · `style: utopia_lints`. Snippets + rules (and why we
skip likes/points/popularity): [badges.md](references/badges.md).

## Footer (no sponsors)

We have no patrons - use the VGV "company is the implicit backer" model, never a
sponsor block. A light **sibling list** (3-5 related packages, not a 27-row
table), a one-line "Built by UtopiaSoftware" attribution, then short Contributing +
License. Nothing forced; utils may keep only License. Shapes in
[readme-structure.md](references/readme-structure.md#footer).

## AI assistants section (our differentiator)

Utopia ships agent rules/skills that work across agentic tools (via `AGENTS.md`
and the skills marketplace) - keep this section **tool-agnostic**, never branded
to one assistant. Add it **only to packages that have a dedicated skill**
(utopia_hooks, utopia_arch → the hooks skill; utopia_cms → the cms skill).
Packages without one get nothing here, not a generic filler. Wording in
[readme-structure.md](references/readme-structure.md#ai-assistants).

## Generating the header image

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

## Foundation cross-link

This is presentation only. Package *content* and idioms come from the foundation:
for hook-based packages the voice and patterns defer to
[`utopia-hooks`](https://github.com/Utopia-USS/utopia-flutter-skills/tree/main/plugins/utopia-hooks).
Do not restate hook/Screen-State-View conventions here.
