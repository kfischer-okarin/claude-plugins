# claude-plugins

This repository contains Claude Code plugins and skills published through a
marketplace (`.claude-plugin/marketplace.json`).

## Before working on plugins or skills

Before you create or edit any plugin manifest, skill, or their frontmatter, you
MUST look up the latest official metadata and frontmatter formats from the
Claude Code documentation. The schemas for `plugin.json`, `marketplace.json`,
and `SKILL.md` frontmatter change over time — do not rely on memory or on the
existing files in this repo as the source of truth.

- Fetch the current Claude Code plugin and skill documentation (e.g. via
  WebFetch/WebSearch) and confirm the required and optional fields before
  writing.
- Verify field names, allowed values, and the overall structure against that
  documentation, then apply them.

## Keep the README in sync

Whenever you add, remove, or rename a plugin component (skill, agent, hook,
etc.), update `README.md` to match — the per-plugin component tables there are
the user-facing list and must stay accurate.
