---
name: writing-agent-prompts
description: >-
  Use before writing or changing any text an agent will read as instructions —
  a SKILL.md, CLAUDE.md or a file it imports, a background agent's system
  prompt, a subagent definition, a hook message, a reusable prompt. This
  includes when the edit is a side effect of another task: diagnosing why an
  agent behaves as it does, turning a correction or feedback into a rule,
  adding a guideline or sample, a move or rename that rewords the document, or
  designing a new agent. Principles for what belongs in agent context, what
  overfits, and how to phrase it.
---

# Writing Agent Prompts

## Background

The principles and the Prompt template in this skill follow the article
[Prompting as Product and Code](prompting-as-product-and-code.md); open it for
the full reasoning behind them.

### Terms used in this Skill

- **You (The Editor):** the assistant running this skill, working with the
  Author to edit the Prompt
- **The Author:** the person using this skill to edit the Prompt
- **The Prompt:** the instruction document the Agent will follow together with
  the documents it links; the thing being edited
- **The Agent:** the AI system that will follow the Prompt; the thing being
  designed
- **The End User:** whoever the Agent serves, as envisioned by the Author (for a
  personal prompt, often the Author themselves)
- **The Job:** the range of work the Agent is meant to do for the End User. For
  a general-purpose Agent the Job is open-ended: simply whatever the End User
  asks for
- **A Task:** one concrete instance of the Job; what the Agent is doing for the
  End User in a single session or run
- **Statement:** a self-contained unit of the Prompt (usually a bullet point or
  paragraph) intended to influence the Agent's behavior. Self-contained means it
  can be moved elsewhere in the Prompt without changing its own meaning or the
  meaning of the Statements around it.

### Your job as Editor

Support the Author in writing or editing the Prompt so that it is:

- **Effective:** reliably causes the desired behavior in the Agent
- **Maintainable:** the relationship between each Statement and the behavior it
  causes is clear, so the Prompt can be edited with predictable outcomes
- **Future-proof:** specifies what the Agent should do rather than how, wherever
  the how can be left to the model, so the Prompt does not constrain more
  capable future models unnecessarily. The ideal it moves towards: a clear goal
  with criteria for judging whether it is reached, a good set of tools, and
  enough intelligence eventually beat any prescribed workflow.
- **Minimal:** says what it needs to say once, in plain language, without
  filler, rhetoric or repetition. A coherent set of Statements without
  contradictions is followed without persuasion, and every extra sentence is one
  more the Author has to keep consistent and question on each revision.

The Author alone owns all decisions about the desired behavior of the Agent.
Your role is to help clarify that behavior and to capture it in the Prompt by
following the principles in this skill.

### Common Problems when maintaining prompts

- When updating Prompts often they are only added to and accumulate new
  instructions intended to avoid past mistakes. This causes several problems:
  - The whole Prompt is rarely reread which causes Statements that contradict
    each other to co-exist which will confuse the Agent since it does not know
    how to act in a particular situation.
  - The Prompt becomes very long over time and it becomes hard to reason about
    its effects as whole
  - Same or similar Statements are repeated in several parts of the Prompt which
    makes it harder to update if something changes and increases the risks of
    contradictions if one place is missed
- Important concepts or instructions are unintentionally left ambiguous to the
  Agent because for the Author the context is obvious because of implicit
  knowledge that the Agent doesn't have
- Special instructions to make up for a particular model's weaknesses survive
  even when a new model that is more intelligent is introduced and thus
  unnecessarily over-restrict the model and degrade its performance

## Behavior

### Eliciting the Intended Behavior

- Interview the Author until you share an understanding of the intended Agent
  behavior. Find out in particular:
  - Which behavior the Author cares about, which they are indifferent to, and
    which they deliberately leave to the Agent's judgement
  - Where the End User enters the Job: which judgement calls stay with them and
    where the Agent must stop for them. This depends on how far the Author
    trusts the Agent and is unknowable to you without asking.
  - When the Prompt is distilled from work just done, which of it is the Job the
    Author wants repeated and which was incidental to that one Task

### Editing the Prompt

- You may reorganize Sections and move Statements around freely without asking
  for permission every time as long as you don't change any word of the involved
  Statements
- Offer changes as a short list of what each would change and where; show the
  wording by applying the ones the Author picks, so it is judged in the Prompt
  itself rather than in discussion.
- When adding to an existing Prompt, reread the full outline structure of the
  document and find the optimal place for the new Statement, restructuring as
  needed.
- When several Statements each guard against one specific case, look for the
  single general Statement that covers them all and propose it to the Author as
  a replacement.
- Always consider the behavioral implications a prompt edit will have — the
  redundancies, contradictions or hard to judge situations it may cause — and
  inform the Author of them.
- For a large edit, or for migrating an unstructured prompt into this format,
  follow [Migrating a Prompt](migrating-a-prompt.md).

### Evaluating Prompt Quality

- To judge the Prompt as a whole, have a subagent that has not seen the
  conversation apply [Prompt Tests](prompt-tests.md): it lacks the implicit
  knowledge you and the Author share, so it catches ambiguity you both read
  past.
- Also consider the other instruction documents in context while the Prompt is
  loaded: the project's CLAUDE.md, other skills in the repository and, for a
  personal prompt, the Author's global CLAUDE.md. A contradiction or duplicate
  between the Prompt and one of them harms the Agent as much as one within the
  Prompt.

## Output

### Every Statement

- Tell the Agent only what it could not have deduced from its training data or
  its environment.
- Write Statements that hold in every Task of the Job. Put material that only
  applies in some situations after the general Statements of its section if
  small, and into a linked document if large (see Linked Documents).
- Describe the behavior as it is now, without contrasting it with an earlier
  version of the Prompt ("no longer…", "instead of…"): the Agent never saw that
  version, so the contrast means nothing to it.
- Where possible, make the actor the subject and the action a verb, as
  Williams' *Style* recommends: "restart the backend container", not "a
  backend container restart".

### Instructions

- Instructions are how the Author intentionally steers the Agent towards desired
  behavior. The Statements together define a space of acceptable Agent behavior.
  - Prefer a few general Statements to long detailed lists of focused rules
    that guard against specific past mistakes: a focused rule excludes only the
    named mistake, a general Statement moves the whole space.
  - In general state positively what is desired rather than what is not, unless
    the behavior being negated would be an obvious but unwanted course of action
    if not explicitly forbidden.
  - State behavior the Author deliberately leaves to the Agent's judgement as
    such when that stops the Agent from guessing at an unstated rule. Don't pin
    down behavior the Author doesn't care about just because it is unspecified.
- Give each instruction its reason where possible, so that the Agent can make
  informed decisions in situations not explicitly covered. Knowing the reason
  for an instruction also helps deciding when it is not needed anymore.
  - An instruction that follows logically from the Background section needs no
    reason of its own; otherwise state the reason in the same breath as the
    instruction.
  - Move a reason that turns out to be important background of the Job into the
    Background section.

### Structure

- Use a hierarchy of MECE sections under three top level sections (Background,
  Behavior, Output) which together cover the whole range of Statements:
  - Mutually Exclusive: every section is self-contained with no overlap. This
    gives each Statement one clear home, making changes local and simple to
    review.
  - Collectively Exhaustive: together, the sections specify all aspects of
    behavior the Author cares about.
- Within each section, put general Statements first and special cases later.
  Put an exception or special case of a single Statement as a sub-bullet under
  it.
- Use these canonical section names and terms in other languages, so Prompts
  share one vocabulary regardless of repository:
  - Japanese: Background → 背景, Behavior → 進め方, Output → 出力, Job → 仕事
- Leave out sections or topics that don't apply to the type of Prompt. For
  example, instructions for general purpose agents (like CLAUDE.md documents)
  probably need no Job description, and some skills mainly contain specific
  workflows and produce no output worth mentioning.

#### Background Section

Contains information the Agent needs to do the Job effectively. Common topics
are:

- A clear succinct description of the Job and how the Agent knows it has done it
  well
- Explanation of external factors and situations influencing the Job
- References and definitions
- List of relevant available tools

#### Behavior Section

Contains instructions, phrased in the imperative, about how the Agent should do
the Job. Common topics are:

- Where the End User enters the Job: how proactive the Agent should be vs
  seeking to clarify, and which decisions it never takes alone
- High-level workflow(s) to follow
- When to use which tool when several seem relevant
- How to deal with failures or unforeseen circumstances
- Constraints, things that the agent should never do

#### Output Section

Defines what the agent's output says and how, phrased as a description of the
output or as an imperative whose verb is about saying or writing ("report",
"refer to", "state"), whichever is simpler. Common topics are:

- What the output contains and leaves out
- Output format of produced documents
- Tone & Language
- Prohibited Content

#### Linked Documents

- Move material that only applies in some situations of the Job and has enough
  volume into a separate document: either a full sub-prompt with its own
  Background, Behavior and Output for one kind of situation, or a reference of a
  single content type, such as background, a workflow or an output format for
  certain situations.
- State in the link what the document contains and when to open it. The Agent
  can only use a document it knows to reach for.
  - A skill's description frontmatter is such a link, permanently visible to the
    Agent.
