# Reporting Gaps: When No Manifest Component Fits

## Why this exists

`protocol/SPEC.md` section 7 states the consumer loop plainly: "Screens are built
against manifest components only (the merged manifest once the project registers custom
components per 3.8); anything a design needs that no manifest id covers is reported as a
gap, never hand-rolled as a lookalike." The protocol's credibility rests
on that sentence being enforced, not just written down. A hand-rolled Material `Stepper`
styled to look like a utopia component is worse than an honest gap report, because it
hides the mismatch: the app now contains a widget that looks native but drifts from the
design system the moment the theme changes, was never token-bound, and gives no signal
to anyone that `utopia_ui` is missing a capability. A gap report is the mechanism that
keeps that signal alive - for the person reviewing the screen, and for whoever decides
whether the missing component becomes a project component (SPEC.md 3.8) or is worth
adding to `utopia_ui` upstream.

## When this applies

Whenever a design element (from any input type - see
[design-inputs.md](design-inputs.md)) has been checked against
[component-mapping.md](component-mapping.md)'s shortlist method and no manifest
component - including nothing reachable via the composition-first check below - covers
what it needs.

## The report format (fixed)

Every GAP, regardless of the element, is reported with exactly these five parts:

1. **Element name/description** - what the design element is and what it does, in
   plain terms.
2. **Closest manifest candidate ids, with why each was rejected** - not just "no
   component fits"; name the ids actually considered and the specific capability gap
   for each.
3. **What the element needs that the candidates lack** - the concrete missing
   capability (a prop, a state, a visual concept the manifest has no component for).
4. **Suggested action** - ask the user how to proceed; the two standing options are
   scaffolding the element as a **project component** (registered in the project
   manifest under a namespaced id - SPEC.md 3.8's production loop, the path most real
   gaps should take) and requesting the component upstream in `utopia_ui`.
5. **Component-spec seed** - so a "scaffold it" decision can start immediately: the
   proposed id including its namespace (`<project_package>:<kebab-name>`, SPEC.md 3.3),
   the props it needs (name + portable type per SPEC.md 3.5), its interaction states,
   and the token bindings it would read (SPEC.md 3.6 vocabulary).

Proportionality: when the honest suggested action is "drop it" rather than "scaffold
it" (a decorative flourish, a genuine one-off), parts 2, 3 and 5 may compress to a
line each - all five parts stay present, but their depth scales with how likely the
element is to become a real component. A functionally-required element or a
design-system-shaped one (a button variant, a form control, a recurring visual) is the
anti-case of this compression: full depth is mandatory, and the part-5 component-spec
seed is non-optional, because these are exactly the gaps most likely to become real
components. A report for such an element that lacks its seed is a report bug, not a
style choice.

Gaps are surfaced in **two** places, always together, never just one:

- In the **final response** to whoever asked for the screen, using the five-part format
  above.
- As a `// TODO` comment at the exact insertion point in the generated screen code,
  summarizing the gap inline so it survives beyond the conversation (a future reader of
  the file sees it even without the original response).

This is not only a formal-GAP rule: any deviation or simplification disclosed in the
response while mapping a design - a size quirk, an inert control, a state
simplification, things that are not formal GAPs - follows the same two-places rule. A
matching code comment lands at the relevant point, because a chat-only disclosure does
not survive the conversation.

## Composition-first check

Before writing a GAP report, check whether the element actually **decomposes** into
components that already exist - a GAP is for genuinely missing capability, not for an
element that just needs assembling from parts already in the manifest. The manifest's
`composes` field on each component is the first place to look: if a similar-looking
component already composes the pieces this element would need, that is strong evidence
the element is buildable today. For example, a design's "confirm/cancel prompt" is not a
gap merely because no component is literally named that - `confirm-dialog` exists
precisely because someone already did this composition (it internally composes
`button`). Cast the candidate net wider than visual lookalikes: include value-carrying
near-misses too - for a 1-5 rating element, a discrete value picker like
`dropdown-field` is a legitimate candidate to consider and reject, not just star-shaped
things. Only after confirming no combination of existing components (used as
directed by their own props - not by inventing new ones) covers the element does it
become a real GAP.

## Worked example: a stepper/wizard progress indicator

The design shows a 4-step signup wizard with a horizontal progress indicator above the
form: four numbered circles connected by a line, each either completed (filled, check
mark), current (outlined, highlighted), or upcoming (muted), with the current step's
label underneath.

Candidates considered, and why each was rejected (verified against
`manifest/utopia.manifest.json`):

- **`form-layout`** (`UtopiaFormLayout`) - "Scrollable layout with fixed content on the
  bottom." Its only props are `backgroundColor` (required), `fadeBarHeight`,
  `fadeDuration`, `content` and `bottom` (both required widget slots), across two
  constructors (`simple`, `raw`). It is a scrollable-body-plus-pinned-bottom-bar shell -
  useful for the wizard's *page* chrome, but it has no concept of steps, a current
  index, or per-step completion state. Rejected: wrong abstraction level entirely, not a
  near-miss.
- **`collapsible`** (`UtopiaCollapsible`) - animates one child between collapsed and
  expanded along a single axis (three constructors: unnamed/`vertical`/`horizontal`),
  driven by a binary `isExpanded`. No indicator dots or connecting track, no multi-step
  concept, and nothing about a step's completion state. Rejected: solves a different
  problem (show/hide), not "n of m progress."
- **`chip-list`** (`UtopiaChipList`) - a wrap of `chip` pills with a trailing "+N more"
  overflow chip; its only props are `labels` (`IList<String>`) and an optional
  `maxLength`. Visually the closest candidate - a horizontal run of small elements - but
  it renders plain string labels with no per-item state at all, and the underlying
  `chip` (composed by `chip-list`) only takes `child`, `leading`, `color`, and
  `contentColor` - there is no "completed / current / upcoming" concept, no connecting
  line between items, and no way to represent a step index. Rejected: the wrap layout is
  close, the semantics are not there.

What the element needs that none of the three candidates provide: an ordered sequence
of steps with a **per-step tri-state** (completed / current / upcoming), a connecting
track between them, and a current-step label - none of which exists on any manifest
component, alone or composed.

Resulting gap report (as it would appear in the final response):

> **GAP: step/wizard progress indicator.** A horizontal 4-step progress bar with
> numbered circles, a connecting track, and a completed/current/upcoming state per
> step, plus the current step's label underneath.
> Closest candidates considered: `chip-list` (rejected - `chip`/`chip-list` have no
> per-item completed/current/upcoming state and no connecting track, only a flat label
> wrap); `collapsible` (rejected - solves show/hide of one child, not multi-step
> progress); `form-layout` (rejected - a scrollable-body/pinned-bottom shell, unrelated
> to step indication).
> Missing capability: a step-sequence component with per-step state and a connecting
> track - `utopia_ui` has no equivalent today.
> Suggested action: confirm with the user whether to (a) scaffold it as a project
> component registered in the project manifest (SPEC.md 3.8), (b) request a
> step-indicator component upstream in `utopia_ui`, or (c) proceed without a progress
> indicator for now.
> Component-spec seed (for the scaffold path): proposed id
> `<project_package>:step-indicator`; props: `steps` (list of string), `currentIndex`
> (number), optional `onStepPressed` (callback); states: completed / current / upcoming
> per step; token bindings it would read: `colors.primary`, `colors.disabled`,
> `textStyles.caption`, `tokens.x`.
> Left as a `// TODO` at the indicator's position in the generated screen.

And the matching code-side marker:

```dart
// TODO(utopia-design-screen): GAP - no manifest component for a step/wizard
// progress indicator (considered: chip-list, collapsible, form-layout - none
// carry per-step completed/current/upcoming state or a connecting track).
// Placeholder below; see the chat response for the full gap report.
const SizedBox.shrink(),
```

## What NOT to do

- **Hand-rolled lookalike.** Do not build a custom `Row` of `Container`s with manual
  borders/colors/connecting lines styled to resemble a step indicator. It compiles, it
  even might look right at first glance, but it reads no tokens, has no place in the
  manifest, and drifts silently the moment the theme changes.
- **Material/Cupertino stand-in.** Do not reach for Flutter's `Stepper` (or a Cupertino
  equivalent) "just to unblock the screen." It is not a manifest component, ships its
  own unrelated visual language, and defeats the entire "manifest components only"
  contract this skill exists to enforce. The narrow exception for functionally-required
  elements is defined below - a declared, unstyled stand-in, never a styled one.
- **Prop invention.** Do not invent a prop on an existing component to make it fit (e.g.
  a `UtopiaChipList(activeIndex: 2)` - `chip-list`'s real props are only `labels` and
  `maxLength`; there is no `activeIndex`). If a component is close but missing exactly
  one capability, that is still a GAP, reported as such - not a reason to imagine an API
  the manifest doesn't have.

**Wrong:**

```dart
// Do not do this - invents a prop UtopiaChipList does not have, and pretends
// a flat label wrap has step semantics it doesn't.
UtopiaChipList(labels: IList(const ['1', '2', '3', '4']), activeIndex: currentStep)
```

**Right:**

```dart
// TODO(utopia-design-screen): GAP - no manifest component for a step/wizard
// progress indicator. See the chat response for the full report.
const SizedBox.shrink(),
```

## When the gap is functionally required

The `SizedBox.shrink()` placeholder above works because a step indicator is decorative -
the signup form still functions without it. That posture flips when the missing element
is a required control: the only way to cancel, submit, or dismiss a screen, not a
decorative or informational gap (those keep the `SizedBox.shrink()` placeholder). When
the screen genuinely does not function without the element, a minimal DECLARED stand-in
is permitted: the plainest widget that provides the function (a bare `TextButton` for a
missing "Cancel" affordance, say), function only, NEVER styled to imitate the design
system - no token dressing, no colors/radii/typography chosen to look native. An
unstyled stand-in that looks obviously foreign is the point: it keeps the gap visible
instead of hiding it. The `// TODO(utopia-design-screen)` marker at the insertion point
names it a stand-in, and the five-part report is still produced in full, naming the
stand-in explicitly (in the element description or the suggested action) - a stand-in
never downgrades the report.

## See also

- [component-mapping.md](component-mapping.md) - the shortlist method a GAP is the
  fallback from; always exhaust this first
- [design-inputs.md](design-inputs.md) - where the element list a GAP check runs
  against comes from
