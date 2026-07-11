# MoonCron

MoonCron is a dependency-free, cross-target cron-expression core for MoonBit.
It fills the gap between an application's clock and its work queue: parse a
portable cron expression once, then use a typed schedule to decide whether a
UTC minute should trigger work.

## Current scope

- Five-field cron: minute, hour, day of month, month, weekday.
- `*`, exact values, ranges (`9-17`), steps (`*/15`) and ranged steps
  (`9-17/2`).
- Standard cron day-of-month / weekday OR semantics when both are restricted.
- No dependencies or backend-specific APIs; currently checked on wasm,
  wasm-gc, JavaScript and native targets.

## Use it

```mbt check
///|
test {
  let schedule = match @moon_cron.parse("*/15 9-17 * * 1-5") {
    Ok(value) => value
    Err(_) => fail("valid cron expression expected")
  }
  let monday = @moon_cron.UtcTime::new(30, 9, 6, 7, 1)
  assert_true(schedule.matches(monday))
}
```

Run the included example with:

```text
moon run cmd/main
```

## Roadmap to a 4k-line ecosystem package

The initial parser/matcher is intentionally small and testable. The next
stages are substantive, independently useful components rather than padded
code: comma lists and named months/weekdays; calendar-aware `next_after` and
bounded occurrence iterators; human-readable descriptions; a native CLI with
input/output adapters; JSON schedule serialization; and conformance/property
test suites. The target is approximately 4,000 effective MoonBit lines across
these library packages, CLI, tests, fixtures and documentation.

## Non-goals

MoonCron is not a job runner, daemon, timezone database or distributed task
queue. Those layers can depend on this small deterministic scheduling core.

## Development

```text
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
```

The GitHub Actions workflow runs the same quality gates. The project is
original MoonBit code and is licensed under Apache-2.0.
