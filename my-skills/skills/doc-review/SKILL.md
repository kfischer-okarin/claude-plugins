---
name: doc-review
description: Review a document with three fresh-eyes subagents — contradictions, redundancy (DRY), and meta bleed. Reports findings only; the caller applies fixes with judgment.
disable-model-invocation: true
---

# Doc Review

Review the documents the user names or that are clearly the subject of the
current conversation. Work out what kind each one is — a system prompt, a
README, a skill, a design note — from the conversation or the file itself.

Launch the four auditors below **in parallel**, as general-purpose subagents
with no conversation context beyond their prompt. One auditor per dimension,
each covering every document under review: contradictions and repetitions
between documents show up only to an auditor that reads them together, and
those are among the findings worth most.

Each gets the absolute paths, what kind each document is, and an instruction to
edit nothing. Their power comes from freshness: do not brief them on the
documents' history, on which parts are new, or on what you expect them to find.

## 1. Contradiction auditor

Audit the documents for internal contradictions and tensions:

- Pairs of statements that directly contradict each other.
- Pairs that conflict in practice: a plausible concrete situation where
  following one rule means violating the other, with no way given to decide.
- Statements contradicted by an example the document shows (examples are
  normative — check the rules against what the examples actually do).
- Undefined or shifting terms: a word used with two different meanings in
  different sections.

When the documents describe a system whose source is at hand, a claim that
contradicts the code it describes is a contradiction too.

For each finding: quote both passages with approximate line references,
explain the conflict in 1–3 sentences, and rate it real vs. cosmetic. Only
genuine logical conflicts — no stylistic issues, no "I'd have written it
differently".

## 2. DRY auditor

Audit the documents for redundancy:

- The same rule or fact stated in more than one place — quote each occurrence.
- Partial overlaps: two passages covering parts of the same ground so a reader
  must merge them mentally, or one a weaker restatement of the other.
- Sentences adding nothing beyond an adjacent sentence or the section heading.

For each finding: say which occurrence to keep as the canonical home and why,
and mark repetitions that might be deliberate emphasis worth keeping. Order by
how much text the fix would save. Where the documents have different audiences,
restatement across them can be justified — say when it is, because each
audience needs a complete account from the document it actually opens.

## 3. Meta-bleed auditor

Find passages where a document talks about itself instead of its subject
matter — authoring reasoning that leaked in:

- Sentences explaining why a rule is written the way it is (design rationale),
  as opposed to why the rule holds in the domain.
- Commentary on what another part of the document does, doesn't do, or fails
  to catch.
- Sentences addressed to someone editing or evaluating the document rather
  than to its actual reader.
- Self-description of the document's structure beyond plain navigation.

Legitimate and not to be reported: plain navigation ("see section Y"),
self-reference used as an operative rule ("anything this document settles
needs no confirmation"), and statements about the task's own artifacts when
those are the subject matter. For each finding: quote the passage, categorize
it, explain in one sentence why it is meta, suggest the minimal fix, and rate
it clear vs. borderline.


## Presenting the results

Merge the reports: findings ordered by severity, overlaps between auditors
deduped, and your own verdict on each — accept, reject with the reason, or
needs-their-call.

Confirm each finding in the file before accepting it — a finding counts once
you can point at the passage it describes. Auditors read freshly, so they
sometimes misjudge scope or quote loosely. Reading around a confirmed finding
often turns up the instances it missed.

Weigh findings by how much of the document is actually in scope to change. A
document that was edited rather than written will collect most of its findings
in the parts nobody touched. Say which is which, and separate the decisions:
correcting new material is the caller's to make, while deleting a stretch of
old material is the user's.

Do not edit the documents unless asked; the findings are the deliverable.
