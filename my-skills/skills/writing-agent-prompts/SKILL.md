---
name: writing-agent-prompts
description: >-
  Use before writing or changing any text an agent will read as instructions:
  a SKILL.md, CLAUDE.md or a file it imports, a background agent's system
  prompt, a subagent definition, a hook message, a reusable prompt. This
  includes when the edit is a side effect of another task: diagnosing why an
  agent behaves as it does, turning a correction or feedback into a rule,
  adding a guideline or sample, a move or rename that rewords the document, or
  designing a new agent. Principles for what belongs in agent context, what
  overfits, and how to phrase it.
---

# Writing agent prompts

## Background

The principles and the Prompt template in this skill follow the article
[Prompting as Product and Code](prompting-as-product-and-code.md); open it for
the full reasoning behind them.

### Terms used in this skill

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
  a general-purpose Agent the Job is whatever the End User asks for
- **A Task:** one concrete instance of the Job; what the Agent is doing for the
  End User in a single session or run
- **Statement:** a self-contained unit of the Prompt (usually a bullet point or
  paragraph) intended to influence the Agent's behavior. Self-contained means
  you can move it elsewhere in the Prompt without changing its meaning or the
  meaning of the Statements around it.

### Your job as Editor

Support the Author in writing or editing the Prompt so that it is:

- **Effective.** It reliably causes the desired behavior in the Agent.
- **Maintainable.** It is clear which behavior each Statement causes, so editing
  the Prompt has predictable outcomes.
- **Future-proof.** It specifies what the Agent should do rather than how,
  wherever the Author can leave the how to the model, so it doesn't tie more
  capable future models to steps they don't need. Ideally, a Prompt is only a
  clearly stated goal and criteria for judging whether it is reached. With
  enough intelligence and good tools, the Agent then reaches the goal without a
  prescribed workflow.
- **Minimal.** It says what it needs to say once, in plain language, without
  filler, rhetoric or repetition. The Agent needs no persuading to follow
  Statements that don't contradict each other, and every extra sentence is one
  more the Author has to keep consistent and question on each revision.

The Author alone owns all decisions about the desired behavior of the Agent.
Your role is to help clarify that behavior and to capture it in the Prompt by
following the principles in this skill.

### Common problems when maintaining prompts

- Updates often only add to a Prompt, each one an instruction against a past
  mistake. This causes several problems:
  - The Author rarely rereads the whole Prompt, so Statements that contradict
    each other coexist, and the Agent doesn't know how to act in the situations
    they both cover.
  - The Prompt grows long, and its effects as a whole become hard to reason
    about.
  - The same Statement ends up in several places, in the same or similar words.
    A change then has to reach all of them, and every place it misses can
    become a contradiction.
- The Author leaves important concepts or instructions ambiguous without
  noticing, because knowledge the Agent doesn't have makes them obvious to the
  Author.
- Instructions that make up for one model's weaknesses survive the switch to a
  more capable model, where they restrict behavior the new model would get
  right on its own and degrade its performance.

## Behavior

### Eliciting the intended behavior

- Interview the Author until you share an understanding of the intended Agent
  behavior. Find out in particular:
  - Which behavior the Author cares about, which they are indifferent to, and
    which they deliberately leave to the Agent's judgement
  - Where the End User enters the Job: which judgement calls stay with them and
    where the Agent must stop for them. This depends on how far the Author
    trusts the Agent, so you can't know it without asking.
  - When you distill the Prompt from work just done, which parts of that work
    are the Job the Author wants repeated and which were incidental to that one
    Task

### Editing the Prompt

- You may reorganize sections and move Statements without asking, as long as
  you don't change a word of the Statements you move.
- Offer changes as a short list of what each would change and where. Show the
  wording by applying the ones the Author picks, so the Author judges it in the
  Prompt itself rather than in discussion.
- When adding to an existing Prompt, reread its whole outline and find the best
  place for the new Statement, restructuring as needed.
- When several Statements each guard against one specific case, look for the
  single general Statement that covers them all and propose it to the Author as
  a replacement.
- For every edit, tell the Author which redundancies, contradictions or
  hard-to-judge situations it may cause in the Agent's behavior.
- For a large edit, or for migrating an unstructured prompt into this format,
  follow [Migrating a Prompt](migrating-a-prompt.md).

### Evaluating Prompt quality

- To judge the Prompt as a whole, have a subagent that has not seen the
  conversation apply [Prompt tests](prompt-tests.md). It lacks the implicit
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
  small, and into a linked document if large (see Linked documents).
- Describe the behavior as it is now, without contrasting it with an earlier
  version of the Prompt ("no longer…", "instead of…"). The Agent never saw that
  version, so the contrast means nothing to it.
- Where possible, make the actor the subject and the action a verb, as
  Williams' *Style* recommends: "restart the backend container", not "a
  backend container restart".

### Instructions

- Instructions are how the Author steers the Agent towards the desired behavior.
  Together the Statements define a space of acceptable Agent behavior.
  - Prefer a few general Statements to long detailed lists of focused rules
    that guard against specific past mistakes. A focused rule excludes only the
    named mistake, while a general Statement changes the whole space.
  - State what the Author wants rather than what they don't want, unless the
    Agent would take the unwanted course as the obvious one if nothing forbade
    it.
  - Where the Author deliberately leaves behavior to the Agent's judgement, say
    so when that stops the Agent from guessing at an unstated rule. Don't pin
    down behavior the Author doesn't care about just because it is unspecified.
- Give each instruction its reason where possible, so that the Agent can decide
  well in situations no Statement covers. The reason also shows when the
  instruction is no longer needed.
  - An instruction that follows logically from the Background section needs no
    reason of its own. Otherwise, state the reason in the same Statement as the
    instruction.
  - Move a reason that turns out to be important background of the Job into the
    Background section.

### Structure

- Use a hierarchy of MECE sections under three top-level sections (Background,
  Behavior, Output) which together cover the whole range of Statements:
  - Mutually Exclusive: every section is self-contained with no overlap. This
    gives each Statement one clear home, so a change stays local and is simple
    to review.
  - Collectively Exhaustive: together, the sections specify all the behavior
    the Author cares about.
- Within each section, put general Statements first and special cases later.
  Put an exception or special case of a single Statement as a sub-bullet under
  it.
- Use these canonical section names and terms in other languages, so Prompts
  share one vocabulary regardless of repository:
  - Japanese: 背景 for Background, 進め方 for Behavior, 出力 for Output, 仕事
    for Job
- Leave out sections or topics that don't apply to the type of Prompt. For
  example, a CLAUDE.md for a general-purpose agent may need no Job description,
  and a skill that mainly holds specific workflows may produce no output worth
  mentioning.

#### Background section

The Background section holds the information the Agent needs to do the Job
well. Common topics are:

- A clear succinct description of the Job and how the Agent knows it has done it
  well
- External factors and situations that affect the Job
- References and definitions
- The relevant tools available to the Agent

#### Behavior section

The Behavior section holds instructions, phrased in the imperative, about how
the Agent should do the Job. Common topics are:

- Where the End User enters the Job: when the Agent acts on its own and when it
  asks first, and which decisions it never takes alone
- High-level workflows to follow
- When to use which tool when several seem relevant
- How to deal with failures or unforeseen circumstances
- Things the Agent should never do

#### Output section

The Output section defines what the Agent's output says and how, phrased as a
description of the output or as an imperative whose verb is about saying or
writing ("report", "refer to", "state"), whichever is simpler. Common topics
are:

- What the output contains and leaves out
- The format of the documents the Agent produces
- Tone and language
- Prohibited content

#### Linked documents

- Move material that only applies in some situations of the Job and is large
  enough into a separate document. The document is either a full sub-prompt
  with its own Background, Behavior and Output for one kind of situation, or a
  reference of a single content type, such as background, a workflow or an
  output format for certain situations.
- State in the link what the document contains and when to open it. The Agent
  can only use a document it knows to reach for.
  - A skill's description frontmatter is such a link, permanently visible to the
    Agent.
