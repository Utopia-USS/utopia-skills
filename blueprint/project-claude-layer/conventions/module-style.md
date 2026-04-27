# `*-module.md` — business module style

A **business module** reference describes a product feature: what it
does for the user, how the user moves through it, and the technical
surface that supports it. Use this style when an agent needs to
understand *why this exists for the product* before touching it.

This is **not API documentation** and **not a code dump**. The
purpose is to load business intent and key flow into context so the
agent can make judgment calls. Code is referenced (file paths,
class names) but rarely quoted, and never reproduced in full.

If the content has no product story — it's a repo-wide convention,
naming rule, or framework idiom — use `*-pattern.md` instead. If
it's a flat lookup table (component catalogue, color tokens, asset
inventory), use `*-cheatsheet.md` instead.

---

## Required sections

### `# <Module name>`

Short noun phrase. Match the user-visible feature name where
possible (e.g. *Assessment*, *Homework*, *Lesson Mode*).

### `## Business intent`

2–4 sentences. Product framing in plain language:

- **Who** uses it (which user role).
- **What** they accomplish.
- **Why** it exists (what problem it solves, what trade-offs were
  accepted in the design).

This is the section that makes the rest of the document make sense.
An agent reading only this paragraph should be able to say *"ah, ok,
this is the part of the app that does X for Y"*.

### `## User flow`

Step-by-step from the user's POV — not the system's. If there are
multiple roles (e.g. teacher + pupil, admin + end-user), give a
sub-flow for each, with the synchronisation points called out.

Include the moments where the **system has to react** — persist,
sync between devices, handle offline, recover from a crash, expire
a session. These are usually the bug-prone parts; flagging them in
the user flow makes them visible to the agent before they look at
code.

Format: numbered steps. Reference key class / state / service names
inline so the agent can search from there, but don't quote code.

### `## Location`

Bullet list of the directories that hold this module's
implementation. Just paths — one line each, no description (the
applicability of the parent skill already covers "what kind of
content lives in those paths").

### `## Data hierarchy`

The domain model — what entities exist, how they nest, where each
lives (Firestore collection, gRPC method, local store, generated
proto). Use a tree if the nesting is meaningful:

```
Assessment
  └── Flow
        └── Part
              └── Category
                    └── Item
                          └── Skill
```

For each non-trivial entity, one line describing what it represents
in business terms (not "a freezed class with five fields" — that's
visible in the code).

### `## Technical surface`

What an agent needs to know to ship a change here. Sub-sections as
needed:

- **Services** — table of `Service | Type | Role` (e.g. Firebase /
  Api / Data / Asset).
- **Screens / pages** — table of `Screen | State hook | Notes`.
- **Contracts** — proto messages, gRPC methods, public API surfaces.
- **Refs / typedefs** — the `Id` and `Ref` shapes used in this module
  (one block of `typedef` declarations is fine — that's signature,
  not implementation).

The bar for inclusion: *"would an agent need this to plan a sensible
change without re-reading every file?"* If yes, include the
signature. If no, skip it — the codebase is the source of truth for
implementation.

---

## Optional sections

### `## Session / sync`

Only if the module has cross-device or cross-user synchronisation.
Describe what's synchronised, how (which state holds the source of
truth, who reads vs writes), and what happens on disconnect.

### `## Conventions specific to this module`

Naming, scoping, validation rules — anything an agent needs to
follow that **isn't** covered by the parent skill's general
patterns. If a rule applies repo-wide, it belongs in a
`*-pattern.md` instead.

### `## Open questions / WIP`

Use while the module is still crystallising — known gaps, decisions
not yet made, places where the implementation is exploratory. As
the module stabilises this section empties out, and once it's
empty consider whether the module is ready to graduate to its own
skill.

### `## Anti-patterns`

Concrete examples of what NOT to do here, with the WHY. The "WHY"
is the load-bearing part — it lets the agent generalise to similar
situations not explicitly listed.

---

## Hard rules

- **No code blocks longer than ~10 lines.** If you're tempted, the
  agent should be reading the source file instead. Quote signatures,
  type definitions, and small examples — never full implementations.
- **No copy-paste from `freezed` / generated files.** The fact that
  a model has 12 fields is in the source. The fact that the model
  exists and what it represents is what the module reference adds.
- **Business intent leads, technical surface follows.** Reversing
  this order turns the document into API docs.
- **Reference, don't restate.** If a pattern is owned by a
  `*-pattern.md` (services, models, design system), link to it
  rather than re-explaining.
- **Module references can graduate.** When a module's surface area
  outgrows a single reference (multiple sub-flows, its own service
  patterns, its own anti-patterns), it splits into its own skill.
  Keep that path open by writing the module to be self-contained.
