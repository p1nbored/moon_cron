# MoonCron

MoonCron is a dependency-free, cross-target cron-expression core for MoonBit.
It fills the gap between an application's clock and its work queue: parse a
portable cron expression once, then use a typed schedule to decide whether a
UTC minute should trigger work, compute upcoming occurrences, or explain the
schedule to a human.

## Current scope

- Five-field cron: minute, hour, day of month, month, weekday.
- `*`, exact values, ranges (`9-17`), steps (`*/15`, `9-17/2`, `5/15`) and
  comma lists (`0,15,30,45`).
- Month and weekday names (`JAN`, `january`, `MON-FRI`), case-insensitive,
  and weekday 7 as a second spelling of Sunday.
- Scheduling macros: `@hourly`, `@daily`, `@midnight`, `@weekly`,
  `@monthly`, `@yearly` and `@annually`.
- Standard cron day-of-month / weekday OR semantics when both are
  restricted, with `*/n` steps anchored at each field's lowest value.
- A validated `UtcDateTime` calendar type with leap-year handling and
  weekday computation, `next_after` for the next occurrence and
  `next_occurrences` for bounded previews.
- Human-readable schedule descriptions via `describe`.
- Preset builders: `every_minute`, `hourly`, `weekday_hourly`, `daily_at`,
  `weekly_on` and `monthly_on`.
- No dependencies or backend-specific APIs; currently checked on wasm,
  wasm-gc, JavaScript and native targets.

## Use it

```mbt check
///|
test {
  let schedule = match @moon_cron.parse("*/15 9-17 * * MON-FRI") {
    Ok(value) => value
    Err(_) => fail("valid cron expression expected")
  }
  let monday = @moon_cron.UtcTime::new(30, 9, 6, 7, 1)
  assert_true(schedule.matches(monday))
  assert_eq(
    schedule.describe(),
    "every 15 minutes past hours 9 through 17 on Monday through Friday",
  )
  let now = @moon_cron.UtcDateTime::new(2026, 7, 6, 9, 30).unwrap()
  assert_true(
    schedule.next_after(now) ==
    Some(@moon_cron.UtcDateTime::new(2026, 7, 6, 9, 45).unwrap()),
  )
}
```

Run the included example with:

```text
moon run cmd/main
```

## Roadmap to a 4k-line ecosystem package

The parser, matcher, calendar, occurrence iterator and describer above are
the first delivered stages. The next stages are substantive, independently
useful components rather than padded code: a native CLI with input/output
adapters; JSON schedule serialization; and conformance/property test
suites. The target is approximately 4,000 effective MoonBit lines across
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
