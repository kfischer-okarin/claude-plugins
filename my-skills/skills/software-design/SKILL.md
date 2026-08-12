---
name: software-design
description: The user's personal software design principles and taste — test design, domain/application layering, seam placement, module design. ALWAYS load this skill in plan mode when planning implementation work. Also load BEFORE writing or reviewing code, writing or restructuring tests, deciding what to test or mock, placing dependency injection, designing modules or interfaces, or refactoring — not only when the user says "design".
---

# Software Design

The design principles and preferences that make up good — easy to understand
and easy to change — software design in Kevin Fischer's eyes. These are
personal preferences: a description of his taste.

The core conviction: a test suite that doubles as a human-readable
specification of the system brings you halfway to an elegant and
maintainable system. The other half is correctly distinguishing essential
from accidental complexity — keeping the two separated in the source code,
and treating each with the distinct tactics it needs.

## Tests Are a Human-Readable Executable Specification

The test suite is a comprehensible, minimal, focused document about the
system's behavior: read top to bottom, it gives a complete picture of the
jobs the system does — and nothing else. Accordingly, the trigger for a new
test is new behavior — "the system should do X" — never code structure.

Writing a test means pinning down a fact about the system. Pins are what
make everything else safe — pinned behavior can be reshaped fearlessly — but
every pin also has a cost: the more is pinned, the harder the system becomes
to move. So be intentional about every pin: distinguish the classes, modules
and functions that represent important domain concepts or use cases from the
incidental ones used for plumbing. The former are worth pinning; the latter
are implementation details that must stay malleable without breaking any
tests. Just because something is public on the language level does not mean
it is a contract that needs to be kept.

The specification character reaches down every level: a test file covers one
major part or topic of the system, and a single test case states one fact
about it. Both must be comprehensible on their own — the file without
consulting other files, the case without consulting helper function
implementations.

Practical implications at the code level:

- Every value the expected outcome depends on is visible inside the test
  case. An assertion must never rest on an implicit default of the test
  helpers.
- Helpers compress noise, never meaning. A helper should remove syntactic
  clutter and express common setup or assertion logic in a succinct,
  domain-relevant phrase, so that the test as a whole reads smoothly — never
  silently supply a value the assertion depends on.
- The interface of a test helper — which parameters stay tunable, what it
  hides — shapes the readability of the whole file more than almost anything
  else. Design it with the same care as a production API.
- Structural DRY (see below) carries little weight in tests. Duplicated
  setup that keeps each case self-contained beats a clever shared helper
  that must be inspected.

Influences:

- Behavior-Driven Development
- Code That Fits in Your Head

## Two Layers: Domain Language and Application Code

Every system has two parts, and keeping them distinct is the core of good
design:

- The **domain model** is the language of the system. It expresses the
  problem *space* — deliberately somewhat more generic than what the system
  happens to do right now. It is a product whose customer is the developer:
  a vocabulary powerful enough to make the day-to-day work of writing
  application logic easy — in the spirit of Domain-Driven Design, built from
  the real, precise terms of the project's domain itself, as value objects
  rather than loose primitives.
- The **application code** builds the concrete workflows out of that
  vocabulary. It is allowed to be plainly procedural; its job is to read as
  a clear composition of domain concepts, not to be clever.

The test that the layering is right: when requirements change, the new use
case is written by restructuring application code, and the domain layer
barely moves.

Influences:

- Domain-Driven Design
- Hexagonal Architecture
- A Philosophy of Software Design

## Seams: Minimal Facades Injected at System Boundaries

The core of the system holds the domain and application logic, pure and
fully specified in its business-relevant external behavior. A thin edge
connects it to the real world: adapters that talk to the external systems,
and the setup code that wires them into the core before the domain logic
takes over — a main function, a web framework's request handling, whatever
the runtime offers. That setup code is allowed to stay plain, unclean and
untested — it holds no logic of its own, and its failures are loud and
immediate at startup.

- Inject into the core only what is hard to control — processes, network,
  filesystem, clock, randomness — or what serves as a sensor for side
  effects the tests need to observe.
- A seam is only warranted for a capability the core needs on-demand, in the
  middle of its work. Often the use case can instead be expressed as a
  function of domain data, with the external system reduced to a
  communication mechanism. Its I/O then happens at initialization or at the
  request boundary: the edge acquires and delivers, and the core needs no
  seam because it has no dependency — only inputs.
- A seam is a **minimal facade**: the smallest interface covering the actual
  use cases at hand, never a general-purpose wrapper around the external
  system.
- By default a seam sits at the external system's outermost physical
  boundary. A fake must replicate as little domain behavior as possible, so
  that it stays simple and obvious to produce.
- A seam may move inward when reality proves the simpler surface: when the
  application turns out to use the external API through a few argument
  patterns that map simply — without complex logic — onto a domain-fitting
  adapter, the facade can extend up to the simplest parametrizable surface
  that fulfills the application's needs completely, as long as it still is
  an interface to the real world. When unsure, default to the unflavored
  external system; widening and simplifying the adapter later is easy.
- The real adapter behind a seam still gets a contact test proving it
  actually touches the real world correctly.
- Interfaces can and should be shaped freely for testability — first and
  foremost via dependency injection — but domain logic and data structures
  never are. Interfaces are ergonomics: how domain data and rules are made
  manipulable, free to bend. The domain model is essence: the reality worked
  out and specified, and it must not change just because it is hard to test.

Influences:

- Hexagonal Architecture
- Humble Object pattern

## The Minimal Viable Language Construct

Every concept in the code is carried by the least powerful language
construct that can do its job — not more than the task needs, but also not
less than it demands. The progression runs roughly: constant → variable →
free function (module- or class-level, not bound to an instance) → closure
(essentially a one-method object) → object → composition of objects →
polymorphism → macros/metaprogramming. Reach for the next step only when
the current one falls short; step back down when a construct's power goes
unused.

A common pitfall is reaching for inheritance before it is needed: when every
subclass's `bark` method only returns a different string, a single `Animal`
with a `bark_sound` parameter serves better than an `Animal` hierarchy.

A construct chosen this way ends up perfectly fitted to its particular use.

Related ideas at neighboring design resolutions: the Transformation Priority
Premise (Robert C. Martin) at the finer resolution of transforming
individual code constructs from specific to generic; the principle of least
expressiveness (Concepts, Techniques, and Models of Computer Programming) at
the coarser resolution of choosing between whole computation models.

## Conceptual DRY, Not Structural DRY

Agents make mechanical multi-file edits cheap, so structural duplication —
code that merely looks alike — is no longer worth much to eliminate. What
still matters is conceptual: a fact or piece of domain logic that is
*supposed* to be the same must live in one logical place (deep modules, in
the sense of A Philosophy of Software Design). Consolidate meaning, not
shapes.

## Resulting Source-Code Preferences

- Call sites read true: keyword-only arguments wherever a bare positional
  call would be ambiguous at the point of use.
- Types are tooling — use them where they help callers and IDEs get calls
  right, and don't build a typed cathedral out of them.

## Context Guides

Architecture and testing patterns per kind of system:

- [references/clis.md](references/clis.md) — command-line tools
- [references/daemons.md](references/daemons.md) — daemons and background
  services
