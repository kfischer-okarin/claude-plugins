# Daemons and Background Services

The same architecture blueprint as [CLIs](clis.md), with a simpler
centerpiece.

## Architecture Blueprint

- **A super thin main layer.** It builds the application object and runs the
  forever loop. The loop itself — while true: tick, sleep — stays in the
  untested main layer.
- **The centerpiece is a `tick` method** representing one iteration of that
  loop. Everything the daemon does is comprehensively tested by calling
  `tick` directly.
- **Time enters as an argument.** `tick(now=...)` keeps the whole behavior a
  function of the clock, so tests state moments instead of stubbing time.
- **Seams for external systems** follow the CLI rules: outermost physical
  boundary by default, moved inward to a simpler domain-fitting surface when
  reality proves the mapping stays trivial.

Argument and config parsing follow the CLI corollaries unchanged.
