---
name: rough-planning
description: Run a requirements hearing, then produce and maintain a lightweight, living plan/progress document for incremental, phase-based feature work — approved up front and revised as work proceeds, not a heavy upfront spec. Use when the user asks to plan a feature, write or update a plan or progress doc, track work across phases, or build end-to-end first and then deepen. Also use proactively when starting any non-trivial implementation that will span multiple commits.
---

# Rough Planning

A lightweight plan that doubles as a progress tracker. Hear out the requirements,
get the plan approved before implementing, then update it as you work. It is NOT
an upfront spec — you deliberately do not fix implementation details, because
they will change.

## When to use

- The user wants a plan for multi-step / multi-commit feature work.
- You are about to start non-trivial implementation and want a shared map first.
- Work will proceed end-to-end-first (get a thin slice working), then deepen.

## Step 1: Prepare the plan template

Copy the template to the plan file — `<FEATURE>_PLAN.md` in the repo root, or
wherever the user points:

```bash
cp "${CLAUDE_SKILL_DIR}/TEMPLATE.md" <FEATURE>_PLAN.md
```

You fill this file in over the next steps.

## Step 2: Requirements hearing

Before writing the plan, conduct an in-depth interview to drive out ambiguity.
Use the `AskUserQuestion` tool to explore:

- **The use case** — what is actually wanted, and why. Surface the goal and the
  background, not just the surface request.
- **The guardrails on the approach** — the conditions any acceptable solution
  must satisfy: what it must or must not do, what it must reuse, integrate with,
  or avoid. These become the Constraints / Requirements section.
- **What is wanted but not now** — work the user recognizes as needed eventually
  but deliberately defers out of this round. This becomes Deferred work.
- **What is explicitly not a goal** — work the user rules out entirely, now and
  later. This becomes Non-goals and bounds the scope.

Be thorough about exposing unclear points. Research the codebase in parallel so
your questions are concrete. Continue the interview until you judge every area is
sufficiently explored — the goal, the guardrails, and the scope boundaries clear
enough to write down. Goal, Non-goals, Constraints, and Deferred work all come
directly out of this hearing.

## Step 3: Write the plan

Fill in the copied template. The file is already structured for you, with the
scope of each section spelled out in its `<!-- -->` comment.

**Only touch the `{{ ... }}` placeholders and the `<!-- -->` comments** — replace
each placeholder with real content, and delete the comments once the section is
written. Everything else in the template is intentional plan text: the fixed
prose, the section headings, the Working Principles appendix, and the "Example
phases in progress" illustration all stay exactly as written. Do not reword,
trim, or "improve" them.

### Phasing principles

- **Each phase is a (somewhat) independent logical unit of work.** It builds on
  earlier phases, but stands on its own as a coherent chunk — not an arbitrary
  slice.
- **If possible, make the first phase a quick-and-dirty end-to-end
  implementation** of the whole feature. If applicable, precede it with a failing
  system-level test (add one, or edit an existing one to fail if the change
  invalidates current behavior). This phase should freely stub out or hardcode
  fixed values for any subsystem or moving part to get the feature running as
  fast as possible — without breaking the existing tests.
- **The following phases refine and properly implement the individual sub-parts**
  that the first phase stubbed or skipped.

### Hard rules

- **No meta-commentary about the plan itself.** Do not write "lightweight
  progress tracker", a "how we'll work" section, "(incomplete is fine)"
  parentheticals, or anything describing the document's own purpose or process.
  The plan talks about the *work*, never about itself.
- **Don't leave the user's editing reasoning in the document.** When the user
  gives feedback on the plan's wording, apply the minimal change in the doc's
  style. Don't record why they asked for it or quote the exchange.

## Step 4: Review before approval

Once the plan is written, and before you present it for approval, put it through
two adversarial reviews. Run them in parallel as subagents, and have each return
its findings rather than edit the plan:

- **Against the documentation and codebase.** This reviewer re-checks every
  factual claim in the plan — sources, names, orderings, how the current code
  behaves — against the actual project documentation and code, and flags anything
  unsupported, misattributed, or contradicted. Its job is to catch claims that
  sound right but the sources do not back.
- **Against the template.** This reviewer reads `TEMPLATE.md` and checks each
  section of the plan against that section's scope instructions (the `<!-- -->`
  comments), flagging content that belongs in a different section or breaks a
  hard rule — e.g. implementation mechanics in Goal, your own design choices in
  Constraints, a permanent non-goal filed under Deferred work, or meta-commentary
  about the plan. Pass this reviewer the path to the current session's
  transcript — the JSONL file named `${CLAUDE_SESSION_ID}.jsonl` under
  `~/.claude/projects/` — so it can verify that Goal, Constraints, Deferred work,
  and Non-goals trace back to what the user actually said in the hearing.

Apply the findings you agree with, then present the plan for approval.

## Step 5: Get approval, then work the plan

Present the plan and ask for approval. Fix what's flagged, then start
implementing, following the **Working Principles** in the plan's appendix.
When you pick up an existing plan in a later session, read that appendix first.
