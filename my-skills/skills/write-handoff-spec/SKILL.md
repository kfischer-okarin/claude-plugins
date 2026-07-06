---
name: write-handoff-spec
description: Interview-driven creation of a minimal-but-explicit spec for handing off work to an autonomous implementation session.
disable-model-invocation: true
---

# Write Handoff Spec

Produce a spec for an autonomous implementation session. The goal is to combine
"short enough to approve in one read" with "all guardrails, constraints, and
verification conditions stated explicitly". Do not over-specify the how — the
reader is the implementing Claude session, and explicitly marking where it is
free to decide is part of the spec.

## Process

### 1. Research before interviewing

- Understand the current state directly from the code. Map every place the
  change will ripple into: config, initialization, tests, CI workflows, docs.
- Use the project's research agents (e.g. doc-researcher) if available.
- Summarize the current state and its problems back to the user once before
  asking any questions.
- Note non-obvious pitfalls found during research (evaluation order, implicit
  defaults, hidden dependencies) — promote them to spec constraints later.
- Note the repo's house style: comment density, prose/UX copy tone, test
  granularity. Existing sparseness is a design decision. Check what the repo
  already encodes (CLAUDE.md and the working-notes file it points to, if any)
  before promoting style into the spec — the spec carries only what is
  task-specific or missing. When a durable repo preference surfaces that the
  repo doesn't record yet, add capturing it there to the change surface
  instead of restating it in future specs.

### 2. Ask only about real decision points, via AskUserQuestion

- Questions must come from **actual decision points found in research** — no
  generic questions, nothing answerable by reading the code.
- Give each question a recommended option, and explain the consequences /
  trade-offs of each option in its description.
- Take as many rounds as needed (the tool caps one call at 4 questions; batch
  related ones, and let earlier answers shape later rounds). The filter is
  altitude, not count: ask anything that changes the spec's guardrails or
  Definition of Done; never ask what only changes implementation details — that
  goes into "Left open" instead.

### 3. Draft → refine → save

- Before presenting, re-read each requirement asking "do I mean this
  exactly?" — precise wording is honored precisely and suspends the
  implementer's judgment at that spot. Rewrite mechanism-phrased requirements
  into the intent behind them unless the mechanism is the point (then say
  so), and mark illustrations as examples.
- Present the full spec draft in the conversation, along with the remaining
  small open points (1–3).
- Incorporate feedback and save to the location the user specifies.

## Spec structure

Fixed section headings; adapt the content to the task:

```markdown
# Spec: <title>

## Goals
2–4 numbered items, written as achieved end states. State the intent (why)
in a line where it isn't obvious — the implementer resolves ambiguity toward
intent, not literal wording.

## Implementation requirements
Only requirements whose satisfaction is checkable. Include pitfalls found
during research, marked with ⚠️ (use subsections if needed).

## Change surface
Table of location × change. Include out-of-scope work and the user's manual
follow-ups as explicit rows. Include the spec file itself as a row: where it
lives and its disposal (e.g. deleted before merge).

## Tests & documentation
Tests and docs to update or add.

## Verification conditions (Definition of Done)
Runnable commands, or concrete manual verification steps. When the change
removes or renames identifiers, env vars, or files, include a residual-
reference sweep (grep for the old names returns nothing). Anything outside
automated verification becomes a contract: "must be called out in the
completion report". Every claim in the completion report must point to a
verification result from the session; anything unverified is labeled as such.

## Left open
Decision points that surfaced during the interview but are deliberately
undecided — either the user explicitly wants them open, or they can't be
judged until something is running. Not an exhaustive list of freedoms:
anything the spec doesn't constrain is the implementer's call by default.
For significant decisions made in this open space, the implementer adds a
one-line decision record to the completion report; when unsure whether a
decision is significant, include it — one line is cheap.

## Working hints
Standing process preferences — stances, not rules. Start from the defaults
below, prune what doesn't apply (especially anything the repo's CLAUDE.md or
working notes already cover), and add a task-specific hint only when research
showed a real mismatch. Keep it to 3–6 one-liners.

- Match the repo's existing density in everything you write: comments, UX
  copy, docs, test scenarios. When unsure whether to add prose, don't —
  review feedback asks for less far more often than more.
- Don't add abstractions, defensive handling, or polish beyond what the
  spec requires; do the simplest thing that works well.
- Use your judgment to delegate self-contained subtasks (mechanical fan-out
  edits, test-file adaptation, doc updates) to cheaper subagent models
  (e.g. Sonnet or Opus); keep the central, highest-judgment work in your
  own context and verify delegated output against the spec before
  integrating.
- Before delivering, have a fresh-context subagent review the full diff
  against this spec and the repo's conventions.
- If the spec's assumptions turn out to be wrong (not merely
  underspecified), stop and surface it rather than improvising a scope
  change.
- When the work is done, record lessons for your future self — review
  corrections, confirmed approaches, and why they mattered — in the
  working-notes file named in the repo's CLAUDE.md (if one is set). Update
  or delete existing notes rather than duplicating; skip what the repo
  already records.
```

## Quality bar

- 1–2 pages; the user can approve it in a single read.
- Precision displaces judgment: anything stated exactly is done exactly, so
  spend exact wording only on true guardrails and state intent everywhere
  else, so judgment has a target. Wording meant as a sketch must be marked
  as an example or moved to "Left open".
- Each requirement is a checkable *what* plus constraints. Specify *how* only
  where needed to avoid a known pitfall.
- "Left open" records deliberate non-decisions, so the reader can tell
  considered-and-delegated apart from overlooked. It is not a catalog of
  freedoms.
- The user's manual work (e.g. deleting secrets) and verification deferred to
  post-merge CI are written as "include in the completion report" contracts.
- End state: the handoff is just "read `<file>` and implement autonomously", and
  the session can run to completion without mid-task questions.
