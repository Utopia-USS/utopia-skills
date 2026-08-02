---
name: utopia-cms
description: >
  Flutter CMS / admin-panel construction with utopia_cms. Applies when building an
  admin, back-office, or internal-tool UI on top of Firebase, Supabase, Hasura, or
  any GraphQL backend - anywhere the deliverable is a paged shell with sortable /
  filterable tables, CRUD (create / edit / delete) flows, and per-row actions.
  Covers the CmsWidget shell, CmsTablePage, the CmsDelegate hierarchy, the CmsEntry /
  CmsFilterEntry / CmsTableAction / CmsManagementSectionEntry catalogs, custom
  delegates for business logic, theming, and to-many relationships. Proactively
  triggers on `flutter pub add utopia_cms`, on any new `*_admin` / `cms` /
  `panel` Flutter package, and whenever a screen is about to be built by
  hand-rolling Flutter `DataTable` + a Firestore / Supabase service + a
  `useState<List<T>?>` + `isLoading` + `error` triplet. Does NOT cover general
  app screen state (use utopia-hooks), app-side BLoC-to-hooks migration (use
  utopia-hooks-migrate-bloc), or end-user non-admin UIs.
license: BSD-2-Clause
metadata:
  author: UtopiaSoftware
  tags: flutter, dart, admin-panel, cms, firebase, supabase, hasura, graphql, backoffice
---

# Skill: Flutter CMS and Admin Panels with utopia_cms

## Overview

**utopia_cms is a low-code Flutter library for building admin / back-office UIs.**
You declare *what data you have* (`CmsEntry`) and *where it lives* (`CmsDelegate`).
The library renders the table, the create / edit / delete overlay, the filters,
the menu, the navigation, the theme, and the loading / error states.

Think of `CmsTablePage` as "Django admin / Retool, in Flutter, talking directly
to your backend, with a Utopia look-and-feel."

If you find yourself writing `useState<List<T>?>` + `bool isLoading` +
`Future<void> loadX()` + a Flutter `DataTable`, you are doing it wrong - read
the [Anti-patterns](#anti-patterns) section first.

## Claude Code and Codex Compatibility

This skill works in both Claude Code and Codex. The Claude hooks and scripts in
this plugin remain Claude-only; Codex compatibility comes from
`.codex-plugin/plugin.json` plus the repo marketplace entry, and Codex uses the
skill directly without a hook manifest.

## When to Apply

Apply when the user is:

- Building an admin / CMS / back-office Flutter app (web or desktop)
- Adding a "manage X" screen with: list + filter + sort + create + edit + delete
- Migrating a hand-rolled admin panel onto `utopia_cms`
- Wiring `utopia_cms` to Firebase / Supabase / Hasura / GraphQL
- Adding per-row actions, custom edit-overlay sections, or to-many relationships
- Reviewing admin-panel code that looks like it might re-implement CRUD by hand

**Out of scope** (use a different skill):

- General Flutter screen state management → `utopia-hooks`
- BLoC → hooks migration of the *app* (not the admin) → `utopia-hooks-migrate-bloc`
- End-user app UIs (non-admin) - `utopia_cms` is admin-only

## Skill Format

Each reference is a self-contained skill page tuned to its topic:

- **Frontmatter** - title, impact rating, tags
- **Quick Pattern** - ❌ Anti-pattern → ✅ utopia_cms way (immediate pattern-match)
- **Body** - rules, the relevant slice of the API, worked examples, common pitfalls
- **Impact ratings** - CRITICAL (always apply), HIGH (significant correctness/quality gain), MEDIUM (worthwhile improvement)

## Priority-Ordered Guidelines

| Priority | Reference | Impact | Description |
|----------|-----------|--------|-------------|
| 1 | [anti-patterns.md][anti-patterns] | CRITICAL | The hand-rolled DataTable + service + useState anti-pattern, why it happens, and how to spot it during review |
| 2 | [shell-cms-widget.md][shell] | CRITICAL | `CmsWidget`, `CmsWidgetItem.page/.action/.custom`, `CmsWidgetMenuParams`, integration with `go_router` |
| 3 | [table-page.md][table-page] | CRITICAL | `CmsTablePage`, `CmsTableParams`, paging, sorting, role gating |
| 4 | [delegates.md][delegates] | CRITICAL | `CmsDelegate` interface, prebuilt impls (Firebase/Supabase/Hasura), custom GraphQL delegates, subclassing for business logic |
| 5 | [entries.md][entries] | CRITICAL | The `CmsEntry` catalog: text, num, bool, date, dropdown, country, link, media, single-media, to-many. `CmsEntryModifier` flags (responsive `pinned`). Dotted-path keys. |
| 6 | [filters.md][filters] | HIGH | `CmsFilterEntry`, `CmsFilterSearchEntry`, `CmsFilterDateEntry`, `CmsFilter` algebra (`&` `\|` `~`), custom filters |
| 7 | [actions.md][actions] | HIGH | `CmsTableAction` per-row popup actions, `shouldUpdateTable` semantics, side-effects vs row mutations |
| 8 | [management-sections.md][management-sections] | HIGH | `CmsManagementSectionEntry.sliverBuilder` for custom slivers in the edit overlay; `CmsManagementBaseState` + `addOnSavedCallback` for cross-cutting saves |
| 9 | [theme.md][theme] | MEDIUM | `CmsThemeData`, `CmsThemeColors`, `CmsThemeTextStyles`, Provider injection at root |
| 10 | [relationships.md][relationships] | MEDIUM | `CmsToManyDelegate`, `CmsToManyDropdownEntry`, Hasura/Supabase one-to-many and many-to-many |
| 11 | [media.md][media] | MEDIUM | `CmsMediaEntry`, `CmsMediaDelegate`, upload + display, `CmsMediaType` |

## Quick Reference - The Three Things You Need

For 80% of cases, you wire three things and you are done. Worked examples live in the
reference files - below is the shape only:

1. **The shell - `CmsWidget`**: one per app, hosts all admin pages.
   `CmsWidget(theme:, selectedPageId:, items: [CmsWidgetItem.page(...), CmsWidgetItem.action(...), CmsWidgetItem.custom(flex: 1)])`.
   Full example: [shell-cms-widget.md][shell].
2. **A page - `CmsTablePage`**: `CmsTablePage(title:, delegate:, pagingLimit:, params: CmsTableParams(...), filterEntries:, customActions:, entries: [CmsTextEntry(...), ...])`.
   Full example with modifiers, filters, and actions: [table-page.md][table-page].
3. **A delegate**: for 95% of tables, subclass the prebuilt one and pass a table reference
   (e.g. `class UserDelegate extends CmsSupabaseDelegate` with `table:` and `archivedFilter:` for soft-delete).
   Override `create / update / delete` only when you need business logic. Full coverage: [delegates.md][delegates].

## Backend Pre-Wiring - Pick Your Delegate Package

| Backend  | Package                   | Delegate                                | Table model               |
|----------|---------------------------|-----------------------------------------|---------------------------|
| Firebase | `utopia_cms_firebase`     | `CmsFirebaseDelegate` (override `get()`)| collection name (String)  |
| Supabase | `utopia_cms_supabase`     | `CmsSupabaseDelegate`                   | `CmsSupabaseDataTable`    |
| Hasura   | `utopia_cms_hasura`       | `CmsHasuraDelegate`                     | `CmsHasuraDataTable`      |
| GraphQL  | `utopia_cms_graphql`      | none prebuilt - custom `CmsDelegate`    | your documents + `CmsGraphQLField`s |

GraphQL (non-Hasura) has no prebuilt delegate: `utopia_cms_graphql` is a service
layer - `CmsGraphQL` (client factory), `CmsGraphQLService` (query / mutate document
builder), `CmsGraphQLField` - on top of which you implement `CmsDelegate` yourself.
See [delegates.md][delegates].

Custom backend? Implement `CmsDelegate` directly - four methods, ~30 lines.
See [delegates.md][delegates] §"Custom delegate".

## Known Limitations (current utopia_cms)

Re-verify against the `utopia_cms` version pinned in the project's `pubspec.yaml`.
Several older limitations are now fixed (noted below). Each remaining row links to
the reference file carrying the workaround.

| Limitation | Workaround in |
|------------|---------------|
| Firestore: stock `CmsFirebaseDelegate.get()` ignores sorting, filters and paging entirely and hardcodes a 30-row limit - always override `get()` | [delegates.md][delegates] |
| Offset paging can duplicate rows when the backend mutates between pages, and page dedupe is O(n^2) - jank on large tables | [table-page.md][table-page] |
| No *automatic* refresh on realtime backends - 0.3.0 adds a built-in manual refresh button, but the table won't refetch on its own | [table-page.md][table-page] |
| `CmsDateEntry` serializes `DateTime.toString()` (not ISO-8601) - the 0.2.x stale-after-picking bug is fixed in 0.3.0 | [entries.md][entries] |
| Inside the management overlay resolve state via `Provider.of`, never `useProvided` - the stock media / to-many fields no longer throw (fixed in 0.3.0), but your own overlay code still must use `Provider.of` | [management-sections.md][management-sections] |
| The management overlay can clip the last form field - add a trailing spacer section | [management-sections.md][management-sections] |
| Framework chrome strings ("Create", "Update", "Delete", "Manage", "Back") are hardcoded English - no l10n hook | [theme.md][theme] |
| No streaming `get()` and no multi-row selection - the two honest reasons to hand-roll a table | [anti-patterns.md][anti-patterns] |

**Recent additions** (see references): `CmsLinkEntry`, `CmsSingleMediaEntry`, responsive
tables / menu / overlay (`CmsPageType`, `pinned: (t) => ...`), a table refresh button,
a `media_kit`-backed `CmsVideoPlayer`, public exports of `CmsManagementBaseState` /
`OnSavedCallback` / `CmsDropdownField`, and a core `utopia_arch` to `utopia_hooks` dep
swap (inject with `useProvided`).

## Searching References

All paths below are relative to the skill root (`plugins/utopia-cms/skills/utopia-cms/`).
From elsewhere, use the absolute form, e.g.
`grep -rl "CmsTableAction" /path/to/plugins/utopia-cms/skills/utopia-cms/references/`.

```bash
# Pick the right entry type
grep -rl "CmsTextEntry\|CmsNumEntry\|CmsBoolEntry\|CmsDateEntry" references/
grep -rl "CmsDropdownEntry\|CmsToManyDropdownEntry\|CmsCountryEntry\|CmsMediaEntry" references/

# Filtering / search
grep -rl "CmsFilter\." references/
grep -rl "CmsFilterSearchEntry\|CmsFilterDateEntry" references/

# Per-row actions / edit-overlay customization
grep -rl "CmsTableAction" references/
grep -rl "CmsManagementSectionEntry\|addOnSavedCallback" references/

# Backend wiring
grep -rl "CmsFirebaseDelegate"  references/
grep -rl "CmsSupabaseDelegate"  references/
grep -rl "CmsHasuraDelegate"    references/
grep -rl "CmsGraphQLService"    references/
```

## Anti-Patterns

These are the failure modes this skill exists to prevent. If you see any in
generated code, stop and refactor before continuing.

| Symptom | Fix |
|---------|-----|
| `pubspec.yaml` of an admin/CMS app does **not** depend on `utopia_cms` | Add it. See [anti-patterns.md][anti-patterns] §1 |
| Custom `*ScreenState` with `useState<IList<T>?>` + `isLoading` + `error` + `loadXxx()` | Replace with a `CmsTablePage`. The state hook becomes 0 lines. |
| Flutter `DataTable` / `DataColumn` / `DataRow` in an admin context | Replace with `CmsTablePage` + `CmsEntry` list |
| Hand-written `XxxService` that re-implements CRUD against Firestore / Supabase / Hasura | Replace with a `Cms{Firebase,Supabase,Hasura}Delegate` subclass (plain GraphQL: custom `CmsDelegate` on `CmsGraphQLService`). Override only `create`/`update`/`delete` when there's business logic. |
| Custom `AlertDialog` for delete confirmation | Delete confirmation is built into `CmsTablePage`'s delete flow - a themed dialog appears with zero code |
| `Navigator.pushNamedAndRemoveUntil` between table pages | Use one `CmsWidget` with multiple `CmsWidgetItem.page` |
| Per-row "edit" / "delete" `IconButton`s | Use `CmsTableParams(canEdit, canDelete)` - they're generated for free; popup-menu actions go in `customActions` |
| Manual reorder / visibility-toggle / archive code in a service | `CmsBoolEntry` for visibility, `CmsTableAction` for one-off ops, soft-delete via `archivedFilter` on the delegate |
| Calling `setState` in an admin screen | Admin code uses `HookWidget`; mutation flows through the delegate |

See [anti-patterns.md][anti-patterns] for the canonical "before / after" diff.
In a real-world incident a hand-rolled admin produced ~970 lines (screen +
state-class + view + custom dialog) for a single CRUD page that would have
been a ~80-line `CmsTablePage`.

## Non-Negotiable Rules

- **`utopia_cms` is in `pubspec.yaml`** for any admin / CMS / back-office Flutter app. Without this, none of the rules below can apply.
- **No hand-rolled CRUD service** in admin code - extend a prebuilt `CmsDelegate` (Firebase / Supabase / Hasura); for a plain GraphQL backend, implement `CmsDelegate` on top of `CmsGraphQLService`. If overriding `update/create/delete`, the override exists to add business logic, not to replicate framework behavior.
- **On Firestore, override `get()`** - stock `CmsFirebaseDelegate.get()` ignores sorting, filters and paging and hardcodes a 30-row limit (still in 0.3.0). See [delegates.md][delegates].
- **No `useState<List<T>?>` + `bool isLoading` + `String? error` pattern in admin code** - `CmsTablePage` owns loading, error, and data.
- **No Flutter `DataTable` in admin code** - every tabular admin view is a `CmsTablePage`. The right way to add a column is a new `CmsEntry` in the `entries` list.
- **No `Navigator.push` between admin tables** - one `CmsWidget`, multiple `CmsWidgetItem.page`. Cross-screen navigation in admin contexts is suspicious - re-examine before building it.
- **No `AlertDialog` for the delete-confirmation prompt** - `CmsTablePage` shows its own themed confirmation dialog automatically (that dialog is internal as of 0.3.0, not callable from app code).
- **Never mutate the row map a `CmsTableAction` receives** - it is the table's live state, passed without copying. Copy first: `{...row, 'status': 'archived'}`.
- **Inside the management overlay resolve `CmsManagementBaseState` via `Provider.of`**, never `useProvided` - the overlay provides it through `package:provider`, so `useProvided` throws there (still in 0.3.0; the stock media / to-many fields were fixed to use `Provider.of`). See [management-sections.md][management-sections].
- **Role-based gating goes in `CmsTableParams` + `CmsEntryModifier`** - not in custom widgets that wrap `CmsTablePage`. (`canEdit: isSuperAdmin`, `CmsEntryModifier(editable: isSuperAdmin)`.)
- **Per-row business logic = `CmsTableAction`**, never a custom popup menu rendered into a column.
- **Custom edit-overlay UI = `CmsManagementSectionEntry`**, never a separate `*EditScreen` route.
- **One `CmsThemeData` for the whole admin app** - Provider-injected at root, optionally passed as `CmsWidget(theme: …)`.
- **`JsonMap` keys may be dotted paths** (`contactData.name`). Don't flatten by hand - `JsonMapExtensions.getAtPath/setAtPath` handles it.
- **Don't import widgets from `utopia_cms/src/**`** - only the public exports from `package:utopia_cms/utopia_cms.dart` (and the delegate packages: `utopia_cms_firebase` / `_supabase` / `_hasura` / `_graphql`). As of 0.3.0 `CmsManagementBaseState` and `OnSavedCallback` are public exports, so the 0.2.x deep-import exception is gone; `CmsDialog` and the context extensions remain unexported.

## Self-Audit Checklist

After generating an admin screen, verify:

1. Is `utopia_cms` (and the relevant delegate package) in `pubspec.yaml`? → If not, this is the anti-pattern. Stop and add it.
2. Does the file extend `HookWidget` and return a `CmsTablePage` (or `CmsWidget`) directly? → If there's a custom `*ScreenView` with its own `DataTable`, refactor.
3. Is there *any* `useState<List<T>?>`, `useState<bool>(isLoading)`, `useState<String?>(error)` in an admin screen? → Delete; `CmsTablePage` owns these.
4. Is there a hand-written `Service` class doing CRUD? → Convert to a `CmsDelegate` subclass.
5. On Firestore: does the delegate override `get()` with real sorting / filter / paging? → Stock `CmsFirebaseDelegate.get()` ignores them (still in 0.3.0).
6. Are role permissions enforced via `CmsTableParams.canEdit/Create/Delete` and `CmsEntryModifier(editable: …)` rather than wrapping `CmsTablePage` in conditionals? → Move into params/modifiers.
7. Are per-row buttons rendered as `IconButton`s in a column? → Move to `customActions: [CmsTableAction(…)]`.
8. Does any `CmsTableAction.onPressed` mutate the row map it receives? → That map is live table state - copy it first (`{...row, 'field': newValue}`).
9. Are nested edit-overlay widgets implemented as separate routes? → Move to `managementSectionEntries: [CmsManagementSectionEntry(…)]`.
10. Does custom code inside the edit overlay call `useProvided<CmsManagementBaseState>()`? → Replace with `Provider.of<CmsManagementBaseState>(context, listen: false)`.
11. Is there an `AlertDialog` for "are you sure you want to delete"? → Remove; it's built in.
12. Is `Navigator.pushNamedAndRemoveUntil` switching between admin tables? → Replace with a single `CmsWidget` shell.
13. Do sibling pages over the same collection duplicate their `CmsEntry` lists? → Extract one shared entries-builder function and parameterize the differences.
14. Does the page lose its filter state when navigating away? → `CmsTableParams.initialFilterValues` + a `useState` in the parent screen.
15. Is theme styling hard-coded into widgets or set per-page? → Single `CmsThemeData` Provider at app root.
16. Are dotted paths (`contactData.name`) being flattened manually? → They aren't - the entry `key` accepts dotted paths.

## Attribution

Built on [utopia_cms](https://pub.dev/packages/utopia_cms) by UtopiaSoftware.
Delegate packages: [utopia_cms_firebase](https://pub.dev/packages/utopia_cms_firebase),
[utopia_cms_supabase](https://pub.dev/packages/utopia_cms_supabase),
[utopia_cms_hasura](https://pub.dev/packages/utopia_cms_hasura),
[utopia_cms_graphql](https://pub.dev/packages/utopia_cms_graphql).

[anti-patterns]: references/anti-patterns.md
[shell]: references/shell-cms-widget.md
[table-page]: references/table-page.md
[delegates]: references/delegates.md
[entries]: references/entries.md
[filters]: references/filters.md
[actions]: references/actions.md
[management-sections]: references/management-sections.md
[theme]: references/theme.md
[relationships]: references/relationships.md
[media]: references/media.md
