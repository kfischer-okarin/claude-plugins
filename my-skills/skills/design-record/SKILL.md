---
name: design-record
description: Extract the requirements and settled design decisions of the current session's work into a design record document.
disable-model-invocation: true
---

# Design Record

## Background

### Purpose

A design record keeps what was settled in a stretch of work — what the user
asked for, what was ruled out, and why — for whoever works on the project later,
human or agent, without having been in the conversation. It is good when such a
reader can tell what the user wanted, what was decided, what is deliberately out
of scope, and why.

The skill is invoked at the end of a stretch of work, so its conversation is the
source of the record. A session may also hold work that belongs to no stretch,
such as routine maintenance done on the way, or several unrelated stretches.

### What Decisions Belong in the Design Record

Those made at the level of the system rather than of a single piece of code: the
kind a design review would discuss and a code review would not. A later reader
cannot recover them from any one place in the code. Typically they shape one of
the following:

- the architecture
- technology selection
- the data model, including how stored and derived values are defined
- security and access
- the user experience
- the developer experience, such as configuration formats or the testing
  strategy
- build, release and operations
- limits of scope

### Terms

- **Stretch of work:** a feature, a larger change, or a round of design. Each
  record covers one stretch.

## Behavior

### Workflow

1. Find the decisions in earlier records that the session's decisions relate
   to, so the draft can refer to them; unless you already looked them up during
   the design, send a subagent for this.
2. Draft a new record from the session's requirements and decisions, numbered
   after the existing ones, where the project keeps design documents, or in
   `docs/design/NNN-<slug>.md` if it has no convention. Extend the latest record
   instead only when the user says this session continues the latest record's
   stretch of work; never edit a record once a later one exists.
   - Draft one record per stretch of work, leaving out what belongs to none.
     When it is unclear where a stretch ends, ask the user before drafting.
   - Mark every choice the agent made on its own with *(agent's choice)*, so the
     user can confirm or change each one in step 3.
   - Count as a user decision only what the user explicitly settled or agreed to
     in the conversation. Record whatever the agent filled in to make the design
     concrete as a separate decision, one of the agent's choices, where it chose
     between realistic alternatives; what it only checked, or left at a
     default, is not a decision.
   - Leave out decisions below the level described in What Decisions Belong in
     the Design Record. If such a decision sits in one place in code written in
     the session and would not be obvious to a reader familiar with the language
     and framework, add a short comment there instead.
3. Iterate with the user on the draft until they approve it, reviewing its
   content and confirming or changing each *(agent's choice)*. Choices the agent
   made on its own become decisions once the user confirms or changes them; the
   approved record drops the marks.
4. If the project's agent instructions (e.g. CLAUDE.md) do not mention the
   design records yet, offer to add a pointer to them and a rule to keep them up
   to date, so later work maintains them.

### Requirements versus decisions

When you are not sure whether something the user said is a requirement or a
decision, follow this rule:

- If it is something the user definitely wants, or needs because of a
  constraint, so that it is non-negotiable, it is a requirement: the *what*.
- If it could have been settled another way without dropping a requirement, it
  is a decision: *how* a requirement is met, or what is in or out of scope.
  - If a requirement was already stated at the level of a technical decision and
    there was never any other realistic choice, keep the requirement and omit
    the decision; list omitted decisions when you show the draft.

### After the record is written

Keep the record in mind for the rest of the session. When a later change in the
same session settles or reverses a decision, propose updating the record
accordingly: rewrite the affected entry in place, keeping the dropped option in
its reasoning where it matters.

## Output

### Document structure

```markdown
---
updated_at: YYYY-MM-DD
---

# NNN — <Title of the stretch of work>

<One or two sentences: what this stretch of work was, and when.>

## Requirements

### RNNN.1 — <The requirement in EARS form>

<The user's reason or context, if they gave one.>

## Decisions

### DNNN.1 — <The decision, stated as the change it makes>

<Why it won over the alternatives, unless the heading says it all.>
```

- `NNN` is the record's number. Entries refer to each other, and to entries of
  earlier records, by these IDs.
- `updated_at` is the date of the session that wrote the record, or that last
  extended it.

### Requirements

- They are the few goals and constraints of the user's that drove the design,
  each with what prompted it where the user said. Single tasks asked for along
  the way, conveniences added during the work, and the user's general
  preferences about how work is done are not requirements; such preferences
  are candidates for agent instruction improvements.
- Each heading is phrased in EARS form with "should" and the keywords in lower
  case: "The app should …", "When a screen loads, the app should …", "While …",
  "If …, then …", "Where …".
- They are listed in the order they came up in the session. Requirements named
  together, as often in the initial request, are ordered so that each concept is
  introduced before a requirement relies on it.

### Decisions

- They are listed chronologically, in the order they were made.
- Each heading states the decision as the change it makes, such as "The
  desktop moved to …"; it stands alone when no reasoning hides behind it. An
  entry states its own decision without restating other entries.
- The body of a user decision stays close to the user's own words, keeping
  qualifiers such as "for now".
- The body introduces a command, file, component or concept only where the
  reasoning needs it; what the code shows is left to the code. A data structure
  the decision settles, such as a table schema, is shown in its final form.
- The reasoning says why this option won over the alternatives that were
  weighed, with the constraints and facts that decided it; how the work arrived
  there is left out.
- A trade-off accepted with a decision, and what follows from it, belong in that
  decision's body rather than in entries of their own.
- Who suggested an option is irrelevant: the entry records the choice and its
  reasoning only.
