---
title: Multi-Page Shell Pattern
impact: HIGH
tags: architecture, screen, navigation, tabs, bottom-nav, shell, composition
---

# Skill: Multi-Page Shell Pattern

A **multi-page shell** is any screen that hosts N sibling pages the user switches between:
bottom nav bar, top tabs, navigation rail, segmented control, wizard steps, anything.

## The Two Rules (non-negotiable)

> **1. Shell is Screen/State/View.** Standard triple. Owns the "currently selected page"
> state and shell-level cross-cutting effects.
>
> **2. EVERY inner page is Screen/State/View — the SAME full triple.** Not a monolithic
> `HookWidget`, not a `StatefulWidget`, not an inline `StreamBuilder` soup. Every page is
> a complete Page + State class + hook + stateless View, identical in shape to any
> top-level routable screen. Being embedded in a `PageView` / `IndexedStack` /
> `TabBarView` does **not** exempt a page from the pattern. Having a parent shell does
> **not** exempt a page from the pattern. Being "simple" does **not** exempt a page from
> the pattern.

Everything else — index vs enum, `PageView` vs `IndexedStack` vs `TabBarView`, local vs
global index, swipeable vs tap-only — is a spectrum chosen per project. **The
composition rule is constant.** If you find yourself writing an inner page without its
own `state/` and `view/` folders, you are violating the pattern regardless of how small
or shell-specific the page feels.

## Quick Pattern

**Incorrect — monolithic page widget with inline logic:**
```dart
// songs_tab_widget.dart — 149 lines, all logic in build()
class SongListWidget extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final audioPlayer = context.currentSongWidget.audioPlayer;
    final reviewState = useProvided<ReviewState>();

    return StreamBuilder<int?>(
      stream: audioPlayer.currentIndexStream,
      builder: (context, currentIndexSnapshot) {
        return StreamBuilder<bool?>(
          stream: audioPlayer.playingStream,
          builder: (context, playingSnapshot) {
            return Scaffold(
              body: CustomScrollView(slivers: [/* ... inline business logic ... */]),
            );
          },
        );
      },
    );
  }
}
```
Problem: page carries its own logic, streams, derivations directly in `build`.
No State class, no View split, no testability. The fact that it's hosted inside a
shell's `PageView` is irrelevant — it's still a screen, so it must follow the screen
pattern.

**Correct — page is a full Screen/State/View triple:**
```dart
// pages/songs/songs_page.dart
class SongsPage extends HookWidget {
  const SongsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = useSongsPageState();
    return SongsPageView(state: state);
  }
}

// pages/songs/state/songs_page_state.dart
class SongsPageState {
  final IList<Song> songs;
  final int? currentIndex;
  final bool isPlaying;
  final void Function(Song) onSongTapped;
  // ...
}

SongsPageState useSongsPageState() {
  final audioPlayer = useInjected<AudioPlayerService>();
  final currentIndex = useMemoizedStream(() => audioPlayer.currentIndexStream, []);
  final isPlaying = useMemoizedStream(() => audioPlayer.playingStream, []);
  // ...
}

// pages/songs/view/songs_page_view.dart — StatelessWidget, receives only `state`
```

## Deep Dive

### When to Use

Any screen where the user alternates between ≥2 sibling pages without leaving the
screen. Typical shapes:

- Bottom nav bar (Home / Profile / Settings)
- Top tabs (by category, by status, by time range)
- Navigation rail (tablet/desktop layouts)
- Wizard / stepper (sequential multi-step flow — same pattern, just with "next/prev"
  semantics instead of free switching)
- Segmented control switching between views of the same data

If the user leaves the shell entirely when switching (`Navigator.push` to another
route), that's just routing — not this pattern.

### Invariants (constant across all implementations)

1. **Shell is Screen/State/View.** `MainScreen` / `HomeScreen` / `RootScreen` — whatever
   name — follows the triple.
2. **Each page is Screen/State/View — no exceptions.** Not "only if complex", not
   "unless it's just displaying a list", not "we'll split later". Every inner page has
   its own `pages/<name>/<name>_page.dart` + `pages/<name>/state/<name>_page_state.dart`
   + `pages/<name>/view/<name>_page_view.dart` from day one. A page may omit
   `route` / `routeConfig` statics if it's never pushed as a route — that is the **only**
   difference from a top-level screen. Everything else is identical: pure-wiring Page,
   State class + hook with all logic, stateless View receiving `state` only.
3. **Shell state owns selection.** A field like `int currentIndex` / `HomePage currentPage`
   plus an `onPageChanged` callback.
4. **Nav widget is stateless and takes `state`.** `BottomBar(state: state)` — not a
   `StatefulWidget` tracking its own index, not a widget calling hooks.
5. **State flows down, callbacks up.** Pages don't reach into shell state via
   `InheritedWidget` / context hacks. If a page needs to cause a shell-level effect
   (e.g. jump to another tab), it goes through a global state or an injected coordinator
   — not through ancestor lookup.
6. **Cross-cutting mount-time effects live in shell state hook.** Deep links, share
   intents, onboarding dialogs, notification routing — these belong to the shell, not
   to any single page. Split into sub-hooks when there are more than one or two.

### The Implementation Spectrum

None of these choices change the composition rule. Pick per project.

| Axis | Options                                                               | When to pick |
|---|-----------------------------------------------------------------------|---|
| **Page identity** | `int index` / `enum HomePage` / `String id`                           | Enum preferred — refactor-safe, typed, can carry metadata (icon, label, role-gating) |
| **Container** | `IndexedStack` / `PageView` / `TabBarView` / `AnimatedSwitcher`       | `IndexedStack` preserves page state across switches (best default for tabs with form inputs or scroll positions). `PageView` enables swipe. `TabBarView` when using Material `TabBar` theming |
| **Selection state** | `useState<T>` / `PageController` + `useListenable` / `TabController` + `useListenable` | Plain `useState` when you only need to know which page is active. Controllers when you need to drive animations (swipe, indicator) |
| **Index scope** | local (shell state) / global (`TabGlobalState`)                       | Local by default. Global only when: (a) deep links target specific tabs, (b) user configures tab order/visibility at runtime, (c) other screens jump to specific tabs |
| **Page list** | static constant / computed from config+role                           | Computed when feature flags, user role, or platform gate visibility |
| **Page construction** | inline children / enum builder method                                 | Builder method when page list is dynamic (feature-flagged, role-gated) |

### Canonical Shape

The cleanest mix of the axes above: enum identity + `useState` + `IndexedStack` +
computed `visiblePages` + stateless nav widget.

```dart
// home_screen.dart
class HomeScreen extends HookWidget {
  static const route = '/home';
  static final routeConfig = RouteConfig.material(HomeScreen._);

  const HomeScreen._();

  @override
  Widget build(BuildContext context) {
    final state = useHomeScreenState();
    return HomeScreenView(state: state);
  }
}

// state/home_screen_state.dart
enum HomePage {
  info(InfoPage.new, AppIcons.info),
  live(LivePage.new, AppIcons.live),
  game(GamePage.new, AppIcons.game);

  final Widget Function() builder;
  final String icon;

  const HomePage(this.builder, this.icon);
}

class HomeScreenState {
  final HomePage currentPage;
  final IList<HomePage> visiblePages;
  final void Function(HomePage) onPageChanged;

  const HomeScreenState({
    required this.currentPage,
    required this.visiblePages,
    required this.onPageChanged,
  });
}

HomeScreenState useHomeScreenState() {
  final userState = useProvided<UserState>();
  final configState = useProvided<ConfigState>();
  final pageState = useState<HomePage>(HomePage.live);

  IList<HomePage> computeVisiblePages() {
    final visibility = {
      HomePage.info: configState.isInfoPageVisible,
      HomePage.live: true,
      HomePage.game: configState.isGamePageVisible && userState.role != UserRole.none,
    };
    return HomePage.values.where((p) => visibility[p] ?? true).toIList();
  }

  return HomeScreenState(
    currentPage: pageState.value,
    visiblePages: computeVisiblePages(),
    onPageChanged: (page) => pageState.value = page,
  );
}

// view/home_screen_view.dart
class HomeScreenView extends StatelessWidget {
  final HomeScreenState state;

  const HomeScreenView({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: HomePage.values.indexOf(state.currentPage),
          children: [for (final page in HomePage.values) page.builder()],
        ),
      ),
      bottomNavigationBar: HomeScreenBottomBar(state: state),
    );
  }
}

// widget/home_screen_bottom_bar.dart — StatelessWidget, renders state.visiblePages,
// calls state.onPageChanged(page). No hooks.
```

Each page (`InfoPage`, `LivePage`, `GamePage`) is a full Screen/State/View triple living
in its own folder: `pages/info/info_page.dart`, `pages/info/state/info_page_state.dart`,
`pages/info/view/info_page_view.dart`.

### Variants

**Swipeable (`PageView`):** replace `IndexedStack` with `PageView`, swap `useState<HomePage>`
for `useMemoized(PageController.new)` + `useListenable(controller)`, map enum ↔ index in
the state hook. Use when swipe-to-switch is the intended UX. Note: `PageView` rebuilds
pages as they scroll into view — if pages have expensive state you want preserved, prefer
`IndexedStack`.

**Material tabs (`TabBarView`):** use `TabController` (or the `TabControllerWrapper` helper
from utopia_hooks) when you want `TabBar`'s indicator animation and gesture integration.
The shell state still owns the enum; the controller is wired to it.

**Global-state-backed index:** when requirement (a/b/c above) applies, move
`HomePage currentPage` out of shell state into a `TabGlobalState`. Shell state consumes
it via `useProvided<TabGlobalState>()` and calls `tabState.selectPage(page)` instead of
mutating a local `useState`. Everything else is identical.

**Wizard / stepper:** same pattern — just constrain `onPageChanged` to `goNext()` /
`goPrevious()` and compute `canGoNext` in the state.

### Inner Page Rules

**An inner page is a regular screen. Period.** There is no such thing as a
"lightweight page" or a "shell-embedded widget" that skips the triple. If the content
justifies its own entry in the shell's nav, it justifies its own Screen/State/View.

Required for every single page, same as [screen-state-view.md](./screen-state-view.md):

- `pages/<name>/<name>_page.dart` — `HookWidget`, pure wiring. Its `build()` calls
  exactly one hook: `use<Name>PageState(...)`, and returns `<Name>PageView(state: state)`.
  Nothing else.
- `pages/<name>/state/<name>_page_state.dart` — immutable State class + `use<Name>PageState`
  hook. All logic, streams, computations, callbacks. No widget imports.
- `pages/<name>/view/<name>_page_view.dart` — `StatelessWidget`. Constructor takes only
  `state`. No hooks, no `useProvided`, no `useInjected`, no `BuildContext` reads beyond
  theming.
- `pages/<name>/widget/` — for extracted widgets when the View grows past ~300 lines.

Cross-cutting rules for inner pages:

- Global state via `useProvided<X>()` inside the page's own state hook — **not** via
  the shell's state, **not** by reading shell State through context.
- Page-local mount-time effects (fetches, subscriptions) live in the page's state hook.
  They run only when the page exists in the widget tree. Mount/unmount behaviour
  depends on the container: `IndexedStack` keeps pages mounted; `PageView` mounts lazily
  as pages scroll into view; `TabBarView` mounts all children by default (or lazily with
  `KeepAliveBloc`-style wrappers).
- If a page needs shell-level context (e.g. "jump to another tab"), the shell injects a
  callback via global state or via a coordinator object — the page does not look up the
  shell ancestor.

**Red flags that indicate the rule is being violated:**

- `*Tab` / `*Page` widget class is the only file in its folder (no `state/` or `view/` siblings)
- `build()` of an inner page is longer than ~10 lines
- `StreamBuilder`, `FutureBuilder`, `useProvided`, or `useInjected` appearing in an inner page's View or build method
- Any business logic, fetch call, or derivation written inline in the page widget
- Inner page extends `HookWidget` but has no corresponding `state/*_page_state.dart` file

### Shell-Level Cross-Cutting Effects

These belong to the shell state hook, not to any page:

- Deep-link / app-link handling
- Share-intent / notification-payload routing to the right page
- First-launch onboarding, marketing dialogs, feature discovery
- Cross-page streams (e.g. "download finished" toast shown regardless of current page)

When you have more than one or two, split them into sub-hooks
(`_useDeepLinkHandling()`, `_useShareIntent()`, `_useOnboarding()`) composed by the main
shell state hook. See [composable-hooks.md](./composable-hooks.md) Pattern 3.

### Naming Convention (soft)

Common convention across canonical examples:

- `XScreen` — reachable as a route (`push`ed, `go`d, or top-level)
- `XPage` — embedded inside a shell's container, never pushed as a route

Both follow the same triple. The distinction is purely where the entry point is.
Fine to deviate per project style, but pick one and be consistent.

## Common Pitfalls

- **Monolithic page widget.** A `*TabWidget` / `*Page` as a single `HookWidget` with
  inline `StreamBuilder`, `useProvided`, and business logic in `build`. **This is the
  #1 violation of this pattern.** Fix: extract State class + stateless View, same as
  any other screen — no "it's just a small tab" exceptions.
- **Page with only a Page file, no `state/` or `view/`.** "I'll split it later" ages
  badly; the page will keep accreting logic in `build` until it's 400 lines. Split from
  day one, even when the page is small.
- **Navigation logic in View.** `onTap: () => controller.animateToPage(...)` in the
  nav widget. Fix: expose `onPageChanged(HomePage)` from state; nav widget just calls it.
- **`controller.page!.round()` inline in View.** Caller reads raw controller state
  across the shell. Fix: expose `currentPage` as a getter on the state class.
- **Hardcoded index magic numbers** (`if (index == 2) ...`). Fix: enum-based identity.
- **Page reaching into shell state via `context`.** `context.findAncestorWidgetOfExactType<ShellView>()`
  to jump tabs. Fix: global state for the selected page, or an injected coordinator.
- **Nav widget as `StatefulWidget`** tracking its own selected index with `setState`.
  Fix: stateless widget receiving state and callback.
- **Mount-time shell effects scattered inside a page's build.** A page calling
  `FeatureDiscovery.discoverFeatures` or subscribing to `appLinks` in its state hook.
  Fix: move to shell state hook.
- **All pages hardcoded in View with no visibility logic** despite feature flags / role
  gates existing. Fix: `visiblePages` computed in state from global config + role.

## Related

- [screen-state-view.md](./screen-state-view.md) — the triple pattern itself
- [global-state.md](./global-state.md) — when shell index lives in global state
- [composable-hooks.md](./composable-hooks.md) — splitting large shell hooks into sub-hooks
