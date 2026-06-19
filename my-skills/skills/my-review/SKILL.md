---
name: my-review
description: Review the current changes using any local repo review guidelines, then run the built-in code-review skill at high effort and save the result. Use when the user asks for "my review" of a diff, branch, or changes.
disable-model-invocation: true
allowed-tools: Skill(code-review)
---

# My Review

1. Look in the repository for local review guidelines (e.g. files named like
   `REVIEW*`, `*review-guidelines*`, or review notes in `CLAUDE.md` / `docs/`).
   If found, read them and keep them in mind during the review.

2. Run the built-in `code-review` skill with the `high` argument. By default,
   assume the review target is the currently checked-out branch's diff against
   the default branch.

3. Write the review result into `.review.json` at the repo root.
