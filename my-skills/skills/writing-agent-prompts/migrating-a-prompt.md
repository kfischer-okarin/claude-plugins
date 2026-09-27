# Migrating a Prompt

Workflow for a large edit or for moving an unstructured prompt into the
Background, Behavior, Output format. The Author decides at every step; you
prepare the material so each decision is small.

1. **Extract the Statements.** List every Statement of the existing prompt,
   one per line, with its source location. Merge Statements that say the same
   thing and note the merge.
2. **Author sorts the list.** For each Statement the Author decides: keep,
   compress, drop. Propose a sorting with a one-line reason per item so the
   Author can accept or override.
3. **Place the kept Statements** into the section hierarchy. Where several
   focused Statements share a purpose, propose the general Statement that
   replaces them.
4. **Write the draft**, then judge it against [Prompt Tests](prompt-tests.md)
   with a subagent that has not seen the conversation, and give the Author the
   failing tests with their evidence.
5. **Iterate** on the failures with the Author until the tests pass or the
   Author accepts the remaining ones.
