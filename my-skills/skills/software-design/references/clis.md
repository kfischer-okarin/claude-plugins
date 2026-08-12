# CLIs

The architecture blueprint for command-line tools. A safe default to start
from in most cases, not a law.

## Architecture Blueprint

- **A super thin main layer.** It parses the arguments, builds the
  application object, and calls one method on it. It stays untested.
- **One big, pure Application object** exposing all CLI functionality
  directly as methods. This is the seam where the system's behavior is
  comprehensively tested.
- **Seams follow the general rules of the main document.** For a CLI the
  usual external systems are time, filesystem and subprocesses; the fake by
  default replaces the raw filesystem, not a higher-level "config storage"
  built on top of it.

## Implementation Corollaries

- **Arguments are parsed in one place** into a value object (or the
  idiomatic map/record equivalent). In general this is a simple pass-on
  layer from CLI flags to the application method call — it earns tests only
  if it grows beyond that.
- **Config is parsed in one place** into a value object, which usually
  enters as a constructor parameter of the application object.
