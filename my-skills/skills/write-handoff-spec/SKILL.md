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

- Present the full spec draft in the conversation, along with the remaining
  small open points (1–3).
- Incorporate feedback and save to the location the user specifies.

## Spec structure

Fixed section headings; adapt the content to the task:

```markdown
# Spec: <title>

## Goals
2–4 numbered items, written as achieved end states.

## Implementation requirements
Only requirements whose satisfaction is checkable. Include pitfalls found
during research, marked with ⚠️ (use subsections if needed).

## Change surface
Table of location × change. Include out-of-scope work and the user's manual
follow-ups as explicit rows.

## Tests & documentation
Tests and docs to update or add.

## Verification conditions (Definition of Done)
Runnable commands, or concrete manual verification steps. Anything outside
automated verification becomes a contract: "must be called out in the
completion report".

## Left open
Decision points that surfaced during the interview but are deliberately
undecided — either the user explicitly wants them open, or they can't be
judged until something is running. Not an exhaustive list of freedoms:
anything the spec doesn't constrain is the implementer's call by default.
For significant decisions made in this open space, the implementer adds a
one-line decision record to the completion report; when unsure whether a
decision is significant, include it — one line is cheap.
```

## Quality bar

- 1–2 pages; the user can approve it in a single read.
- Each requirement is a checkable *what* plus constraints. Specify *how* only
  where needed to avoid a known pitfall.
- "Left open" records deliberate non-decisions, so the reader can tell
  considered-and-delegated apart from overlooked. It is not a catalog of
  freedoms.
- The user's manual work (e.g. deleting secrets) and verification deferred to
  post-merge CI are written as "include in the completion report" contracts.
- End state: the handoff is just "read `<file>` and implement autonomously", and
  the session can run to completion without mid-task questions.
