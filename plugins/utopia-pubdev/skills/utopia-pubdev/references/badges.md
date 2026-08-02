# Badges

shields.io is the ecosystem standard - flutter_hooks, riverpod, bloc, and Very Good
all build their rows from it (CI/coverage use their provider's own badge endpoint).
Restraint is the differentiator: VGV ships 4, riverpod ~6, flutter_hooks ~5; bloc
ships 13 and wraps on mobile. The header image is the hero - badges are a quiet row
beneath it. Publisher domain, lints package, and hues come from the resolved brand
profile ([brand-profile.md](brand-profile.md); Utopia's values in
[utopia-brand.md](utopia-brand.md)) - a field set to `none` drops its badge, and a
shorter row is correct, never a filler badge.

## Dynamic vs static - the actual standard

A shields badge is either **dynamic** (queries a live source on each load) or
**static** (a hardcoded `badge/<label>-<message>-<color>` constant). Use the dynamic
endpoint wherever a real source exists; don't hardcode what shields can read live.

- **Dynamic** (self-updating): `pub/v` (pub version - the one universal badge, used by
  flutter_hooks + VGV), `pub/publisher` (verified publisher), CI build status, code
  coverage, `github/stars`.
- **Static by convention:** **license** and **style**. Every reference package
  hardcodes these (`badge/license-MIT-…`, `badge/style-very_good_analysis-…`,
  `badge/style-bloc_lint-…`) - there is no clean live source and they are effectively
  constants, so static is correct here, not lazy. (A live `github/license/<owner>/<repo>`
  exists, but none of the majors use it - match the prevailing static form.)

## Default set (ref-style markdown - the house form, matches VGV)

`<publisher-domain>` and `<lints_pkg>` come from the profile; the hex values shown are
the Utopia palette.

```markdown
[![pub package][pub_badge]][pub_link]
[![publisher][publisher_badge]][publisher_link]
[![license: <LICENSE>][license_badge]][license_link]
[![style: <lints_pkg>][style_badge]][style_link]

[pub_badge]: https://img.shields.io/pub/v/<pkg>.svg?logo=dart
[pub_link]: https://pub.dev/packages/<pkg>
[publisher_badge]: https://img.shields.io/pub/publisher/<pkg>.svg?color=7A4FC2
[publisher_link]: https://pub.dev/publishers/<publisher-domain>
[license_badge]: https://img.shields.io/badge/license-<LICENSE>-2E8B57.svg
[license_link]: LICENSE
[style_badge]: https://img.shields.io/badge/style-<lints__pkg>-0B5EA2.svg
[style_link]: https://pub.dev/packages/<lints_pkg>
```

- **pub version** - *dynamic*; the one genuinely useful chip for GitHub-first readers.
- **publisher** - *dynamic*; renders "publisher | <domain>" from pub.dev's
  verified-publisher record. A provenance / trust signal, not a popularity one, so it fits
  every package no matter how niche. Hardcode the profile's domain in the link; the badge
  text comes from pub.dev. No verified publisher in the profile → drop the badge.
- **license** - *static*; match the package's actual LICENSE. Set `<LICENSE>` to `MIT`
  or `BSD--2--Clause` (a literal hyphen in shields label text is escaped as `--`). Read
  the LICENSE file - do not default to MIT.
- **style: <lints_pkg>** - *static* self-referencing badge, the same move as bloc's
  `style: bloc_lint` and VGV's `style: very_good_analysis`. Signals ecosystem maturity
  and promotes the org's lints. Use only on packages that depend on the profile's lints
  package; no lints package in the profile → drop the badge. (`__` escapes the
  underscore in shields label text.)

**Colour - four distinct hues, never a blue wall.** Each badge gets its own semantic colour
at a similar saturation, so the row reads as a set, not a rainbow. The Utopia palette:
`pub` version = shields amber (automatic for pre-1.0), `license` = green `2E8B57`
(open-source), `style` = brand blue `0B5EA2` (the signature accent - the bloc / VGV move),
`publisher` = violet `7A4FC2`. A profile may swap hues (its `palette` field - the signature
accent slot is where the org colour goes) but keeps four distinct ones. Override a dynamic
badge's colour with `?color=<hex>` (publisher); set a static badge's in the
`badge/label-message-<hex>` slot (license, style). Three-plus badges in one hue is the
failure mode - spread them.

Use inline HTML `<a href><img></a>` **only** when you wrap the row in `<p align="center">`
for a centered header (bloc/riverpod do this); ref-style markdown is the default.

## Optional dynamic add-ons - only when real

```markdown
[![ci][ci_badge]][ci_link]
[![coverage][cov_badge]][cov_link]

[ci_badge]: https://github.com/<repo_org>/<repo>/actions/workflows/ci.yml/badge.svg
[ci_link]: https://github.com/<repo_org>/<repo>/actions/workflows/ci.yml
[cov_badge]: https://codecov.io/gh/<repo_org>/<repo>/branch/main/graph/badge.svg
[cov_link]: https://codecov.io/gh/<repo_org>/<repo>
```

- **ci** - dynamic build status; add only with an actual CI workflow.
- **coverage** - dynamic; codecov, or a self-hosted `coverage_badge.svg` committed by CI
  (VGV style) - but only if coverage is enforced.
- **github stars** - `https://img.shields.io/github/stars/<repo_org>/<repo>?style=flat&logo=github&label=stars` -
  dynamic social proof (bloc / riverpod use it instead of pub likes). **Skip it unless the
  repo is genuinely star-popular** - a low count reads worse than no badge. The publisher
  badge in the default set is the provenance signal instead (Utopia skips stars for
  exactly this reason).

## Skip

`pub/likes`, `pub/points`, `pub/popularity` - none of flutter_hooks, riverpod, bloc, or
VGV use them; pub.dev already shows these on the package page, so they are redundant
there and low-signal on GitHub. (Provenance via the publisher badge beats popularity for
niche packages.) Also skip "Awesome Flutter" / "Flutter Favorite" style vanity badges
and any inline-styled (`style="background:white"`) HTML badge tables - they break dark mode.
