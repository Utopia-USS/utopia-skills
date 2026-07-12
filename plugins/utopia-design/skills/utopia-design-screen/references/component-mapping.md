# Mapping Design Elements to Manifest Components

## What this pattern is

The manifest (`manifest/utopia.manifest.json`) is the machine-readable API surface of
`utopia_ui` - every exported widget, its constructor(s) and props, the data classes and
helpers those props depend on, and the theme tokens each component actually reads
(protocol/SPEC.md section 3). This doc covers how to resolve that file for the project
being worked on, how to read one entry, and how to turn a list of design elements into
real constructor calls against it. It is the CRITICAL reference in this skill - every
other reference assumes the reader already knows this shape.

## When this applies

Before writing any screen code from a design input (-> [design-inputs.md](design-inputs.md)),
and whenever deciding whether an element maps cleanly or needs a
[GAP report](gap-reporting.md).

## Resolving the manifest

`utopia_ui` ships `manifest/utopia.manifest.json` inside its pub tarball, so the version
a project resolves is exactly the version whose manifest matches. Resolve the package
root through `.dart_tool/package_config.json` - the identical technique
**utopia-design-tokens**'s
[getting-started.md](../../utopia-design-tokens/references/getting-started.md) documents
for `tokens/utopia.tokens.json`; do not re-derive that resolution snippet here, just
point it at `manifest/utopia.manifest.json` under the same resolved `$utopia_ui_root`
instead of the token document.

Since protocol 0.2.0 up to three manifest documents can be in play (SPEC.md 3.8): the
shipped **library manifest** above; a **project manifest**
(`design/project.manifest.json` - ONLY the project's own custom components, opt-in via
overlay, ids namespaced `<project_package>:<kebab-name>` per SPEC.md 3.3); and a
**merged view** (`design/merged.manifest.json` - library + project in one file).
**Mapping-target preference: `design/merged.manifest.json` when it exists, else the
shipped library manifest.** The merged view is DERIVED - regenerate it, never edit it,
never treat it as a source of truth; `validate_manifest` gates its freshness (recorded
`utopiaUiVersion` must equal the resolved version; embedded library entries must equal
the shipped manifest). Bare ids (`button`) are always library components; namespaced
ids are the project's registered components - both are equally legal mapping targets.
The project/merged files are produced by
`dart run utopia_design_tools:generate_manifest --project` - the utopia-design-component
skill owns that loop. A project that has not registered custom components has only the
shipped library manifest.

Optional freshness check: `dart run utopia_design_tools:validate_manifest` with zero
arguments validates the shipped manifest against the resolved `utopia_ui` version
(the `packageVersion` drift gate, SPEC.md 3.7). Its full CLI contract - default file
resolution, sources root, exact gates - is **utopia-design-sync**'s
[regeneration.md](../../utopia-design-sync/references/regeneration.md); this doc does
not re-spec it.

## The component entry shape

Every entry under `components[]` has this shape (SPEC.md 3.4):

- `id` - the stable cross-surface key, kebab-case of the class name minus the `Utopia`
  prefix (`UtopiaButton` -> `button`, `UtopiaChipList` -> `chip-list`). Skills and the
  HTML twin both reference components by this id.
- `name` - the Dart class name (`UtopiaButton`).
- `description` - the first dartdoc paragraph.
- `file` - the declaring source file, relative to the package root.
- `constructors[]` - one entry per constructor (`name: ""` for the unnamed constructor,
  else the named constructor's name, e.g. `"form"`, `"fixed"`, `"vertical"`). Each
  carries `description` and `props[]`.
- `tokenBindings`, `states`, `composes`, `examples` - see below.

Every prop in `props[]` carries: `name`, the portable `type` (below), the verbatim
`dartType`, `required`, and (when the prop has one) the verbatim Dart `default`
expression - copy defaults exactly as written, they are not paraphrased. A prop is
either required (must be supplied) or has a default (may be omitted); a prop with
neither is nullable-and-omittable.

## Portable prop type vocabulary (SPEC.md 3.5)

| `type` | Meaning | Extra fields on the prop |
|---|---|---|
| `string` | `String`, `String?` | - |
| `number` | `double`, `int` | - |
| `bool` | `bool` | - |
| `enum` | any enum param | `enumName`, `values` (the literal enum member names) |
| `color` | `Color`; `List<Color>` gradients use `list` + `itemType: "color"` | - |
| `duration` | `Duration` | - |
| `date` | `DateTime` | - |
| `callback` | a function returning `void`/`Future`, not a builder | - |
| `widget-slot` | a plain `Widget` param | - |
| `builder-slot` | a function param returning `Widget` (receives `BuildContext` first) | - |
| `list` | `List<T>` / `IList<T>` | `itemType` (portable) + `itemDartType` |
| `generic-model` | the component's own type parameter (`T row`) or a function over it | - |
| `model` | an exported `utopia_ui` data class | `modelName` referencing `models[]` |
| `other` | an opaque platform type (`Key`, `FocusNode`, `Curve`, `EdgeInsets`, `TextInputType`, ...) | - |

`enum` example (`sidebar`'s `presentation` prop): `enumName: "UtopiaSidebarPresentation"`,
`values: ["rail", "drawer"]`, default `"UtopiaSidebarPresentation.rail"`. A prop typed
`generic-model` is `dropdown-field`'s `value` (`dartType: "T?"`); `table`'s
`rows: IList<T>?` is instead a `list` whose `itemType` is `generic-model` - in both
cases `T` is whatever row/value type the screen's data uses, resolved by the caller,
not by the manifest.

## `models[]` and `helpers[]`

Props typed `model` or a `list` with `itemType: "model"` only make sense with their
`modelName` entry from the manifest's `models[]` section - a data/config class excluded
from `components[]` (SPEC.md 3.2) but sharing the same constructor/prop shape. Example:
`sidebar`'s `items` prop is `list` of `model` with `modelName: "UtopiaSidebarItem"` -
`UtopiaSidebarItem` is a sealed base with three real constructible subtypes also in
`models[]`: `UtopiaSidebarDestination` (`id`, `label`, `icon`, all required - a
selectable page entry), `UtopiaSidebarAction` (`label`, `icon`, `onPressed`, all
required - a fire-and-forget entry that never becomes "selected"), and
`UtopiaSidebarCustom` (`builder`, required - an arbitrary widget slot). Similarly
`table`'s `entries` prop resolves via `modelName: "UtopiaTableEntry"`, whose unnamed
constructor takes `cellBuilder` (required builder-slot) plus optional `id`, `title`,
`tooltip`, `flex` (default `"2"`), `minWidth`, `hidePriority` (default `"0"`), `sortBy`,
`searchBy`, `sortOptions` (a `list` of `model` `UtopiaTableSortOption`), `sortable`; its
named `fixed` constructor swaps `flex` for a required `width` for non-flexing columns
(icons, avatars).

`helpers[]` carries exported free functions, hooks and typedefs with signatures and
descriptions - e.g. `useUtopiaTableState` (client-side search/sort convenience for a
`table`), `utopiaCardSliver` (the sliver counterpart of `card`'s chrome), the
`UtopiaTableSort` typedef (`{String columnId, bool descending}`, the shape `table`'s
`currentSort`/`onSortSelected` traffic in), and `utopiaDatePickerMaterialTheme` (maps
theme tokens onto a Material `ThemeData` scoped to `date-picker`'s calendar grid). A
screen composing a table with sort/search almost always needs `useUtopiaTableState`
alongside the `table` component itself - check `helpers[]`, not just `components[]`,
before concluding something needs a GAP.

## `tokenBindings` as the token-discipline source

`tokenBindings` lists the theme members a component actually reads (SPEC.md 3.6) -
`colors.<field>`, `textStyles.<field>`, `tokens.<family>.<step>`, `theme.<slot>`. This is
what "read visual values from `UtopiaTheme`/context" (the SKILL.md token-discipline
rule) resolves to in practice: `button`'s bindings are `colors.accent`,
`colors.onColoredHover`, `colors.primary`, `textStyles.button`, `theme.borderRadius`,
`tokens.x` - none of those six values should ever appear as a literal in code that
constructs a `UtopiaButton`. A component's bindings do not need to be memorized; read
them off the manifest entry for the component in hand.

## `states`, `composes`, `examples`

- `states` - the interaction states the component (and its twin specimen, when one
  exists) can be in, e.g. `button`: `disabled`, `hover`, `loading`; `text-field`:
  `disabled`, `error`, `focus`, `readOnly`. Useful for knowing what a design's hover/
  disabled/error variant of an element actually corresponds to.
- `composes` - ids of other manifest components this one builds internally, e.g.
  `button` composes `gradient-background` and `three-bounce`; `dialog` composes
  `form-layout` and `page-wrapper`; `confirm-dialog` composes `button`. This is the
  first place to look during the composition-first GAP check (->
  [gap-reporting.md](gap-reporting.md)).
- `examples` - paths into `example/lib/sections/*.dart` in the `utopia_ui` repo showing
  the component in use; useful as a live reference for how a constructor is actually
  called, not just what its props are.

## Worked example

A design shows an internal "Team Members" admin page: a left navigation rail, a page
title, a search box above a data table of members (name, role, a trailing "Remove"
action per row), and an "Add Member" button that opens a confirm/cancel prompt.

| Design element | Candidate id(s) considered | Chosen id | Why |
|---|---|---|---|
| Left navigation rail | `sidebar` | `sidebar` | Only manifest component modeling a collapsible rail / drawer nav with selectable destinations |
| Page heading "Team Members" | `title` | `title` | `title`'s sole prop (`title: String`, required) is exactly a page heading, nothing more |
| Search box above the table | `search-field`, `text-field` | `search-field` | `search-field` composes `field-wrapper` like `text-field` but is purpose-built for a filter box (states: `disabled`, `focus`); `text-field` has no reason to be preferred here |
| Data table with a per-row action | `table` | `table` | Generic-over-row-type table with an `actionsBuilder` slot for exactly a trailing per-row action |
| "Add Member" button | `button` | `button` | Primary call-to-action; no competing candidate |
| Confirm/cancel prompt on remove | `confirm-dialog`, `dialog` | `confirm-dialog` | Purpose-built themed confirm/cancel prompt (`danger: true` for the destructive tone); the raw `dialog` would need to reconstruct title/body/actions by hand for no benefit |

Resulting constructor calls (every prop below verified against
`manifest/utopia.manifest.json`):

```dart
UtopiaSidebar(
  items: [
    UtopiaSidebarDestination(id: 'members', label: const Text('Members'), icon: const Icon(Icons.people)),
    UtopiaSidebarDestination(id: 'settings', label: const Text('Settings'), icon: const Icon(Icons.settings)),
  ],
  selectedId: 'members',
  onDestinationPressed: (destination) => onNavigate(destination.id),
  // presentation defaults to UtopiaSidebarPresentation.rail - fine for a desktop admin shell
)

const UtopiaTitle(title: 'Team Members')

UtopiaTable<Member>(
  rows: members, // null renders the loading skeleton; an empty IList renders emptyWidget
  entries: IList([
    UtopiaTableEntry(id: 'name', title: 'Name', cellBuilder: (context, row) => Text(row.name)),
    UtopiaTableEntry(id: 'role', title: 'Role', cellBuilder: (context, row) => Text(row.role)),
  ]),
  rowKey: (row) => row.id,
  searchPanel: UtopiaTableSearchPanel(
    searchField: UtopiaSearchField(
      value: searchValue,
      hint: 'Search members',
      onChanged: onSearchChanged,
    ),
  ),
  actionsBuilder: (context, row, index) => UtopiaRemoveIconButton(onPressed: () => onRemove(row)),
)

UtopiaButton(
  child: const Text('Add Member'),
  onTap: onAddMemberTap,
)

UtopiaConfirmDialog(
  title: 'Remove member?',
  subtitle: 'This cannot be undone.',
  confirmLabel: 'Remove',
  danger: true,
  // hasConfirm / hasCancel default true; cancelLabel defaults to 'Cancel'
)
```

Three things worth naming about this example. The `entries` literal is wrapped
`IList([...])` because the prop's verbatim `dartType` is `IList<UtopiaTableEntry<T>>`
(from `fast_immutable_collections`) - a bare `List` literal does not assign to `IList`
and will not compile; always match the verbatim `dartType` (`sidebar`'s `items` is a
plain `List<UtopiaSidebarItem>`, so its literal stays bare). `UtopiaRemoveIconButton`
inside `actionsBuilder` is itself a real manifest component (id `remove-icon-button`,
also composed internally by `date-picker`), not an invented one - its only prop is a
required `onPressed` callback. And `UtopiaTableSearchPanel` (id `table-search-panel`)
is the manifest's purpose-built slot for pinning a search field above a table's
headers, so the search box does not need to be laid out by hand next to the table.

## See also

- [gap-reporting.md](gap-reporting.md) - what to do when an element has no candidate at
  all, or every candidate is rejected
- [design-inputs.md](design-inputs.md) - how to read each kind of design input for the
  element list this doc's worked example starts from
- [twin-gallery.md](twin-gallery.md) - the HTML twin as both a design input and a visual
  reference for a component's real specimen
