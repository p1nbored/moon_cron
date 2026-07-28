///|
test "forward and reverse queries agree" {
  let cron = @moon_cron.parse("0,30 9 * * MON-FRI").unwrap()
  let monday = @moon_cron.parse_utc_datetime("2026-07-27T08:59Z").unwrap()
  let first = cron.next_after(monday).unwrap()
  assert_eq(first.to_iso8601(), "2026-07-27T09:00Z")
  assert_eq(
    cron.previous_before(first).unwrap().to_iso8601(),
    "2026-07-24T09:30Z",
  )
}

///|
test "bounded occurrence query count and gaps" {
  let cron = @moon_cron.parse("*/15 9 * * *").unwrap()
  let start = @moon_cron.parse_utc_datetime("2026-07-28T09:00Z").unwrap()
  let end = @moon_cron.parse_utc_datetime("2026-07-28T09:59Z").unwrap()
  let range = @moon_cron.DateTimeRange::new(start, end).unwrap()
  let query = @moon_cron.OccurrenceQuery::new(range, 10).unwrap()
  assert_eq(cron.occurrences(query).length(), 4)
  assert_eq(cron.count_occurrences(range).count, 4)
  let gaps = cron.gap_summary(range).unwrap()
  assert_eq(gaps.minimum_minutes, 15)
  assert_eq(gaps.maximum_minutes, 15)
}

///|
test "collision query finds shared minutes" {
  let left = @moon_cron.parse("*/15 9 * * *").unwrap()
  let right = @moon_cron.parse("0,30 9 * * *").unwrap()
  let start = @moon_cron.parse_utc_datetime("2026-07-28T09:00Z").unwrap()
  let end = @moon_cron.parse_utc_datetime("2026-07-28T09:59Z").unwrap()
  let range = @moon_cron.DateTimeRange::new(start, end).unwrap()
  let collisions = left.collisions_with(right, range)
  assert_eq(collisions.length(), 2)
  assert_eq(collisions[0].at.to_iso8601(), "2026-07-28T09:00Z")
  assert_eq(collisions[1].at.to_iso8601(), "2026-07-28T09:30Z")
}

///|
test "daily counts and cursor pages are bounded" {
  let cron = @moon_cron.parse("0 * * * *").unwrap()
  let start = @moon_cron.parse_utc_datetime("2026-07-28T00:00Z").unwrap()
  let end = @moon_cron.parse_utc_datetime("2026-07-29T23:59Z").unwrap()
  let range = @moon_cron.DateTimeRange::new(start, end).unwrap()
  let counts = cron.daily_counts(range)
  assert_eq(counts.length(), 2)
  assert_eq(counts[0].count, 24)
  assert_eq(counts[1].count, 24)
  let page = cron.occurrence_page(start, end, 3).unwrap()
  assert_eq(page.values.length(), 3)
  assert_true(page.next_cursor is Some(_))
}
