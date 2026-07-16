---
name: my-review
description: Review the current changes using any local repo review guidelines, then run the built-in code-review skill at high effort and present the findings. Without a PR argument also write them to .review.json; with one, post selected findings to the pull request.
disable-model-invocation: true
allowed-tools: Skill(code-review), Bash(gh:*), Bash(rm -f .review.json)
---

# My Review

The skill takes an optional argument: a pull request reference (a PR number,
`#235`, or a full PR URL). Its presence selects the output mode in step 3.

1. Look in the repository for local review guidelines (e.g. files named like
   `REVIEW*`, `*review-guidelines*`, or review notes in `CLAUDE.md` / `docs/`).
   If found, read them and keep them in mind during the review.

2. Run the built-in `code-review` skill with the `high` argument. By default,
   assume the review target is the currently checked-out branch's diff against
   the default branch.

3. Always present the findings in the conversation, ranked most-severe first —
   for each give a short label, the `file:line`, and enough detail to decide
   whether it is worth acting on.

4. Then, depending on whether a PR argument was given:

   - **No PR argument** (local review handoff): also write the review result
     into `.review.json` at the repo root, silently. First delete any existing
     `.review.json` with `rm -f .review.json` so you never have to read the old
     file before overwriting it.

   - **PR argument given** (review via PR comments): ask in prose (not via the
     AskUserQuestion tool) which findings to post as inline review comments (the
     user may pick a subset, all, or none). For each selected finding, post an
     inline comment on its `file:line`:

     - Resolve the repo and PR head SHA with `gh pr view <pr> --json
       headRefOid,url`.
     - Post with `gh api repos/{owner}/{repo}/pulls/{n}/comments` using
       `commit_id` (the head SHA), `path`, `line`, and `side=RIGHT`.
     - Begin each comment body with the fixed header line
       `🤖 Review comment by Claude Code`, followed by the finding.
