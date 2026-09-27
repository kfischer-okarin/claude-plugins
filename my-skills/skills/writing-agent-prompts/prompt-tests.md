# Prompt Tests

A checklist for judging a Prompt as a whole. Give it to a subagent that has
not seen the conversation, together with the Prompt under test and, for the
coverage test, the sources the Prompt was written from. The judge answers each
test with pass or fail and quotes the Statements as evidence.

## Structure

1. **No contradictions:** no two Statements prescribe different behavior for
   the same situation.
2. **No duplication:** no idea appears in more than one place, including the
   same idea restated as a goal, a problem and a rule.
3. **One home per Statement:** every Statement sits in exactly one section whose
   heading covers it; nothing would fit equally well elsewhere.
4. **Background, Behavior and Output stay separate:** Background contains no
   instructions, Behavior nothing about output, Output nothing about process.
5. **General first:** within each section, general Statements come before
   special cases.
6. **Situation-specific material is linked out:** nothing in the Prompt applies
   only to some Tasks of the Job unless it is small; every linked document
   says what it contains and when to open it.

## Content

7. **Not deducible:** every Statement tells the Agent something it could not
   have worked out from its training data or environment.
8. **General:** every Statement holds in every Task the Prompt loads in; none
   reads like a patch for one past incident.
9. **Reason present:** every instruction has its reason stated with it or
   derivable from Background. List instructions without one.
10. **What over how:** no Statement prescribes a method where stating the
    outcome would suffice.
11. **Decidable conditions:** wherever a Statement branches ("when X, do Y"),
    the Agent can decide X from what it can observe.

## Ambiguity

12. **No implicit knowledge:** every term of art is defined or self-evident to
    someone who has never seen the Author's environment. List unclear terms.
13. **Terms hygiene:** every defined term is used; every used term of art is
    defined.

## Minimality

14. **No filler:** no sentence whose removal loses no information: rhetoric,
    hedging, motivation, restatement. List removable sentences.
15. **Shortest form:** could the Prompt be shorter without losing a
    decision-relevant fact? Say where.

## Coverage (after a migration)

16. **Nothing essential lost:** list principles from the sources absent from
    the Prompt, and for each say whether the Agent could go wrong without it.

## Scenarios

Write three to six concrete situations from the core branches of the Job. For
each, the judge answers: what does the Prompt tell the Agent to do, and did
you have to guess? A guess marks a product decision the Author has not made.
