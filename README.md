# claude-plugins

Personal [Claude Code](https://docs.claude.com/en/docs/claude-code) plugins,
published as a marketplace.

## Install

```
/plugin marketplace add kfischer-okarin/claude-plugins
/plugin install my-skills@kfischer-okarin-plugins
```

Update later with `/plugin update my-skills@kfischer-okarin-plugins`. Releases
are rolling — the latest commit on the default branch is always the current
version.

## Plugins

### `my-skills`

A small collection of personal Claude Code skills.

| Skill | What it does |
|---|---|
| `rough-planning` | Run a requirements hearing, then produce and maintain a lightweight, living plan/progress document for phase-based work. |
| `my-review` | Review the current changes using any local repo review guidelines, then run the built-in `code-review` skill at high effort and save the result. |
| `check-review-comments` | Fetch review comments on the current PR from GitHub and triage each on importance vs. effort. |
