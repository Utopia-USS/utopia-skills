# README structure

One skeleton, two tiers. **Two layers:** the *visual contract* (header + footer) is
fixed - identical across every package in a family, so the family looks like a family.
The *content* (the body) right-sizes to the package. Brand values (attribution,
publisher, lints, header image, house mark) come from the resolved brand profile
([brand-profile.md](brand-profile.md)); examples below show the Utopia profile's
values. Read this before composing; badge rules are in [badges.md](badges.md), the
Utopia chip in [brand-spec.md](brand-spec.md).

Distilled from a 12-package cross-analysis (our hooks/arch/cms + bloc, flutter_hooks,
riverpod, very_good_cli, equatable, mason, dio, go_router, freezed).

## Header

**Visual contract - strict; identical across every package.** Exactly this order:

```
<img src="docs/header.png" width="W" alt="<Org> <Name>"/>    ← header image per profile, flush-left, natural width

[![pub][pub_b]][pub_l] [![publisher][pub2_b]][pub2_l] [![license][lic_b]][lic_l] [![style: <lints>][sty_b]][sty_l]   ← row per profile (badges.md)

# <package_name>                                             ← ALWAYS present, = the pub.dev name

<one grounded sentence: what it is + when to use it>
Visit [<docs site>](…)                                       ← only if a docs site exists

<img src="docs/demo.gif" width="100%" alt="… demo"/>        ← optional; visual / UI / CLI packages only
```

- **H1 is mandatory and is the package name** (`# utopia_hooks` or `# Utopia Hooks`).
  Never `# Overview`, never an H3-as-title, never logo-alt-only. This is the
  highest-signal rule we found: half the most-popular packages (bloc, riverpod, equatable,
  mason, freezed) omit the H1 and it is a real mistake - pub.dev and GitHub use the first
  `# H1` as the title fallback, and web search and screen readers depend on it. No emoji in
  the H1 - including the profile's house mark (Utopia's 👾 belongs in plugin / marketplace
  descriptions and may accent a section heading or the Contributing line, but never the title).
- **Header image** (when the profile ships one), flush-left, natural `width`, never
  `height` / stretch. Generated or exported, never hand-drawn; must stay legible on both
  pub.dev themes. Flush-left (aligns with body text), not centered like the felangel
  packages. `header_image: none` in the profile → the badge row leads.
- **Badges: ref-style markdown**, defs at the bottom (the house form, matches VGV). Not
  inline HTML in `<p align="center">`, not mixed md+HTML. Restrained set, publisher and
  lints values from the profile - see [badges.md](badges.md).
- **Optional GIF / screenshot** right after the one-liner, for packages whose value is
  visual (a demo is credibility before code). Must be **responsive** - `width="100%"` or a
  sane max, never hardcoded `width="960" height="425"` (breaks on narrow viewports).

## Body

**Content - guidance; right-size to the package.**

### Opening sentence

One sentence: **"A `<category>` that `<does X>`"**, what-it-is, general→specific. This is
what ~9 of 12 do ("A predictable state management library…", "A declarative routing
package for Flutter…"). Avoid "Goal of this package is to…" (see brand voice). A
**pain-first** opening is allowed when the package removes a felt boilerplate pain
(equatable, freezed, flutter_hooks open on the pain and land harder for it).

### Sections (Full tier order)

```
## Motivation            ← optional; only when the "why" isn't self-evident (see below)
## Usage                 ← code-first; the first code block comes fast
### See also             ← link to the docs site; keeps the body lean (the flagship pattern)
## Example               ← GIF + code, for visual / widget packages
## AI assistants         ← ONLY if the package has a dedicated skill (see #ai-assistants)
## Related packages      ← light sibling list, 3-5 entries
## Contributing          ← short; link CONTRIBUTING.md
## License               ← optional section; the badge + LICENSE file is the real source

[pub_b]: …               ← all link/badge URLs as ref-style defs at the bottom
```

### Motivation - optional, with a rule

Add `## Motivation` **only when the "why" isn't self-evident** - the package replaces a
tedious manual approach and a reader could ask "why not do it by hand / use X?". equatable
(vs hand-written `==`), freezed (vs boilerplate), utopia_cms (vs no-code) all earn it. An
obvious utility / tool (HTTP client, router, CLI) skips it - a forced Motivation reads as
filler. **When you write one, show don't tell:** a before/after code block or screenshot
(freezed, flutter_hooks, equatable) beats a prose paragraph.

### Flow

Code-first (first real snippet within ~one screen; zero-code READMEs were a flagged
mistake). General→specific top to bottom: intro → (motivation) → quickstart/usage →
feature tour → reference → footer. **"See also" → docs site** to keep the body lean is the
flagship move (bloc, riverpod, vgv, hooks all push depth to a site); utilities don't need one.

### Usage idioms worth stealing (pick what fits)

Before/after comparison; DO/DON'T code blocks for rules; per-scenario titled subsections
with one snippet each (dio); a categorized API/hook catalog table with per-entry pub.dev
links (flutter_hooks, hooks); a GIF demo for visual/CLI packages. Section-level emoji is a
taste call; never in the H1.

## Minimal tier (small utility packages)

For single-purpose utils (e.g. utopia_bytes, utopia_collections, utopia_lints):

```
<img src="docs/header.png" width="W" alt="<Org> <Name>"/>

[![pub]…] [![publisher]…] [![license]…] [![style: <lints>]…]

# <package_name>

<one or two sentences>

## Usage          ← one short, real snippet (or a tight bullet list of the helpers)
## Related packages   ← optional
## License        ← optional
```

No Motivation, no See-also, no AI section unless it genuinely has a dedicated skill. Simple
is correct here - do not pad a 30-line package into a 200-line README. (H1 + the profile's
header image + badge row are still required - the visual contract holds at every tier.)

## Tier selection

- **Minimal:** the package does one obvious thing; the API fits on one screen. (go_router
  at 82 lines, utopia_arch at 66 - correctly minimal.)
- **Full:** flagship / framework-shaped (hooks, cms, arch, cli); has concepts to teach,
  multiple features, or a docs site. (freezed 1441, dio 988, flutter_hooks 398.)

## Footer

**Visual contract - strict.** Exactly this order. No sponsors. (The example shows the
Utopia profile's values - substitute your profile's siblings, attribution line, and
house mark; `house_mark: none` drops the 👾 from the Contributing line.)

```
## Related packages

| Package | What it adds |
|---|---|
| [utopia_hooks](https://pub.dev/packages/utopia_hooks) | State management with hooks |
| [utopia_injector](https://pub.dev/packages/utopia_injector) | Dependency injection |
| [utopia_arch](https://pub.dev/packages/utopia_arch) | The full architecture bundle |

Built by [Utopiasoft](https://utopiasoft.io).

## Contributing

👾 Issues and PRs welcome - see [CONTRIBUTING.md](CONTRIBUTING.md) (drop the link if no such file exists).

## License

MIT (or BSD-2-Clause - match the package's LICENSE). See [LICENSE](LICENSE).
```

- **No sponsors / no funding block.** Only individual-maintainer OSS carries Sponsors
  (bloc, flutter_hooks, riverpod, freezed - all funded personally). Every company-backed
  project (VGV, Utopia) uses an attribution line instead - the profile's `org` field
  (Utopia: `Built by [Utopiasoft](https://utopiasoft.io).`).
- **Related packages:** a small **table** (3-5 rows, `Package | What it adds`) of the most-
  related siblings per the profile's `siblings` field, each with a one-line gloss - a
  static component, not a bullet list. Not the whole family, not a 27-row dump, not a
  catch-all "Community" section. `siblings: none` → drop the section.
- **License:** a full `## License` section is **optional** - most top packages ship only
  the badge + a `LICENSE` file. A utility may drop Contributing and keep just License.

## AI assistants

Tool-agnostic, and a differentiator (almost nobody ships it; the nearest external analog
is very_good_cli's MCP server, which is exactly the open framing to copy). Add **only** to
packages the profile's `ai_assistants` field marks as shipping a dedicated skill (Utopia:
utopia_hooks, utopia_arch → the hooks skill; utopia_cms → the cms skill). Frame it around
the open mechanism (`AGENTS.md`, a skills marketplace, MCP); name assistants as
*examples*, never brand it to one; don't add a filler version to packages without a
skill, and omit the section on every package when the profile has no mechanism.

The Utopia profile's wording:

```
## AI assistants

This package ships agent rules and a skill - the Screen/State/View pattern, the
hook catalog, and anti-pattern guards - usable from any agentic coding tool
(Claude, Codex, Cursor, …) via `AGENTS.md` and the skills marketplace. Add them to a
project with `utopia init agents` / `utopia init skills`, or install the
[Utopia skills marketplace](https://github.com/Utopia-USS/utopia-flutter-skills).
```

Adjust the parenthetical to the package (cms → "CMS delegates, table pages, CRUD flows");
for another profile, swap the skill summary, mechanism, and install command for its own.
Placement: after the API/Example sections, before Related packages. Keep it to ~3 lines:
what it provides, that it's tool-agnostic, how to add it. Avoid hype and
"perfect understanding" claims.
