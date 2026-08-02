# Utopia brand profile

The bundled profile, auto-applied when the codebase is detected as Utopia's
(rule in [brand-profile.md](brand-profile.md#resolution-order)). Also the
worked example of the profile schema.

- **org:** UtopiaSoftware - <https://utopiasoft.io>. Footer attribution line,
  exactly: `Built by [Utopiasoft](https://utopiasoft.io).`
- **repo_org:** `Utopia-USS`
- **publisher:** `utopiasoft.io` (verified). The provenance signal for Utopia
  packages - used instead of `github/stars`, which is skipped (the packages
  are not star-popular; a low count reads worse than none).
- **lints:** `utopia_lints` - the `style: utopia_lints` badge, only on
  packages that actually depend on it. Self-referencing, the same move as
  bloc's `style: bloc_lint` and VGV's `style: very_good_analysis`.
- **palette:** pub = shields amber (automatic for pre-1.0), license = green
  `2E8B57`, style = brand blue `0B5EA2` (the logo flame - the signature
  accent), publisher = violet `7A4FC2`. Full brand palette:
  [brand-spec.md](brand-spec.md#palette).
- **header_image:** `utopia-chip` - the bundled generator (`scripts/`), recipe
  locked in [brand-spec.md](brand-spec.md), light/dark gallery at
  [docs/gallery.html](../docs/gallery.html). Generated, never hand-drawn;
  embedded flush-left at natural @1x width.
- **house_mark:** 👾 - leads plugin/marketplace descriptions; a sparing accent
  on a section heading or the Contributing line; never in the H1.
- **siblings:** explicit per-package pick, 3-5 closest from the family, e.g.:

  | Package | What it adds |
  |---|---|
  | [utopia_hooks](https://pub.dev/packages/utopia_hooks) | State management with hooks |
  | [utopia_injector](https://pub.dev/packages/utopia_injector) | Dependency injection |
  | [utopia_arch](https://pub.dev/packages/utopia_arch) | The full architecture bundle |

- **ai_assistants:** only packages with a dedicated skill qualify -
  `utopia_hooks`, `utopia_arch` (the hooks skill) and `utopia_cms` (the cms
  skill). Mechanism: `AGENTS.md` + the skills marketplace; install with
  `utopia init agents` / `utopia init skills` or the
  [Utopia skills marketplace](https://github.com/Utopia-USS/utopia-flutter-skills).
  Wording skeleton: [readme-structure.md](readme-structure.md#ai-assistants).

Content foundation: Utopia hook-based packages defer voice and idioms to the
[`utopia-hooks`](https://github.com/Utopia-USS/utopia-flutter-skills/tree/main/plugins/utopia-hooks)
skill (see SKILL.md's foundation cross-link).
