---
name: rough-planning
description: Run a requirements hearing, then produce and maintain a lightweight, living plan/progress document for incremental, phase-based feature work — approved up front and updated as you go, not a heavy upfront spec. Use when the user asks to plan a feature, write a plan or progress doc, track work across phases, or work end-to-end-first then deepen. Also use when starting any non-trivial implementation that will span multiple commits.
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

Write the file as `<FEATURE>_PLAN.md` (or wherever the user points). Start from
`TEMPLATE.md` in this skill directory — `{{ ... }}` marks what you replace;
everything else is fixed document text. The template ends with a **Working
Principles** appendix; keep it in the plan so the principles for executing and
updating the plan travel with the file into later sessions.

## Step 1: Requirements hearing

Before writing the plan, drive out ambiguity. Use the `AskUserQuestion` tool to
ask about:

- **The use case** — what is actually wanted, and why. Surface the goal and the
  background, not just the surface request.
- **Implementation constraints** — what the solution must or must not do, what it
  must reuse, integrate with, or avoid.

Be thorough about exposing unclear points. Research the codebase in parallel so
your questions are concrete. Keep asking until the goal and the constraints are
clear enough to write down. The Goal and the Constraints/Requirements section of
the plan come directly out of this hearing.

## Document structure

See `TEMPLATE.md` for the skeleton.

1. **Title** — just the feature name. No subtitle describing the document.
2. **Goal** — WHAT and WHY, as prose. The current problem, why it's worth
   changing, what the change enables. No implementation details here.
3. **Constraints / Requirements of the Solution** — a subsection under Goal.
   The constraints and requirements on the implementation approach, each sourced
   from what the user said in the hearing.
4. **Phases** — the current understanding of the implementation, as a checklist.
   Each phase has a short description; the phase you're currently in also carries
   a todo-list of its sub-steps (you add those once you start it — see Working
   cadence). This is a TODO list you maintain, not a fixed schedule.
5. **Current position / notes** — one or two lines: where you are, what's next.
6. **Out of scope** — things the user clearly identified as out of scope for this
   work.

## Phasing principles

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

## Hard rules

- **No meta-commentary about the plan itself.** Do not write "lightweight
  progress tracker", a "how we'll work" section, "(incomplete is fine)"
  parentheticals, or anything describing the document's own purpose or process.
  The plan talks about the *work*, never about itself.
- **Don't leave the user's editing reasoning in the document.** When the user
  gives feedback on the plan's wording, apply the minimal change in the doc's
  style. Don't record why they asked for it or quote the exchange.

## Executing the plan

The principles for working through and updating the plan live in the **Working
Principles** appendix of `TEMPLATE.md`, so they stay with the plan across
sessions. Follow them when implementing — and when you pick up an existing plan,
read its appendix first.
