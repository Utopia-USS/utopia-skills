# browser-testing bundle

Skill-only bundle. Installs `.claude/skills/browser-testing/SKILL.md` and
nothing else - the workflow is tool-driving guidance that an agent loads on
demand, not an orchestration step worth its own slash command.

## When to open

Open this bundle whenever the repo has any web target that compiles and
serves. The signal is auto-inspectable during Phase 0 repo inspection - no
user prompt needed:

- A Flutter package with a `web/` directory and `flutter build web` working,
  **or**
- An `admin/` workspace serving its UI via Chrome, **or**
- A `landing/` (or sibling) workspace running Next.js / Vite / similar dev
  server.

Multiple targets are fine - the SKILL.md genericises which package to start
via `<repo-web-target>`.

## Reversal - when **not** to open

- No buildable web target. Mobile-only repos (iOS/Android Flutter, native
  RN) skip this entirely.
- Team verifies exclusively via emulator / physical device and there is no
  browser-driveable surface.

## What this bundle ships

- `skill/browser-testing/SKILL.md` - the workflow skill.
- *No command* - browser-testing is tool-driving guidance loaded ad-hoc by
  the agent when the user asks for visual verification, perf work, or
  scenario driving. A slash command would add a wrapper without adding
  coordination value.

## Substitution checklist

- `<repo-web-target>` - directory name of the web-target package
  (e.g. `storefront`, `admin`, `packages/app`).
- MCP names - pick one of:
  - **Chrome DevTools MCP** (`<prefix>-chrome-devtools` or generic
    `chrome-devtools`) - preferred when full DevTools Protocol matters
    (performance traces, heap snapshots, lighthouse, network panel).
    Reference: repo-A and repo-B both use this.
  - **`Claude_Preview` MCP** (`preview_*` tool family) - simpler surface,
    no DTD layer. Reference: repo-C uses this.
- Dart MCP - `<prefix>-dart` if the repo bundles a DTD-backed Dart MCP
  (repo-A, repo-B); strip the DTD section if not (repo-C).
- Entry-point path - `lib/main_<env>.dart` or `lib/main.dart` depending on
  repo conventions.
- `fvm` prefix in run commands - keep only if the repo's toolchain canon is
  FVM=yes (bootstrap-procedure.md §0.7); strip to bare `flutter` otherwise.

Usually only `<repo-web-target>` and the MCP names need real touching;
keep the rest as-is. Light project tweaks beat heavy genericisation here -
the value is in the runtime quirks list, which is the same everywhere.

## Production precedent

All three reference repos open this bundle:

- repo-B - Flutter web app, uses `<prefix>-chrome-devtools` +
  `<prefix>-dart` MCPs.
- repo-A - admin web portal, uses `<prefix>-chrome-devtools` + `dart` MCPs,
  adds Supabase-specific network/error tables and a security caveat about
  key material.
- repo-C - player app + admin + Next.js landing, uses `Claude_Preview`
  MCP, adds multiplayer two-window flow.

## Strip-the-banner reminder

The SKILL.md ships with a `<!-- BLUEPRINT -->` banner below the frontmatter.
Remove it once `<repo-web-target>` and the MCP names are substituted in.
