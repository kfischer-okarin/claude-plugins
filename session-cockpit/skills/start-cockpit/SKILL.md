---
name: start-cockpit
description: Turns on the session cockpit, an Emacs buffer where the user answers your questions at their own pace. Use when the user asks for the cockpit, or once you have more than about half a dozen questions for the user at the same time.
allowed-tools: Bash(mise exec -C ${CLAUDE_PLUGIN_ROOT} -- ${CLAUDE_PLUGIN_ROOT}/exe/session-cockpit start *)
---

!`mise exec -C ${CLAUDE_PLUGIN_ROOT} -- ${CLAUDE_PLUGIN_ROOT}/exe/session-cockpit start ${CLAUDE_SESSION_ID}`

## Background

- The cockpit lists the questions you ask with the session-cockpit tools.
  The user answers them in any order and submits several answers at once,
  with a comment. Each submission arrives as an event of the `submissions`
  monitor.
- The user sees each question with its ID (`[q1]`), its options and the
  lines in files it points at, which are also marked in the files
  themselves.
- `/clear` turns the cockpit off: the next session starts without it.

## Behavior

- Move every question you asked the user in the chat that is still
  unanswered into the cockpit with `ask`, so the user finds all of them in
  one place. The questions listed above are in it already.
- While the cockpit is on, ask with `ask` whenever you have several
  questions for the user at once, so that none waits unnoticed in the
  transcript. Ask a single question in the chat, where the user answers it
  right away.
- When you can't go on without an answer, end your turn: the user's
  submission arrives as an event and starts the next one.
- Previews hold concrete material to compare options by, such as code or a
  layout.
- Point a question at the lines in files it is about with `anchors`.
- Keep the open questions current: update one when what you learn changes
  it, and withdraw one that no longer needs an answer, so the user never
  answers a stale question.
- Act on a submission as on the user's reply in the chat: an answer
  decides, a comment can steer anything.

## Output

- Chat messages leave out how the cockpit changes, such as which questions
  you asked, updated or withdrew: the tool calls show that already.
  - The exception: when you turned the cockpit on yourself rather than on
    the user's request, say so once, with how to open it.
- A question mentioned in the chat goes by its ID and a few words of it,
  such as "[q2] (log format)".
