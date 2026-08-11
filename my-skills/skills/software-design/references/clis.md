# CLIs

The architecture blueprint for command-line tools. A safe default to start
from in most cases, not a law.

## Architecture Blueprint

- **A super thin main layer.** It parses the arguments, builds the
  application object, and calls one method on it. It stays untested.
- **One big, pure Application object** exposing all CLI functionality
  directly as methods. This is the seam where the system's behavior is
  comprehensively tested.
- **External systems — most commonly time, filesystem, subprocesses — get
  their seams at their outermost physical boundary.** The fake replaces the
  raw filesystem, not a higher-level "config storage" built on top of it:
  a fake must replicate as little domain behavior as possible, so that it
  stays super simple and obvious to produce.
- **A seam may move inward when reality proves the simpler surface.** When
  the application turns out to use an external API through a few specific
  argument patterns that map simply — without complex logic — onto a
  domain-fitting adapter, the facade can extend up to the simplest
  parametrizable surface that fulfills the application's needs completely,
  as long as it still is an interface to the real world. When unsure,
  default to the unflavored external system; widening and simplifying the
  adapter later is easy.

## Implementation Corollaries

- **Arguments are parsed in one place** into a value object (or the
  idiomatic map/record equivalent). In general this is a simple pass-on
  layer from CLI flags to the application method call — it earns tests only
  if it grows beyond that.
- **Config is parsed in one place** into a value object, which usually
  enters as a constructor parameter of the application object.
