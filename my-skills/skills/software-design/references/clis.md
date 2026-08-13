# CLIs

The architecture blueprint for command-line tools. A safe default to start
from in most cases, not a law.

## Architecture Blueprint

- **A super thin main layer.** It parses the arguments, wires up the
  application API, and forwards one call to it. It stays untested.
- **A testable application API** exposing every CLI command as immediately
  as possible — callable with what the argument parsing library already
  produces, without extra conversions or hoops to jump through — so that the
  main layer can really stay humble and just forward arguments,
  configuration and seam adapters. This is the surface where the system's
  behavior is comprehensively tested.
- **Seams follow the general rules of the main document.** For a CLI the
  usual hard-to-control dependencies are time and subprocesses. The files a
  tool reads and writes enter as paths, and tests exercise them as real
  files in temp directories.

## Implementation Corollaries

- **Arguments are parsed in one place** into a value object (or the
  idiomatic map/record equivalent). In general this is a simple pass-on
  layer from CLI flags to the application API call — it earns tests only
  if it grows beyond that.
- **Config is parsed in one place** into a value object, which the main
  layer usually hands to the application API at wiring time.
