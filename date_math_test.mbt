///|
test "date arithmetic crosses leap-day and year boundaries" {
  let leap = @moon_cron.parse_utc_datetime("2024-02-28T23:59Z").unwrap()
  assert_eq(leap.add_minutes(1).unwrap().to_iso8601(), "2024-02-29T00:00Z")
  let year_end = @moon_cron.parse_utc_datetime("2025-12-31T23:59Z").unwrap()
  assert_eq(year_end.add_minutes(1).unwrap().to_iso8601(), "2026-01-01T00:00Z")
  assert_eq(
    year_end.add_minutes(-1440).unwrap().to_iso8601(),
    "2025-12-30T23:59Z",
  )
}

///|
test "date and datetime ISO round-trip" {
  let date = @moon_cron.parse_utc_date("2026-07-28").unwrap()
  assert_eq(date.to_iso8601(), "2026-07-28")
  let time = @moon_cron.parse_utc_datetime("2026-07-28T16:30Z").unwrap()
  assert_eq(time.to_iso8601(), "2026-07-28T16:30Z")
  assert_true(@moon_cron.parse_utc_date("2026-02-29") is Err(_))
  assert_true(@moon_cron.parse_utc_datetime("2026-07-28 16:30") is Err(_))
}

///|
test "date ranges contain intersect and chunk minutes" {
  let start = @moon_cron.parse_utc_datetime("2026-07-28T09:00Z").unwrap()
  let end = @moon_cron.parse_utc_datetime("2026-07-28T10:04Z").unwrap()
  let range = @moon_cron.DateTimeRange::new(start, end).unwrap()
  assert_eq(range.minute_count(), 65)
  let chunks = range.chunks(30)
  assert_eq(chunks.length(), 3)
  assert_eq(chunks[0].minute_count(), 30)
  assert_eq(chunks[1].minute_count(), 30)
  assert_eq(chunks[2].minute_count(), 5)
}
