///|
fn make_book() -> @moon_cron.ScheduleBook {
  let book = @moon_cron.ScheduleBook::new()
  book
  .add(
    @moon_cron.NamedSchedule::new(
      "quarter-hour",
      @moon_cron.parse("*/15 9 * * MON-FRI").unwrap(),
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
test "schedule book enforces unique names and enablement" {
  let book = make_book()
  assert_eq(book.length(), 2)
  assert_eq(book.enabled_length(), 2)
  assert_true(
    book.add(
      @moon_cron.NamedSchedule::new("hourly", @moon_cron.every_minute()).unwrap(),
    )
    is Err(_),
  )
  book.set_enabled("hourly", false).unwrap()
  assert_eq(book.enabled_length(), 1)
  assert_true(book.get("hourly").unwrap().enabled == false)
}

///|
test "schedule book merges events chronologically" {
  let book = make_book()
  let start = @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap()
  let end = @moon_cron.parse_utc_datetime("2026-07-27T09:45Z").unwrap()
  let range = @moon_cron.DateTimeRange::new(start, end).unwrap()
  let events = book.events(range)
  assert_eq(events.length(), 5)
  assert_eq(events[0].at.to_iso8601(), "2026-07-27T09:00Z")
  assert_eq(events[0].schedule_name, "hourly")
  assert_eq(events[1].schedule_name, "quarter-hour")
  let batches = book.event_batches(range)
  assert_eq(batches.length(), 4)
  assert_eq(batches[0].schedule_names.length(), 2)
}

///|
test "schedule book audits pairwise collisions" {
  let book = make_book()
  let start = @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap()
  let end = @moon_cron.parse_utc_datetime("2026-07-27T17:59Z").unwrap()
  let range = @moon_cron.DateTimeRange::new(start, end).unwrap()
  let audit = book.audit(range)
  assert_eq(audit.total, 2)
  assert_eq(audit.enabled, 2)
  assert_eq(audit.collision_pairs, 1)
  assert_eq(audit.dormant_names.length(), 0)
}

///|
test "schedule book inventory is stable" {
  let book = make_book()
  assert_eq(
    book.to_text(),
    "[enabled] quarter-hour: */15 9 * * 1-5\n[enabled] hourly: 0 9-17 * * 1-5",
  )
  let removed = book.remove("hourly").unwrap()
  assert_eq(removed.name, "hourly")
  assert_true(book.remove("missing") is Err(_))
}
