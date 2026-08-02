---
name: browser-testing
description: >
  Only when explicitly asked. Browser testing workflow for the repo's web
  target (`<repo-web-target>`) using a Chrome DevTools MCP (or `Claude_Preview`
  MCP) and, if available, a DTD-backed Dart MCP. Applies when verifying UI
  changes in the browser, driving the app via a11y snapshots and click/fill,
  connecting the Dart Tooling Daemon for hot reload or widget-tree inspection,
  debugging runtime errors via console logs, capturing screenshots as proof of
  visual changes, or troubleshooting Flutter-web runtime quirks
  (fill-drops-first-char, broken keyboard scrolling, stale snapshot uids
  after navigation).
---

<!-- BLUEPRINT - adapt per-repo. Workflow-style skill. Open this skill only if Phase 0 inspection confirmed a web target exists. Substitute <repo-web-target> tokens. Strip this banner after substitution. -->

# Browser testing

Workflow-style skill. Format intentionally diverges from the
module / pattern / cheatsheet trichotomy (skill-design.md's taxonomy for
project reference docs) - this content is organised around
**Modes / Tools / Steps / Recovery**, because the value is in the runtime
quirks and tool sequencing, not in a layered knowledge map.

Drives the repo's web target (`<repo-web-target>`) in Chrome via two MCPs
working together:

- **Chrome DevTools MCP** (`<prefix>-chrome-devtools` or `Claude_Preview`) -
  page discovery, a11y snapshots, click, fill, `evaluate_script`,
  screenshots, network panel, console logs, performance traces, heap
  snapshots, lighthouse audits.
- **Dart MCP** (`<prefix>-dart`, *if available*) - DTD-backed hot reload,
  widget tree inspection, runtime errors, symbol resolution.

Neither MCP on its own is enough when both are available. Chrome DevTools
drives the page; Dart MCP drives the running Dart VM. They meet through the
Dart Tooling Daemon (DTD) URI that `flutter run --machine` emits.

If the repo only has the Chrome DevTools MCP (no Dart MCP), skip the DTD
section - semantics-tree driving still works.

## When to use - explicit ask only

**Do not auto-launch the browser to verify edits.** Spinning up a Flutter web
build takes 1-3 minutes per cold start and adds little signal for routine
code changes; the analyzer + reading the diff is faster for most edits.

Use this skill only when the user explicitly asks: "test it", "verify
visually", "run scenarios", "measure perf", "heap snapshot", "screenshot",
or equivalent in the team's language.

Performance / diagnostics work counts as explicitly asked when the task
itself is "diagnose / measure / repro in browser".

## Launch the app

From repo root (adjust the entry point per the team's `lib/main*.dart`
convention):

```bash
# `fvm` prefix: keep only if the repo's toolchain canon is FVM=yes
# (bootstrap-procedure.md §0.7); use bare `flutter` otherwise.
cd <repo-web-target> && fvm flutter run \
  -d chrome \
  -t lib/main.dart \
  --dart-define=FORCE_ENABLE_SEMANTICS=true \
  --machine \
  --web-browser-debug-port=47688
```

Why each flag:

| Flag | Why |
|------|-----|
| `-d chrome` | Chrome device |
| `-t lib/main.dart` | Entry point (some repos split `lib/main_staging.dart` / `lib/main_live.dart` - pick the right one) |
| `--dart-define=FORCE_ENABLE_SEMANTICS=true` | Enables the a11y tree so `take_snapshot` returns interactable `uid`s. Without it, snapshots are shallow and `click` has nothing to target. |
| `--machine` | Daemon mode - emits JSON events on stdout, including `app.dtd` with the DTD WebSocket URI |
| `--web-browser-debug-port=47688` | Stable DevTools port the Chrome DevTools MCP attaches to |

Leave the process running throughout the session. When launching via Claude's
`Bash` tool, use `run_in_background: true` so other tools remain responsive.

Non-Flutter targets (Next.js landing, Vite, etc.) launch via their own dev
servers - `npm run dev`, `pnpm dev`. Skip the Flutter-specific flags; the
rest of this skill still applies for snapshot/click/screenshot work.

## Connect the Dart MCP to the DTD

*(Skip this whole section if the repo does not ship a Dart MCP.)*

Watch `flutter run` stdout for an event line like:

```json
[{"event":"app.dtd","params":{"appId":"...","uri":"ws://127.0.0.1:57999/rwEUKs-q0mE="}}]
```

Extract the `uri`, then call the Dart MCP's `connect_dart_tooling_daemon`
tool with `{ "uri": "ws://127.0.0.1:57999/..." }`.

On success these become available:

- `hot_reload` / `hot_restart`
- `get_widget_tree`
- `get_runtime_errors`
- `get_active_location`
- `resolve_workspace_symbol`

If the user launched `flutter run` in an external terminal and the URI is not
in Claude's bash output, **ask the user to paste the `app.dtd` line.** Do
not guess the URI - ports are dynamic.

## Drive the UI

Standard flow (tool names vary by MCP; the shape is the same):

```
1. list_pages        # find the right tab
2. select_page       # skip if single tab - auto-selected
3. take_snapshot     # a11y tree with uids
4. click             # click by uid
```

**Snapshots vs screenshots:**

- `take_snapshot` first - gives `uid`s you can click.
- `take_screenshot` when layout must be verified visually, when the a11y
  tree missed content, or when clicks aren't behaving.
- Combine both when debugging - snapshot to find uids, screenshot to verify
  visual state.

## Performance and diagnostics

If the Chrome DevTools MCP exposes the full Chrome DevTools Protocol, prefer
it over ad-hoc JS profilers when measuring real perf:

- `performance_start_trace` / `performance_stop_trace` - same trace as
  Chrome's Performance panel (frame timings, long tasks, layout thrash, GPU
  work).
- `take_heap_snapshot` - full V8 heap dump; diff two snapshots before/after
  a navigation cycle to find leaks.
- `lighthouse_audit` - Performance / Best Practices / a11y scores.
- `list_network_requests` + per-request body inspection - find duplicate
  asset fetches, watch backend wire traffic.

Heavy listing screens and frequent network/auth flows are where heap-snapshot
diffs catch the most common regression (stream subscriptions not cancelled,
listeners not disposed).

## Known quirks - Flutter web

These are runtime behaviours of Flutter web (and its interaction with
chrome-devtools-mcp), not bugs in the app code.

### `fill` drops the first character

Typing "Emma" yields "mma"; "test@example.com" yields "est@example.com".
Consistent. For automated login / form filling, prepend a throwaway char
(`"XEmma"` → "Emma") or accept the truncation when the resulting value is
still functional. Re-verify after MCP upgrades - this may get fixed upstream.

### Standard scrolling does not work

`window.scrollTo()`, keyboard `End` / `Home` / `Page Down` - none of these
scroll Flutter web content. Flutter manages its own scroll containers inside
the semantics host elements. Use `evaluate_script`:

```js
() => {
  const all = document.querySelectorAll('*');
  for (const e of all) {
    if (e.scrollHeight > e.clientHeight + 50) {
      e.scrollTop = e.scrollHeight;
    }
  }
  return 'scrolled';
}
```

Target a specific container by narrowing the selector once `take_snapshot`
identifies the right host element.

### `uid`s go stale after navigation / state change

A `uid` from a previous snapshot may no longer exist after a route change
or any state-changing click; the next `click` call throws `DOM.resolveNode`
errors. **Always `take_snapshot` after navigation or any action that changes
the UI before the next `click`.**

### Dialogs sometimes ignore uid-click on Close

Recovery fallbacks in order:

1. `press_key` with `"Escape"`.
2. Click the backdrop - look for a `generic "Dismiss"` node in the snapshot.

### Single-tab auto-select

If only one Chrome tab exists, `list_pages` auto-selects it. Skip
`select_page` in that case.

## Non-Negotiable Rules

- **Always `--dart-define=FORCE_ENABLE_SEMANTICS=true`.** Without it, MCP
  snapshots are shallow and click targets do not exist.
- **Stable port 47688.** MCP config assumes it; do not vary.
- **Re-snapshot after every navigation / state-changing action** before the
  next `click` - stale uids cause `DOM.resolveNode` errors.
- **Use `evaluate_script` for scrolling Flutter web** - keyboard keys and
  `window.scrollTo` do not work.
- **Never guess the DTD URI** - read it from the `app.dtd` event line or
  ask the user to paste it. Ports are dynamic.
- **Don't drive `git push` / deploy from a browser-driven session** -
  preview is verification, not deployment.
- **Hand proof to the user** - screenshot for visual changes, console log
  for runtime errors, network trace for API changes. Do not ask the user to
  verify manually.

## Self-Audit

1. Started the right package (`<repo-web-target>` - the one with a `web/`
   directory or dev server)?
2. Used `--dart-define=FORCE_ENABLE_SEMANTICS=true` and
   `--web-browser-debug-port=47688`?
3. DTD URI extracted from the `app.dtd` event - not guessed? *(Skip if no
   Dart MCP.)*
4. `connect_dart_tooling_daemon` called with the exact URI string?
5. Re-snapshotted after every state change before the next click?
6. Captured a screenshot for visual changes / a console log for runtime
   errors / a network trace for API changes - handed proof to the user, did
   not ask them to verify manually?
7. `fill` operations account for the first-character drop?
8. Stopped `flutter run` when finished, or noted in the summary that it's
   left running for the user?

## Related

- The repo's master skill - project conventions, env split, design system.
  The browser-testing flow drives the repo's UI, so all master-skill
  non-negotiables apply to the code under test.
- Chrome DevTools MCP (or `Claude_Preview` MCP) - full tool surface (click,
  fill, evaluate_script, performance_start_trace, take_heap_snapshot,
  lighthouse_audit, list_network_requests, etc.).
- Dart MCP - DTD-backed dev tools (hot_reload, widget tree, runtime errors).
