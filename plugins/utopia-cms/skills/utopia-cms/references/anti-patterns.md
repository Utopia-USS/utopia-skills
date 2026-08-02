---
title: Anti-patterns (don't hand-roll the framework)
impact: CRITICAL
tags: anti-pattern, review
---

# Skill: Anti Patterns (Don't Hand Roll the Framework)

The single most common failure mode when an agent builds an admin panel without
alignment: it **ignores `utopia_cms` entirely** and rebuilds, from scratch, what
the framework provides for free.

This reference exists so that anyone reviewing or generating CMS code can
pattern-match the failure in seconds and refactor with confidence.

---

## The one-line test

> If the file declares `useState<List<T>?>` + `useState<bool>(true)` (loading)
> + `useState<String?>(null)` (error) + a `loadXxx()` function inside an
> admin / CMS / back-office screen - **stop**. That is the anti-pattern.

Replace the whole file (state + view) with a `HookWidget` that returns a
`CmsTablePage`. The state hook disappears.

---

## Quick Pattern

### ❌ Anti-pattern (hand-rolled - what an unbriefed agent will produce)

```dart
// lib/screen/products/state/products_screen_state.dart  - 100+ lines
class ProductsScreenState {
  final IList<Product>? products;
  final bool isLoading;
  final String? error;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String) onDelete;
  // …
}

ProductsScreenState useProductsScreenState() {
  final service = useProvided<ProductService>();        // hand-rolled Firestore service
  final productsState = useState<IList<Product>?>(null);
  final isLoadingState = useState(true);
  final errorState = useState<String?>(null);

  Future<void> load() async {
    isLoadingState.value = true; errorState.value = null;
    try { productsState.value = await service.loadProducts(); }
    catch (e) { errorState.value = e.toString(); }
    finally { isLoadingState.value = false; }
  }

  useEffect(() { load(); return null; }, const []);
  return ProductsScreenState(/* … */);
}

// lib/screen/products/view/products_screen_view.dart - 200+ lines
class ProductsScreenView extends StatelessWidget {
  // … Flutter DataTable, IconButton per row, AlertDialog for delete, …
}

// lib/services/product_service.dart  - 100+ lines reimplementing CRUD
class ProductService {
  Future<IList<Product>> loadProducts()           { /* Firestore */ }
  Future<void> createProduct({…}) async           { /* Firestore */ }
  Future<void> updateProduct({…}) async           { /* Firestore */ }
  Future<void> deleteProduct(String id) async     { /* Firestore */ }
  // …
}
```

### ✅ utopia_cms way

```dart
// lib/screen/main/pages/products_page.dart - entire file
class ProductsPage extends HookWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CmsTablePage(
      title: 'Products',
      delegate: const CmsFirebaseDelegate('products'),
      pagingLimit: 50,
      filterEntries: [
        CmsFilterSearchEntry(filterKeys: ['name'], entryKey: 'product_search', label: 'Search'),
      ],
      entries: [
        CmsTextEntry(key: 'name',       label: 'Name',     modifier: CmsEntryModifier(sortable: true)),
        CmsBoolEntry(key: 'isVisible',  label: 'Visible'),
        CmsNumEntry (key: 'orderIndex', label: 'Order',    modifier: CmsEntryModifier(sortable: true)),
        CmsNumEntry (key: 'price',      label: 'Price',    isDecimal: true, modifier: CmsEntryModifier(required: false)),
      ],
    );
  }
}
```

**Net result:** ~25 lines vs. ~400+ lines. No service. No state class. No view file. No `DataTable`. Loading / error / delete-confirm / create / edit overlays are all generated.

**Known limitation (0.3.0):** the stock `CmsFirebaseDelegate.get` hardcodes `limit(30)` and ignores sorting, filters and paging entirely - on Firestore, subclass it and override `get` before the search filter and `pagingLimit` above do anything. See [delegates.md](delegates.md).

---

## The full failure list (real-world incident)

This list is distilled from a real codebase where an unbriefed agent produced
~970 lines (a `*_screen.dart` of 27 + a `*_screen_state.dart` of 316 + a
`*_screen_view.dart` of 561 + a custom dialog of 72) for a single admin CRUD
page that should have been ~80 lines of `CmsTablePage`. Each anti-pattern
below maps to a *specific* concrete file/decision an unbriefed agent makes:

| # | Anti-pattern | Symptom in code | Replacement |
|---|--------------|-----------------|-------------|
| 1 | **No `utopia_cms` dependency** | `pubspec.yaml` for an admin app doesn't list `utopia_cms` | Add `utopia_cms:` + `utopia_cms_{firebase,supabase,hasura,graphql}:` |
| 2 | **Custom admin scaffold** | `AdminScaffold` widget with hand-built nav rail or drawer | `CmsWidget` with `CmsWidgetItem.page` per page |
| 3 | **Manual route per table** | `Navigator.pushNamedAndRemoveUntil(AppRoutes.products, …)` between admin tables | One `CmsWidget`; each table is a `CmsWidgetItem.page` |
| 4 | **`useState<List<T>?>` + `isLoading` + `error`** | Loading triplet in the screen state hook | Delete it - `CmsTablePage` owns these |
| 5 | **`Flutter DataTable`** | `DataTable / DataColumn / DataRow` in admin code | `CmsTablePage` + `CmsEntry` list |
| 6 | **Custom CRUD service** | `class XxxService { Future<…> loadXxx, createXxx, updateXxx, deleteXxx }` | `class XxxDelegate extends CmsFirebaseDelegate { … }` (or `CmsSupabaseDelegate` / `CmsHasuraDelegate`; for a non-Hasura GraphQL backend there is no prebuilt delegate - implement `CmsDelegate` on top of `CmsGraphQLService`, see [delegates.md](delegates.md)) |
| 7 | **`AlertDialog` to confirm delete** | `showDialog(builder: (_) => AlertDialog(title: 'Delete?'))` in admin context | Built-in - the framework shows its own themed confirm dialog when the user taps Delete (internally `CmsDialog`; not a user-callable API) |
| 8 | **`IconButton` row of edit/delete actions** | `IconButton(icon: Icons.edit, …), IconButton(icon: Icons.delete, …)` per row | `CmsTableParams(canEdit: true, canDelete: true)` - generated |
| 9 | **Manual reorder buttons** | `Icons.arrow_upward / arrow_downward` per row + reorder service | A `CmsTableAction` named "Move up" / "Move down" or, better, an `orderIndex` field + sort |
| 10 | **Manual visibility toggle button** | `IconButton(icon: Icons.visibility, onPressed: () => toggle)` | `CmsBoolEntry(key: 'isVisible')` - preview is a read-only switch; toggling happens via the edit overlay (one click → Edit → flip → Save). If you really need 1-click inline toggle, add a `CmsTableAction(label: 'Toggle visibility', shouldUpdateTable: true, onPressed: …)` |
| 11 | **Custom "*Edit screen" route** | Separate route + screen for create / edit (e.g. `AppRoutes.productEdit(id)`) | `CmsTablePage` opens its own create/edit overlay; nested data goes in `CmsManagementSectionEntry` |
| 12 | **Refetch pattern after each mutation** | `await service.deleteX(id); await loadProducts();` | Built in - create / edit trigger a table refetch, delete removes the row, and a `shouldUpdateTable: true` action swaps in the returned row |
| 13 | **Filter state in `useState`** | `useState<String>('search query')` + manual filter logic in `Stream.where` | `CmsFilterSearchEntry(filterKeys: […])` - filter pushed down to the backend |
| 14 | **Per-screen `ScreenState` + `ScreenView` split** | `products_screen_state.dart` + `products_screen_view.dart` for what amounts to a list | A single `HookWidget` returning `CmsTablePage` - the framework already owns State/View separation |
| 15 | **Hard-coded theme per page** | `Container(decoration: BoxDecoration(color: AppColors.background…))` wrapping the table | One `CmsThemeData` at app root |
| 16 | **Manual stream subscription with `useEffect` cleanup** | `useEffect(() { final sub = service.stream().listen(…); return sub.cancel; })` | `CmsTablePage` is request/response (`CmsDelegate.get` is a one-shot `Future`); most admin views poll on user action, not push. A page that genuinely needs live push updates is a sanctioned bypass - see "Special case" below |

---

## Why does an unbriefed agent fall into this?

1. **`utopia_cms` is less common than the mainstream state-management stacks.** Without explicit context the agent defaults to "Flutter Material widgets + a service class."
2. **The framework looks "internal."** When `utopia_cms` appears as a path override in `dependency_overrides`, an agent often reads it as project-internal code and avoids it.
3. **The hand-rolled version compiles and runs.** It only fails the *quality* bar - feature parity is achievable both ways. Without a skill telling the agent there is a *correct* way, both paths look equally valid.
4. **Each anti-pattern alone looks reasonable.** A `DataTable`, a service class, a loading state - none is obviously wrong. The wrongness is in the *whole shape*.

The fix is **always** the same shape: replace screen-state-class + screen-view + service with `HookWidget` → `CmsTablePage(delegate: …, entries: […])`.

---

## Detection - review checklist

Use this list when reviewing or auditing admin code:

```bash
# 1) Is utopia_cms even a dependency?
grep -q '^[[:space:]]*utopia_cms' admin/pubspec.yaml || echo "❌ admin app does not depend on utopia_cms"

# 2) Hand-rolled DataTable in admin code?
grep -rn "DataTable(" admin/lib/screen/ admin/lib/ui/

# 3) Loading-state triplet in admin code?
grep -rnE "useState<bool>\([^)]*\).*isLoading|useState<List<.+>\?>" admin/lib/screen/

# 4) Custom CRUD service?
grep -rnE "Future<[^>]*> (load|create|update|delete)" admin/lib/services/

# 5) AlertDialog (delete-confirm) in admin context?
grep -rn "AlertDialog" admin/lib/screen/

# 6) Multiple admin route entries (sign of per-table routing)?
grep -nE "AppRoutes\.[a-zA-Z_]+ =" admin/lib/app/app_routing.dart | wc -l
```

Any non-empty result is a flag - read the file and verify against the table above.

---

## Refactor recipe - turning hand-rolled into utopia_cms

Given the anti-pattern, the refactor is mechanical:

1. **Add deps.** `flutter pub add utopia_cms utopia_cms_<backend>`.
2. **Identify the model.** What's the "row" type (e.g. `Product`)? It becomes a `JsonMap`. The model class can stay for app-side reads; the admin reads/writes `JsonMap`.
3. **Replace the service with a delegate.** `XxxService` → `class XxxDelegate extends Cms<Backend>Delegate`. Keep custom create / update logic by overriding those methods; let `get` / `delete` use defaults. (Firebase / Supabase / Hasura have prebuilt delegates to subclass; a non-Hasura GraphQL backend has none - implement `CmsDelegate` yourself on top of `CmsGraphQLService`, see [delegates.md](delegates.md).)
4. **Decide entries.** One `CmsEntry` per field you currently render in `DataColumn` or in the edit form. Pick the type:
   - `CmsTextEntry` for strings
   - `CmsNumEntry` for numbers (`isDecimal: true` for floats)
   - `CmsBoolEntry` for booleans (the "Visible" toggle column becomes this)
   - `CmsDateEntry` for dates
   - `CmsDropdownEntry<T>` for closed sets (roles, statuses)
   - `CmsToManyDropdownEntry` for relations
   - `CmsMediaEntry` for images/files
5. **Decide filters.** Each "search bar" or "filter chip" becomes a `CmsFilterEntry`. The most common is `CmsFilterSearchEntry(filterKeys: ['name', 'email'], …)`.
6. **Decide actions.** Each manual `IconButton` that isn't covered by edit / delete becomes a `CmsTableAction`. Delete keeps its built-in confirm; for your own destructive actions the "are-you-sure" prompt stays a `showDialog` confirm inside `onPressed` (`CmsDialog` is internal-only as of 0.3.0 - see [actions.md](actions.md)).
7. **Decide overlay sections.** Anything in the *edit* flow that isn't a simple field becomes a `CmsManagementSectionEntry(sliverBuilder: …)`.
8. **Shell.** Replace `AdminScaffold` / routing with one `CmsWidget` whose `items: [CmsWidgetItem.page(…), …]` covers all tables.
9. **Theme.** Lift the hard-coded admin colors into one `CmsThemeData`, provide at app root.
10. **Delete dead code.** The screen state class, the screen view, the service, the per-table routes, the custom dialogs - all gone.

Expected diff size: ~10× reduction in lines.

---

## Special case: not all admin UIs fit a table

A few admin tasks genuinely don't fit `CmsTablePage`:

- **Bulk import / CSV upload** - a form, not a table. Build it as a normal `HookWidget` page; expose it as `CmsWidgetItem.page(content: BulkImportPage())` in the shell. *Per-row* CSV import is a `CmsTableAction`.
- **Dashboards / metrics** - a charting page. Same: regular `HookWidget` page, exposed as `CmsWidgetItem.page`. Use the `CmsHeader`, `CmsButton`, `CmsLoader` primitives so it matches the theme.
- **Auth / sign-in** - outside the `CmsWidget`. Standard `utopia_hooks` Screen/State/View.
- **Singleton config document** - pricing, feature flags, a force-update policy: one document, no rows. Honest test: there is no list to page; a 1-row `CmsTablePage` bolts create/delete chrome onto something that is neither creatable nor deletable. Build a hand-rolled form page (idiom below).
- **Realtime stream table + bulk selection** - live presence/session data with multi-row bulk operations ("kick selected"). Honest test: `CmsDelegate.get` returns a one-shot `Future<List<JsonMap>>` with no streaming variant, and the table has no multi-row selection. Both capabilities are missing upstream as of 0.3.0, so a hand-rolled table is the only option.
- **RPC-only data viewer** - read-only data served by a cloud function or RPC because security rules block direct reads. Honest test: the data source cannot express CRUD at all. This one is borderline: a read-only `CmsDelegate` wrapping the RPC plus `CmsTableParams(canCreate: false, canEdit: false, canDelete: false)` often still fits; hand-roll only when the RPC cannot honor `get`'s filter / sort / paging contract.

**Discipline rule:** every bypass page carries a doc comment naming *which*
missing framework capability forces it, e.g.
`/// Not a CmsTablePage: CmsDelegate.get is Future-based (no streaming) and the table has no multi-select.`
When upstream grows that capability, the comment tells you the page can
collapse back into `CmsTablePage`.

The singleton-config form requires a hydration latch (a reload counter plus a `hydratedFor` guard) to keep background refetches from clobbering in-progress edits: seed the field state once per load id, save via `useSubmitState`, and treat empty fields as absent rather than defaulted.

These are *not* anti-patterns - the framework deliberately exposes shell +
theme primitives so non-table admin pages still look native to the panel. The
key distinction:

> "Custom widget *page* inside the `CmsWidget` shell" = fine. "Custom widget *replacing* `CmsTablePage` for a paged tabular CRUD view" = anti-pattern.

---

## Reference: the shape of a "right" admin page

When in doubt, the shape of a correct admin page is:

- One `HookWidget` (≤ ~150 lines).
- `build()` resolves the role / auth state (e.g. `useProvided<AuthState>()`),
  derives any flags, constructs the delegate, returns one `CmsTablePage`.
- The delegate is a thin `class XxxDelegate extends Cms<Backend>Delegate`
  declared in `lib/delegate/xxx_delegate.dart` (~10-40 lines), overriding
  `create / update / delete` only when business logic differs from the base.
- Role permissions flow through `CmsTableParams.canEdit/canCreate/canDelete`
  and `CmsEntryModifier(editable: …)`.
- Cross-cutting per-row actions are `CmsTableAction`s; cross-cutting nested
  edit-overlay UI lives in `CmsManagementSectionEntry`s.

Anything significantly longer or differently shaped is drifting toward the
anti-patterns above.
