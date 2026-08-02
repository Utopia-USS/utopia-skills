<img src="docs/header.png" width="249" alt="Utopia Pub.dev"/>

[![license: BSD-2-Clause][license_badge]][license_link]

# utopia-pubdev

A Claude Code and Codex plugin that composes and standardizes pub.dev READMEs for Dart/Flutter packages: a brand-profile-driven header and badge row, house voice, minimal vs full section tiers, and a no-sponsor footer with sibling links. Branding is data, not prose: the bundled Utopia profile auto-applies in Utopia codebases, any other repo commits its own `docs/pubdev-brand.md`, and with neither present the skill interviews you before composing.

## What's inside

- The `utopia-pubdev` skill - the README standard, brand-profile driven.
- The `pubdev-brand-setup` skill - a derive-then-interview flow that writes a repo's `docs/pubdev-brand.md`.
- Five references: `readme-structure.md` (the header and footer contract, plus the two section tiers), `badges.md`, `brand-profile.md` (the profile schema, resolution order, and Utopia detection rule), `utopia-brand.md` (the bundled Utopia profile), and `brand-spec.md` (the locked Utopia chip recipe).
- The bundled brand-chip generator (`chip.py`, `render.mjs`, `generate.py`), which turns a package name into a Clay PNG via headless Chrome - Utopia profile only - plus a light/dark brand sheet at `skills/utopia-pubdev/docs/gallery.html`.

No hooks, commands, or agents.

## Installation

```bash
# Claude Code
/plugin marketplace add Utopia-USS/utopia-flutter-skills
/plugin install utopia-pubdev@utopia-flutter-skills
```

```bash
# Codex
codex plugin marketplace add Utopia-USS/utopia-flutter-skills --ref main
codex plugin install utopia-pubdev@utopia-flutter-skills
```

## Bring your own brand

The composition rules (structure, tiers, badges, voice) are generic; everything brand-specific - attribution line, pub.dev publisher, lints badge, palette, header image, house mark - lives in a brand profile. Resolution order: a committed `docs/pubdev-brand.md` always wins; without one, a detected Utopia codebase gets the bundled Utopia profile; anywhere else the skill asks before composing. Run the `pubdev-brand-setup` skill once per repo to answer those questions and persist them.

## Generating a header chip (Utopia profile only)

```sh
cd skills/utopia-pubdev/scripts
npm i puppeteer-core            # once
python3 generate.py --repo /path/to/repo     # discovers packages, writes <pkg>/docs/header.png + manifest.json
```

Needs `node`, `python3`, a local Chrome (or `$CHROME` pointing at the binary), and network access at render time: the Ubuntu web font has to load, or the render aborts instead of shipping a chip with a fallback face.

## Related plugins

| Plugin | What it adds |
|---|---|
| [utopia-hooks](../utopia-hooks/) | The content and idiom foundation this standard defers to |
| [utopia-cms](../utopia-cms/) | The CMS skill this standard's AI-assistants section links `utopia_cms` READMEs to |
| [utopia-ai-arch](../utopia-ai-arch/) | The `.claude/` layer, explicitly out of this skill's scope |
| [utopia-design](../utopia-design/) | Consumes the same brand standard for its own assets |

Built by [UtopiaSoftware](https://utopiasoft.io).

## Contributing

👾 Issues and PRs welcome - skills are designed to be forked: copy one into your own Claude Code or Codex setup, tweak the rules, ship it.

## License

BSD 2-Clause - see [LICENSE](../../LICENSE).

[license_badge]: https://img.shields.io/badge/license-BSD--2--Clause-2E8B57.svg
[license_link]: ../../LICENSE
