# claude-plugins

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins,
published as a marketplace.

## Install

```text
/plugin marketplace add kfischer-okarin/claude-plugins
/plugin install my-skills@kfischer-okarin-plugins
```

Update later with `/plugin update my-skills@kfischer-okarin-plugins`. Releases
are rolling — the latest commit on the default branch is always the current
version.

## Plugins

### `my-skills`

A small collection of personal Claude Code skills.

<!-- markdownlint-disable MD013 -->

| Skill                   | What it does                                                                                                                                      |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `rough-planning`        | Run a requirements hearing, then produce and maintain a lightweight, living plan/progress document for phase-based work.                          |
| `my-review`             | Review the current changes using any local repo review guidelines, then run the built-in `code-review` skill at high effort and save the result.  |
| `check-review-comments` | Fetch review comments on the current PR from GitHub and triage each on importance vs. effort.                                                     |
| `write-handoff-spec`    | Interview you about a task, then produce a minimal-but-explicit spec that a later autonomous session can implement unattended.                    |
| `software-design`       | Personal software design principles and taste — tests as executable specification, domain/application layering, seam placement, module design.    |
| `doc-review`            | Review documents with four fresh-eyes subagents — contradictions, redundancy (DRY), meta bleed, and evolution bleed — and report merged findings. |
| `writing-agent-prompts` | Principles, structure and a review workflow for writing the instruction documents agents read — skills, CLAUDE.md files, system prompts.         |
| `design-record`         | Turn a stretch of work's requirements and settled design decisions into a numbered design record, reviewed with you before it is final.           |

<!-- markdownlint-enable MD013 -->

### `session-cockpit`

A per-session cockpit in Emacs: the questions Claude asks, answered at your
own pace, file annotations and a short brief of where the session stands.
Work in progress — see [`session-cockpit/PLAN.md`](session-cockpit/PLAN.md).

Requires [mise](https://mise.jdx.dev) (Ruby 4.0).

| Component                    | What it does                                                                                                             |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `session-cockpit` MCP server | Lets Claude ask the user questions and read the open ones, and keeps the session's log, taking over the user's submits.  |
| `submissions` monitor        | Delivers what the user submits from the Emacs cockpit to Claude.                                                         |
| SessionStart hook            | Keeps track of which session a Claude Code process is in, so `/clear` starts a fresh agenda.                             |
