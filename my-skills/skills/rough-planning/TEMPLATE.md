# {{ FEATURE NAME }}
<!-- Just the feature name. No subtitle describing the document. -->

## Goal

<!-- WHAT changes and WHY, as prose. Cover the current problem, why it's worth
     changing, and what the change enables. Sourced from the hearing.
     Keep implementation mechanics out — how the current code works,
     function/constant names, sort strategies, your own design choices. Those
     are decided in Phases, not here. -->
{{ GOAL }}

## Non-goals

<!-- Things deliberately NOT part of this work, and not planned for later either
     — they bound the scope. Distinct from Deferred work, which IS wanted, just
     not now. Only list non-goals the user actually called out. -->
- {{ NON-GOAL 1 }}
- ...

## Constraints / Requirements of the Solution

Guardrails for the implementation approach — the conditions any acceptable
solution has to satisfy.
<!-- Each item is a guardrail the user set in the hearing: what the solution
     must or must not do, what it must reuse, integrate with, or avoid. They
     bound the implementation approach without dictating it. NOT your own design
     or implementation choices, which get decided in Phases. -->
- {{ CONSTRAINT 1 }}
- ...

## Phases

Current understanding of the implementation. Later phases are a rough direction
and may change as things are learned.
<!-- A checklist of (somewhat) independent units of work, each a coherent chunk
     rather than an arbitrary slice. If possible the first phase is a
     quick-and-dirty end-to-end thin slice that stubs or hardcodes freely to get
     the feature running without breaking existing tests; later phases properly
     implement what it stubbed. Design and implementation decisions live here,
     not in Goal or Constraints. -->

- [ ] **P1: {{ PHASE 1 TITLE }}**
      {{ PHASE 1 DESCRIPTION }}
- ...

## Current position / notes

<!-- One or two lines only: where you are right now and what's next. Keep it
     pointing at the next action as the work moves. -->
- {{ CURRENT STATE }}

## Deferred work

<!-- Work identified as necessary or wanted but deliberately pushed out of this
     round — "we want this, just not now". Only items the user actually decided
     to defer. Not permanent non-goals (those go under Non-goals): if it was
     never going to be part of the work, it does not go here. -->
- {{ DEFERRED WORK 1 }}
- ...

## Appendix

### Working Principles

How to execute and update this plan across sessions.

- **Before each phase, describe the rough design approach and get a quick OK** —
  where things get added/changed at a high level. Stay high-level on purpose:
  don't lock down low-level choices in advance. Implementing the phase settles
  them naturally, and pinning them early just creates spec churn.
- **Write a sub-step todo-list only for the phase you're currently in**, and
  only after you've described and confirmed its rough approach. Never pre-write
  sub-steps for future phases — what you learn will likely invalidate them.
- **When you complete a sub-step, rewrite it in place in past tense**, folding
  in what you did, what you learned, and how you verified it in abstract terms
  (e.g. "ran acceptance tests", "ran unit tests", "tested manually via the
  CLI"). No need to cite concrete test counts. Don't append a separate "Done"
  summary. Check off the phase once all its sub-steps are.
- **When you discover a "do this later, within this work" item:** add it as a
  sub-step if it belongs to the current phase, otherwise note it in the relevant
  future phase's description.
- **When a piece of work is identified as necessary but not part of this round,
  move it to Deferred work** — wanted, just not now. If instead it will not be
  done at all, it belongs under Non-goals.
- **Keep "Current position / notes" pointing at where you are and what's next**,
  updating it as the work moves — one or two lines only.
- **Never delete a section that goes empty.** If a section has no items, or its
  items all get resolved, leave the heading and write `- (None)` under it.

### Example phases in progress

``` markdown
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
```

P1 is done: its sub-steps are rewritten in past tense and carry what/learned/how
inline. P2 is current, so it has a sub-step todo-list. P3 is still future — just a
title and a one-line direction, no sub-steps until it becomes current.
