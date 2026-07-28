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
  weekday computation, signed date arithmetic, closed time ranges,
  `next_after` / `previous_before`, bounded occurrence queries and paging.
- Human-readable schedule descriptions via `describe`.
- Preset builders: `every_minute`, `hourly`, `weekday_hourly`, `daily_at`,
  `weekly_on` and `monthly_on`.
- Programmatic field algebra for validation, normalization, union,
  intersection, difference and overlap prechecks.
- Source-aware crontab documents with comments, environment assignments,
  macros, command lookup, due-command queries and stable rendering.
- Named schedule registries with enablement, merged events, collision
  detection and bounded audits.
- Operational policies with maintenance blackouts and one-off inclusions.
- Frequency, hourly/weekday distribution, peak concurrency, collision and
  health reports suitable for command-line or CI artifacts.
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

Parse and query a complete crontab document:

```mbt check
///|
test {
  let document = @moon_cron.parse_crontab(
    (
      #|# Operations
      #|SHELL=/bin/sh
      #|0 9 * * MON-FRI open-office
      #|*/15 9-17 * * MON-FRI collect-metrics
    ),
  ).unwrap()
  assert_eq(document.entry_count(), 2)
  assert_eq(document.variable("SHELL"), Some("/bin/sh"))
  let at = @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap()
  assert_eq(document.due_at(at).length(), 2)
}
```

Apply a maintenance blackout and produce an operational report:

```mbt check
///|
test {
  let cron = @moon_cron.parse("0 9-17 * * MON-FRI").unwrap()
  let policy = @moon_cron.SchedulePolicy::new(cron)
    .unwrap()
    .add_blackout(
      @moon_cron.ScheduleBlackout::new(
        @moon_cron.DateTimeRange::new(
          @moon_cron.parse_utc_datetime("2026-07-27T12:00Z").unwrap(),
          @moon_cron.parse_utc_datetime("2026-07-27T14:00Z").unwrap(),
        ).unwrap(),
        reason="maintenance",
      ),
    )
  let noon = @moon_cron.parse_utc_datetime("2026-07-27T12:00Z").unwrap()
  assert_eq(policy.decision_at(noon), @moon_cron.Excluded("maintenance"))

  let book = @moon_cron.ScheduleBook::new()
  book.add(@moon_cron.NamedSchedule::new("office", cron).unwrap()).unwrap()
  let day = @moon_cron.DateTimeRange::new(
    @moon_cron.parse_utc_datetime("2026-07-27T00:00Z").unwrap(),
    @moon_cron.parse_utc_datetime("2026-07-27T23:59Z").unwrap(),
  ).unwrap()
  assert_eq(book.report(day).total_events, 9)
}
```

Run the included example with:

```text
moon run cmd/main
```

## Delivered scale

The package now contains more than 4,000 non-test MoonBit source lines. The
workload is enforced in CI using `scripts/count-production-lines.ps1`, which
excludes tests, generated interfaces, examples and build output. The
implementation is split by capability rather than padded into a single file.

## Non-goals

MoonCron is not a job runner, daemon, timezone database or distributed task
queue. Those layers can depend on this small deterministic scheduling core.

## Development

```text
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
moon package
```

The GitHub Actions workflow runs the same quality gates, verifies generated
interfaces remain clean, runs the example and enforces the production-code
floor. The project is original MoonBit code and is licensed under Apache-2.0.
