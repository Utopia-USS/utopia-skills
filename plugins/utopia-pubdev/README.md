<img src="docs/header.png" width="249" alt="Utopia Pub.dev"/>

[![license: BSD-2-Clause][license_badge]][license_link]

# utopia-pubdev

A Claude Code and Codex plugin that composes and standardizes pub.dev READMEs for Utopia Dart/Flutter packages: the brand-chip header, house voice, minimal vs full section tiers, a restrained badge set, and a no-sponsor footer with sibling links.

## What's inside

- The `utopia-pubdev` skill.
- Three references: `readme-structure.md` (the header and footer contract, plus the two section tiers), `badges.md`, and `brand-spec.md` (the locked brand values).
- The bundled brand-chip generator (`chip.py`, `render.mjs`, `generate.py`), which turns a package name into a Clay PNG via headless Chrome, plus a light/dark brand sheet at `skills/utopia-pubdev/docs/gallery.html`.

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

## Generating a header chip

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
