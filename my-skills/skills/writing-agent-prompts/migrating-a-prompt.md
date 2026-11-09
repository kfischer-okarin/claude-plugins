# Migrating a Prompt

Follow these steps for a large edit or for moving an unstructured prompt into
the Background, Behavior, Output format. The Author decides at every step; you
prepare the material so each decision is small.

1. **Extract the Statements.** List every Statement of the existing prompt,
   one per line, with its source location. Merge Statements that say the same
   thing and note the merge.
2. **Place the Statements** into the section hierarchy without changing their
   wording, so the Author can judge each one in its new context.
3. **The Author sorts the placed Statements.** For each Statement the Author
   decides whether to keep, compress or drop it. Propose a sorting with a
   one-line reason per item so the Author can accept or override. Where several focused Statements
   share a purpose, propose the general Statement that replaces them.
4. **Write the draft**, then have a subagent that has not seen the
   conversation judge it against [Prompt tests](prompt-tests.md), and give the
   Author the failing tests with their evidence.
5. **Iterate** on the failures with the Author until the tests pass or the
   Author accepts the remaining ones.
