# Design review pass - the 6th phase

Run AFTER the exit gate and the post-migration refactor checklist, per DOMAIN CLUSTER
(all state files serving one feature area), before `--finalize`.

## Why this phase exists (field evidence)

The exit gate and the 5th-phase checklist are COMPLIANCE framings: they verify the code
is correct, idiomatic, and free of named anti-patterns. A wrong solution SHAPE passes
both. Field data from a completed full-app migration: the grep-based checklist recovered
~1.8% of the new state code, while a shape-level review of a single fully-compliant,
review-passed settings cluster found a redesign from 654 to ~182 LOC (-72%) and three
latent bug classes (stale-read join race, unguarded double-tap, refresh-per-rebuild).
A calibrated sweep of the remaining state layer found ten more such families worth
~600-700 LOC. None of them violated any gate.

The failure mode is not capability - it is framing. An agent asked "does this comply"
approves the first-obvious shape. The same model asked "is this the best possible shape"
finds the redesign. This phase asks the second question, explicitly.

## How to run it

Spawn a FRESH-context reviewer (never the agent that wrote the migration) per domain
cluster with this framing:

> Review these files as a demanding staff engineer. Question: is this the best possible
> utopia_hooks design for these responsibilities? Judge the chosen solution SHAPE, not
> correctness or style. Benchmark: LOC and maintainability (single source of truth,
> number of places to touch per change, testability). If you would design any part
> differently, show the alternative concretely with estimated LOC before/after. Verify
> every API you propose against the resolved utopia_hooks package source. "Already
> optimal" is an acceptable verdict only with rigorous justification.

Inputs: the cluster's state files + their consumers, the utopia_hooks package source
(resolved version from pubspec.lock), the foundation-skill references. Do NOT give it
the migration agent's reasoning or the parity notes - fresh eyes on shape.

## Field-verified finding families (what such reviews turn up)

1. **Missing combinator** - the same hook skeleton hand-written 3+ times across files
   (slider-plus-textfield editor, image pick/remove pair, pick -> persist -> refresh ->
   fan-out row). Fix: one parameterized hook; often the combinator already exists
   somewhere in the repo - search before writing. Duplicated skeletons also duplicate
   bugs: one field case produced the same keyless-useEffect bug in every copy.
2. **Write path not invalidating read path** - N hand-written `await set(); refresh();`
   pairs at call sites. Every forgotten pair is a stale-UI bug; a post-write `refresh()`
   can join a pre-write in-flight compute (`refreshOrWait`) and return stale data. Fix:
   invalidate INSIDE the write (refresh within the submit run, `clear()` first when the
   payload must not survive), so call sites cannot forget it.
3. **Split read/write shapes for settings surfaces** - see
   [settings-prefs-migration.md](./settings-prefs-migration.md).
4. **Hand-mirrored snapshot classes** - N-field data class copying an existing entity
   field-for-field (3 edit sites per new field). Fix: expose the entity, add getters
   only where projection is real.
5. **Dead API** - setters/getters/flags with zero callers after migration (parity ported
   surface nothing consumes anymore). Sweep call sites, delete.
6. **Submit states nobody reads** - `inProgress` exposed but never consumed, no
   double-tap guard on the write path. Fix: one shared submit state per mutually
   exclusive action group + `skipIfInProgress`, or wire the button idiom
   (`toButtonState` / `useSubmitButtonState`).
7. **Refresh blanks the page** - consumers gate on `data == null` while every reload
   nulls the payload. Fix: `useValueOrPrevious()` on the computed state (one line) when
   the old snapshot should stay visible.
8. **Stateless wrapper classes** - sub-state classes owning no state (pure usecase
   call-through with ctor ceremony). Collapse into the parent until a real ownership
   boundary appears; topical grouping is not an ownership boundary.

## Process rules

- Findings land as SEPARATE commits (`refactor(app): <what> - <why>`), never mixed into
  `migrate:` commits. Bisect hygiene applies.
- Parity still holds: a shape change that alters observable behavior (optimistic writes,
  kept-visible snapshots during reload) is an accepted-delta DECISION for the
  orchestrator/owner, recorded in the commit body - not something the reviewer applies
  silently.
- Prioritize by LOC-recovery-to-risk: combinators and dead-API sweeps are low risk;
  shape changes touching write semantics need the full test gate per commit.
- The pass is bounded: one review per cluster, one fix wave per review, re-run the exit
  gate after. Do not loop - residual judgment calls get journaled, not endlessly
  re-reviewed.
