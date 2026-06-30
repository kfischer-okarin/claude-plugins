# {{ FEATURE NAME }}
<!-- Just the feature name. No subtitle describing the document. -->

## Goal

<!-- WHAT changes and WHY, as prose: the current problem, why it's worth changing,
     what the change enables. Sourced from the hearing. Keep implementation
     mechanics out (how the current code works, function/constant names, sort
     strategies) — those belong in Phases. -->
{{ GOAL }}

### Constraints / Requirements of the Solution

<!-- Each item is something the user said in the hearing: what the solution must
     or must not do, what it must reuse, integrate with, or avoid. Not your own
     design or implementation choices — those get decided in Phases. -->
- {{ CONSTRAINT 1 }}
- ...

## Phases

Current understanding of the implementation. Later phases are a rough direction
and may change as things are learned.
<!-- A checklist of (somewhat) independent units of work. If possible the first
     phase is a quick-and-dirty end-to-end thin slice that stubs or hardcodes
     freely. Only the current phase carries a sub-step todo-list — never pre-write
     sub-steps for future phases. Design and implementation decisions live here. -->

- [ ] **P1: {{ PHASE 1 TITLE }}**
      {{ PHASE 1 DESCRIPTION }}
- ...

## Current position / notes

<!-- One or two lines: where you are, what's next. -->
- {{ CURRENT STATE }}

## Deferred work

<!-- Work the user recognized as wanted or needed but deliberately pushed out of
     this round — "we want this, just not now". Only items the user actually
     decided to defer. Not permanent non-goals: if it was never going to be part
     of the work, it does not go here. -->
- {{ DEFERRED WORK 1 }}
- ...

## Appendix: Working Principles

How to execute and update this plan across sessions.

- **Get the plan approved before implementing.** Present the plan, ask for
  approval, fix what's flagged, then start.
- **Before each phase, describe the rough design approach and get a quick OK** —
  where things get added/changed at a high level. Stay high-level on purpose:
  don't lock down low-level choices in advance. Implementing the phase settles
  them naturally, and pinning them early just creates spec churn.
- **Write a sub-step todo-list only for the phase you're currently in**, and only
  after you've described and confirmed its rough approach. Never pre-write
  sub-steps for future phases — what you learn will likely invalidate them.
- **When you complete a sub-step, rewrite it in place in past tense**, folding in
  what you did, what you learned, and how you verified it in abstract terms (e.g.
  "ran acceptance tests", "ran unit tests", "tested manually via the CLI"). Don't
  append a separate "Done" summary. Check off the phase once all its sub-steps are.
- **When you discover a "do this later, within this work" item:** add it as a
  sub-step if it belongs to the current phase, otherwise note it in the relevant
  future phase's description.
- **When the user defers a wanted item out of this round, move it to Deferred
  work.**
- **Keep "Current position / notes" pointing at what's next.**

### Example phases in progress

- [x] **P1: Webhooks persisted end-to-end**
  Quick-and-dirty thin slice: receive a webhook, store it, show it in the admin list.
  - [x] Added deliveries table + model
  - [x] Controller now writes the payload on receipt — stored raw for now, redaction deferred to P3
  - [x] Added a bare admin list view; confirmed the receipt-to-list path — ran acceptance tests
- [ ] **P2: Retry failed deliveries**
  Background job re-sends deliveries that errored, with capped backoff.
  - [x] Marked deliveries failed / succeeded on the delivery record
  - [ ] Enqueue the retry job with capped backoff
- [ ] **P3: Redact secrets in stored payloads**
  Direction only — exact redaction rules still open.

P1 is done: its sub-steps are rewritten in past tense and carry what/learned/how
inline. P2 is current, so it has a sub-step todo-list. P3 is still future — just a
title and a one-line direction, no sub-steps until it becomes current.
