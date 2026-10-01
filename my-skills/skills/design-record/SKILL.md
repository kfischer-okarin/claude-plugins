---
name: design-record
description: Extract the requirements and settled design decisions of the current session's work — a design interview such as grill-me, or an unstructured conversation — into a design record document, and keep it in step with the rest of the session.
disable-model-invocation: true
---

# Design Record

## Background

### Purpose

A design record keeps what was settled in a stretch of work — what the user
asked for, what was ruled out, and why — for whoever works on the project
later, human or agent, without having been in the conversation. It is good when such a reader
can tell what the user wanted, how each wish was met, what is deliberately out
of scope, and why.

The skill is invoked at the end of a stretch of work, so its conversation is the
source of the record.

### What Decisions Belong in the Design Record

Those made at the level of the system rather than of a single piece of code:
the kind a design review would discuss and a code review would not. A later
reader cannot recover them from any one place in the code. Typically they shape
one of the following:

- the architecture
- technology selection
- the data model, including how stored and derived values are defined
- security and access
- the user experience
- the developer experience, such as configuration formats or the testing
  strategy
- build, release and operations
- accepted trade-offs and limits of scope

### Terms

- **Stretch of work:** a feature, a larger change, or a round of design. Each
  record covers one stretch; records are numbered in order and not edited once a
  later one exists.

## Behavior

### Workflow

1. Draft a new record from the session's requirements and decisions, numbered
   after the existing ones, where the project keeps design documents, or in
   `docs/design/NNN-<slug>.md` if it has no convention. Extend the latest
   record instead only when the user says this session continues the latest
   record's stretch of work.
   - Mark every choice the agent made on its own with *(agent's choice)*, so
     the user can confirm or change each one in step 2.
   - Only what the user explicitly settled or agreed to in the conversation is
     a user decision. Whatever the agent filled in to make the design concrete
     is a separate decision, one of the agent's choices.
   - If code was written, a decision below the level described in What
     Decisions Belong in the Design Record that is localized to one place in
     the code becomes a short comment there instead of an entry, when it would
     not be obvious to a reader familiar with the language and framework.
2. Iterate with the user on the draft until they approve it, reviewing its
   content and confirming or changing each *(agent's choice)*. Choices the
   agent made on its own become decisions once the user confirms or changes
   them; the approved record drops the marks.
3. Send a subagent to find decisions in earlier records that the approved ones
   relate to, and relate them in the record (see Decisions).
4. If the project's agent instructions (e.g. CLAUDE.md) do not mention the
   design records yet, offer to add a pointer to them and a rule to keep them up
   to date, so later work maintains them.

### After the record is written

The record stays loaded for the rest of the session. When a later change in the
same session settles or reverses a decision, propose updating the record
accordingly.

## Output

### Document structure

```markdown
# NNN — <Title of the stretch of work>

<One or two sentences: what this stretch of work was, and when.>

## Requirements

### 1. <The requirement as a short proposition>

*Source: <initial request | added by <user> during the conversation |
<user>'s answer to a question about what the work should do>.*

#### Settled decisions

**YYYY-MM-DD — <Question?>**
<Answer, then the reasoning.>

## Open questions

- <Question, with its requirement number and what is known so far>
```

`<user>` is the name the project's documents and git history know the user by.

### Requirements

A requirement is something the user wants the stretch of work to achieve: the
*what*, not the solution. It comes from the user's initial request, from a
direction the user added during the conversation, or from the user's answer to
a question about what the work should do; its Source line says which.

- Each is a short proposition phrased with "should" ("The app should …"), or
  with "can" for a capability the user gains ("Foods can be logged without a
  chat").
- They are listed in the order they came up in the session. Requirements named
  together, as often in the initial request, are ordered so that each concept is
  introduced before a requirement relies on it.

### Decisions

A decision is a choice about *how* a requirement is met, or about what is in or
out of scope, that the user made or confirmed during the conversation. Every
decision belongs to the requirement that motivated it.

- The list under each requirement is flat and chronological.
- The question names the concern the choice settles, open enough that every
  option considered answers it.
  - It presupposes nothing that was itself a choice: "What authentication does
    the APK download need?" rather than "Are the downloads public?", "What works
    while offline?" rather than "Does the app queue entries while offline?".
  - It is a complete sentence, understandable from the design record up to that
    point without the conversation.
- The answer to a user decision stays close to the user's own words, keeping
  qualifiers such as "for now".
- The answer introduces every command, file, component or concept it creates,
  with its purpose, for a reader who does not know the final design.
- The reasoning says why this option won; constraints and facts that forced it
  belong here, and so do the alternatives not chosen where they matter.
- Who suggested an option is irrelevant: the entry records the choice and its
  reasoning only.
- The date is the day the decision was settled; for one of the agent's choices,
  the day the user confirmed or changed it.
- A decision that reverses one from an earlier record is recorded here, naming
  the record and decision it replaces.

### Open questions

An open question is a question about the requirements or the design that the
user left open in the discussion, to be decided later. The agent's own ideas for
later work are not open questions.

Omit the section when there are none.
