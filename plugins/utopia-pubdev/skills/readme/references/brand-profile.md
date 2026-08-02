# Brand profile

Everything brand-specific in this standard - attribution, publisher, lints
badge, palette, header image, house mark, siblings, AI-assistants wording -
lives in one place: the brand profile. The composition rules
([readme-structure.md](readme-structure.md), [badges.md](badges.md)) read from
it; they never hardcode a brand.

## Where it lives

`docs/pubdev-brand.md` at the **repo root**, committed to git. One profile per
repo, applied to every package in it (monorepos included) - branding is a
family property, not a per-package one.

## Resolution order

1. `docs/pubdev-brand.md` present → use it. It always wins, including in
   Utopia repos (an explicit file is how a repo overrides the default).
2. No file, Utopia detected → the bundled [utopia-brand.md](utopia-brand.md).
   Detection needs a **strong** signal (pubspec `repository`/`homepage` under
   `github.com/Utopia-USS`, or publisher `utopiasoft.io` in existing
   badges/READMEs) or **both weak** signals (`utopia_` name prefix AND a
   `utopia_lints` dependency). A lone `utopia_` prefix is a fork signal, not a
   brand signal.
3. Neither → **stop and interview** (below). Never invent a publisher, an
   attribution line, or a lints package.

## Schema

Every field is required; `none` is a valid value and means "omit that element".

| Field | What it drives | `none` means |
|---|---|---|
| `org` | Display name + URL → the footer attribution line `Built by [Org](url).` | - (required) |
| `repo_org` | GitHub org/user for CI and coverage badge URLs | no CI/coverage badges |
| `publisher` | pub.dev verified-publisher domain → the `publisher` badge | drop the publisher badge |
| `lints` | The org's shared lints package → the `style: <lints>` badge (only on packages that depend on it) | drop the style badge |
| `palette` | The four badge hues (see [badges.md](badges.md) - four distinct hues at similar saturation) | use the stock defaults |
| `header_image` | `utopia-chip` (bundled generator, Utopia only), `asset` (org-provided `docs/header.png` - legible on both pub.dev themes, flush-left, natural width), or `none` | no header image; the H1 leads |
| `house_mark` | Optional emoji/glyph accent (section heading, Contributing line - never the H1) | no mark anywhere |
| `siblings` | How to pick Related packages: an explicit list, or a rule like "closest 3-5 by same publisher" | drop the Related packages section |
| `ai_assistants` | Which packages ship a dedicated skill + the install mechanism and link for the AI-assistants section | omit the section on every package |

License is deliberately NOT a profile field: the license badge always comes
from reading the package's own LICENSE file ([badges.md](badges.md)).

## File template

```markdown
# pub.dev brand profile

Consumed by the utopia-pubdev README standard. One profile per repo.

- **org:** <Display Name> - <https://org.example>
- **repo_org:** <github-org> (or none)
- **publisher:** <publisher.domain> (or none)
- **lints:** <org_lints package> (or none)
- **palette:** pub <hue>, license <hex>, style <hex>, publisher <hex> (or default)
- **header_image:** asset | none
- **house_mark:** <emoji> (or none)
- **siblings:** <explicit list, or a selection rule>
- **ai_assistants:** <qualifying packages + install mechanism + link> (or none)
```

The bundled [utopia-brand.md](utopia-brand.md) is the worked example of this
schema.

## Interview (when no profile resolves)

Derive first, ask only the gaps, confirm once. The `utopia-pubdev:brand-setup`
skill in this plugin runs this flow and writes the file; when composing without
it, follow the same steps inline:

1. **Derive from the repo:** `org` and `repo_org` from pubspec
   `repository`/`homepage` and the git remote; `publisher` from existing
   pub.dev badges/links or the pub.dev page of an already-published package;
   `lints` from a shared `*_lints`/analysis dependency; `header_image` and
   badge conventions from existing READMEs.
2. **Ask the user for the gaps** - in one message, not a drip: attribution
   wording, publisher (if underivable), lints package or none, header-image
   policy, house mark or none, sibling selection, AI-assistants mechanism or
   none.
3. **Confirm the assembled profile in one shot** (derived + answered), then
   offer to save it as `docs/pubdev-brand.md` so the interview never repeats.

Do not proceed to composition with unresolved fields - a README composed on a
guessed brand is worse than a delayed one.
