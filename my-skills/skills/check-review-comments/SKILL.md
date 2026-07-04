---
name: check-review-comments
description: Fetch review comments on the current PR from GitHub, then judge each on importance vs. effort.
disable-model-invocation: true
argument-hint: "[pr-number]"
allowed-tools: Bash(gh *), Bash(${CLAUDE_SKILL_DIR}/scripts/gather-comments.sh *)
---

# Check Review Comments

## Gather every source

Run the bundled script to collect all feedback sources into one labeled
stream — the local `.review.json` (produced by the `my-review` skill), inline
review comments, review summaries, and conversation (issue) comments. Pass the
PR number from `$ARGUMENTS` if given; otherwise it defaults to the current
branch's PR.

```bash
${CLAUDE_SKILL_DIR}/scripts/gather-comments.sh $ARGUMENTS
```

## Judge and report

List every comment from both sources with its file, line, author, and body.
For each, give a quick verdict on whether it's worth applying — weighing
**importance** (does it fix a real bug, correctness, or clarity issue?) against
**effort** (how much work to address). Flag the high-importance / low-effort
ones to do first, and call out any safe to skip.
