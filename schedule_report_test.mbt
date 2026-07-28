///|
fn report_book() -> @moon_cron.ScheduleBook {
  let book = @moon_cron.ScheduleBook::new()
  book
  .add(
    @moon_cron.NamedSchedule::new(
      "quarter-hour",
      @moon_cron.parse("*/15 9-17 * * MON-FRI").unwrap(),
    ).unwrap(),
  )
  .unwrap()
  book
  .add(
    @moon_cron.NamedSchedule::new(
      "hourly",
      @moon_cron.parse("0 9-17 * * MON-FRI").unwrap(),
    ).unwrap(),
  )
  .unwrap()
  book
}

///|
test "schedule statistics include hourly and weekday distributions" {
  let schedule = @moon_cron.NamedSchedule::new(
    "hourly",
    @moon_cron.parse("0 9-17 * * MON-FRI").unwrap(),
  ).unwrap()
  let range = @moon_cron.DateTimeRange::new(
    @moon_cron.parse_utc_datetime("2026-07-27T00:00Z").unwrap(),
    @moon_cron.parse_utc_datetime("2026-07-27T23:59Z").unwrap(),
  ).unwrap()
  let stats = @moon_cron.analyze_schedule(schedule, range)
  assert_eq(stats.occurrence_count, 9)
  assert_eq(stats.active_days, 1)
  assert_eq(stats.frequency, @moon_cron.Moderate)
  assert_eq(stats.hour_count(9), 1)
  assert_eq(stats.weekday_count(1), 9)
}

///|
test "schedule report identifies collision pairs and peak minute" {
  let range = @moon_cron.DateTimeRange::new(
    @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap(),
    @moon_cron.parse_utc_datetime("2026-07-27T10:00Z").unwrap(),
  ).unwrap()
  let report = report_book().report(range)
  assert_eq(report.schedule_count(), 2)
  assert_eq(report.collision_pair_count(), 1)
  assert_eq(report.collision_for("hourly", "quarter-hour").unwrap().count, 2)
  assert_eq(report.peak.unwrap().schedule_names.length(), 2)
  assert_eq(report.active_day_count(), 1)
  assert_eq(report.busiest_day().unwrap().event_count, 7)
  assert_eq(report.health(), @moon_cron.NeedsAttention)
}

///|
test "disabled schedules are reported as dormant" {
  let book = report_book()
  book.set_enabled("hourly", false).unwrap()
  let range = @moon_cron.DateTimeRange::new(
    @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap(),
    @moon_cron.parse_utc_datetime("2026-07-27T17:00Z").unwrap(),
  ).unwrap()
  let report = book.report(range)
  assert_eq(report.dormant_names(), ["hourly"])
  assert_eq(report.collision_pair_count(), 0)
}

///|
test "text report exposes reproducible operational evidence" {
  let range = @moon_cron.DateTimeRange::new(
    @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap(),
    @moon_cron.parse_utc_datetime("2026-07-27T09:30Z").unwrap(),
  ).unwrap()
  let text = report_book().report(range).to_text()
  assert_true(text.contains("MoonCron schedule report"))
  assert_true(text.contains("collision pairs: 1"))
  assert_true(text.contains("health: needs-attention"))
  assert_true(text.contains("Recommendations:"))
  assert_true(text.contains("quarter-hour"))
  assert_true(text.contains("2026-07-27T09:00Z"))
}
