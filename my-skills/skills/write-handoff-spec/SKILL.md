---
name: write-handoff-spec
description: Interview-driven creation of a minimal-but-explicit spec for handing off work to an autonomous implementation session.
disable-model-invocation: true
---

# Write Handoff Spec

Produce a spec for an autonomous implementation session done by an intelligent
implementer with good judgement. It should contain enough background information
to understand the request and high-level directions from the user ordering the
implementation while leaving most of the actual details to the implementer's
judgement.

## Process

### 1. Interview the user

The user will call this skill with a request and you are supposed to find out
the exact nature of that request including questions like:

- Why is this change necessary?
- What kind of goal state needs to be reached and how can it be verified?
- Are there external constraints to the possible implementation methods?
- Does the user have preferences about the implementation method?

For this you will need to do an in-depth interview with the user using the
`AskUserQuestion` tool. To be able to ask meaningful questions you need to find
out the current state of the project so explore the codebase and documentation
until you think you have a good enough idea of all parts that are relevant to
the request. Then conduct the interview. 

You might be tempted to completely map out the one real correct implementation
approach already at this point in time. Do _NOT_ do this. This is not the time
for that and it will only overwhelm the user with implementation details, which
they do care about but not in advance in a hypothetical vacuum - code review is
the time for that.

Make sure to know enough about the problem that the user would not be
dissatisfied. Trust that the implementer will be smart enough to interpret the
this spec and find out the details during implementation.

### 2. Write the spec

It should be short enough that the user can easily review it but contain enough
detail to get across all important requirements of the task at hand.

You are free to format the spec as you like and just store it in the repository
root as `<FEATURE_NAME>_SPEC.md`. Just make sure that the implementor has a
clear (preferably test-driven) way to know they are done.

The final goal should be that you can just hand the implementor the spec and
tell them to go and implement it and that together with the repository contents
and their own judgement will be enough to produce a result that the user will be
very satisfied with.
