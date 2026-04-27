# `*-cheatsheet.md` — flat lookup / catalogue style

Use this style when the most useful thing the agent can have in
context is a **map of what exists** — components, tokens, assets,
icons, error codes, available activities. The defining property:
there are no rules to follow and no flows to walk through. The agent
just needs to know what's already there so they reuse it instead of
inventing it.

If the content has a product story, use `*-module.md`. If it
encodes rules with reasoning, use `*-pattern.md`. Cheat-sheets
sit alongside one of the other two styles in the same skill —
they don't replace the conventions, they index the inventory those
conventions describe.

Common suffixes: `*-cheatsheet.md`, `*-catalogue.md`, `*-map.md`,
`*-inventory.md`. Pick the one that reads best.

Examples of good fits:

- **Design system component map** — every `Crazy*` widget, what it
  does, when to use it, where it lives.
- **AppColors / AppValues / AppIcons inventory** — every token, its
  intended use.
- **Activity catalogue** — every existing activity (3-letter code,
  what it does, proto file).
- **Error / status code reference** — gRPC error codes, business
  rule codes, mapping to user-facing messages.

---

## Required sections

### `# <Catalogue name>`

Noun phrase naming what's catalogued (e.g. *Crazy UI Component Map*,
*App Tokens*, *Activity Catalogue*).

### `## How to use this`

1–3 sentences. *"Before reaching for a custom widget, check this
list. If something close exists, use it. If nothing fits, the
existing options inform what shape a new addition should take."*
Sets the bar: cheat-sheets exist to steer the agent away from
duplicating things that already exist.

### `## <Inventory tables>`

The bulk of the document. Format depends on what's catalogued, but
the constraint is constant: **scannable in one read**. Tables are
usually right; long prose is usually wrong.

Examples of good shapes:

```
| Component | Where | Use when | Avoid when |
|---|---|---|---|
| `CrazyPage` | classroom/lib/ui/common/crazy_ui/page/ | Standard scaffolded screen | Pupil-facing lesson UI (different layer) |
| `CrazySchoolPage` | …/page/ | School-context screen with header | Class-context (use CrazyClassPage) |
```

```
| Token | Hex / value | Intended use |
|---|---|---|
| `AppColors.primary` | `#1B6FE7` | Primary actions, links, focused states |
| `AppColors.onPrimary` | `#FFFFFF` | Text/icons on primary surfaces |
```

```
| Code | Activity | Proto | Notes |
|---|---|---|---|
| `SIO` | Sound Identification | `proto/classroom/activity/sio.proto` | Single-letter |
| `IMC` | Image Match | `proto/classroom/activity/imc.proto` | Has variants 01, 02 |
```

Group entries when there's a natural grouping (by feature area, by
visual category, by lifecycle). Keep groups small enough that the
table-of-contents fits in a screen.

### `## When to add a new entry`

When does the catalogue grow? Who decides? Often this links back to
a `*-pattern.md` that defines the rules — *"new components follow
[crazy-design-system pattern](crazy-design-system.md); add to this
catalogue once merged."*

---

## Optional sections

### `## Deprecated`

Things that exist in the codebase but should not be reached for.
Keep the entry, mark it deprecated, point at the replacement. This
prevents the agent from "discovering" old code and re-introducing
it.

### `## See also`

Link to the `*-pattern.md` that governs how new entries are added,
or to the `*-module.md` whose user flow the catalogue serves.

---

## Hard rules

- **Tables, not prose.** A cheat-sheet that's mostly paragraphs is
  a pattern document with bad formatting. Convert or split.
- **No "how to write X" content.** That's `*-pattern.md`. Cheat-sheets
  describe what exists, not how to make new things.
- **No business / user flow content.** That's `*-module.md`.
- **Keep entries terse.** One line per cell. If a cell needs a
  paragraph, the thing it describes deserves its own reference doc.
- **Stale entries are worse than missing entries.** When the
  codebase changes, the cheat-sheet has to follow on the same PR.
  Treat it like any other code surface — the drift scan should
  catch dead links, but logical drift (component renamed, token
  retired) is on the author.
