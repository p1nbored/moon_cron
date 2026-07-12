///|
test "next after finds the next quarter hour" {
  let cron = @moon_cron.parse("*/15 * * * *").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 7, 11, 10, 7).unwrap()
  assert_true(
    cron.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2026, 7, 11, 10, 15).unwrap()),
  )
}

///|
test "next after is strictly after the given minute" {
  let cron = @moon_cron.parse("*/15 * * * *").unwrap()
  let on_match = @moon_cron.UtcDateTime::new(2026, 7, 11, 10, 15).unwrap()
  assert_true(
    cron.next_after(on_match) ==
    Some(@moon_cron.UtcDateTime::new(2026, 7, 11, 10, 30).unwrap()),
  )
}

///|
test "next after rolls over midnight and the year" {
  let cron = @moon_cron.parse("0 0 * * *").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 12, 31, 23, 59).unwrap()
  assert_true(
    cron.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2027, 1, 1, 0, 0).unwrap()),
  )
}

///|
test "next after applies the day or weekday rule" {
  // Day 1 of the month OR a Monday: from a Sunday, the following Monday
  // wins over the first day of the next month.
  let cron = @moon_cron.parse("0 9 1 * 1").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 8, 2, 0, 0).unwrap()
  assert_true(
    cron.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2026, 8, 3, 9, 0).unwrap()),
  )
}

///|
test "next after reaches february the twenty ninth" {
  let cron = @moon_cron.parse("0 0 29 2 *").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 1, 1, 0, 0).unwrap()
  assert_true(
    cron.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2028, 2, 29, 0, 0).unwrap()),
  )
}

///|
test "impossible schedules produce no occurrence" {
  let cron = @moon_cron.parse("0 0 30 2 *").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 1, 1, 0, 0).unwrap()
  assert_true(cron.next_after(from) is None)
}

///|
test "next occurrences returns consecutive matches in order" {
  let cron = @moon_cron.parse("30 12 * * *").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 7, 11, 0, 0).unwrap()
  let occurrences = cron.next_occurrences(from, 3)
  assert_eq(occurrences.length(), 3)
  assert_true(
    occurrences[0] == @moon_cron.UtcDateTime::new(2026, 7, 11, 12, 30).unwrap(),
  )
  assert_true(
    occurrences[1] == @moon_cron.UtcDateTime::new(2026, 7, 12, 12, 30).unwrap(),
  )
  assert_true(
    occurrences[2] == @moon_cron.UtcDateTime::new(2026, 7, 13, 12, 30).unwrap(),
  )
}

///|
test "next occurrences stops when the schedule dries up" {
  let cron = @moon_cron.parse("0 0 30 2 *").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 1, 1, 0, 0).unwrap()
  assert_eq(cron.next_occurrences(from, 5).length(), 0)
  assert_eq(cron.next_occurrences(from, -1).length(), 0)
}

///|
test "next after stops at the end of the calendar" {
  let cron = @moon_cron.parse("0 * * * *").unwrap()
  let from = @moon_cron.UtcDateTime::new(9999, 12, 31, 23, 59).unwrap()
  assert_true(cron.next_after(from) is None)
}

///|
test "next after still works late in year 9999" {
  let cron = @moon_cron.parse("0 0 * * *").unwrap()
  let from = @moon_cron.UtcDateTime::new(9999, 12, 30, 1, 0).unwrap()
  assert_true(
    cron.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(9999, 12, 31, 0, 0).unwrap()),
  )
}

///|
test "the minute cursor resets when the search advances an hour" {
  let cron = @moon_cron.parse("15 * * * *").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 7, 11, 10, 20).unwrap()
  assert_true(
    cron.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2026, 7, 11, 11, 15).unwrap()),
  )
}

///|
test "matches at agrees with wall clock matching" {
  let cron = @moon_cron.parse("*/15 9-17 * * 1-5").unwrap()
  let monday = @moon_cron.UtcDateTime::new(2026, 7, 6, 9, 30).unwrap()
  let sunday = @moon_cron.UtcDateTime::new(2026, 7, 5, 9, 30).unwrap()
  assert_true(cron.matches_at(monday))
  assert_false(cron.matches_at(sunday))
}

///|
test "every occurrence returned satisfies the schedule" {
  let cron = @moon_cron.parse("*/20 6-8 * mar 1-5").unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 1, 1, 0, 0).unwrap()
  let occurrences = cron.next_occurrences(from, 25)
  assert_eq(occurrences.length(), 25)
  let mut cursor = from
  for occurrence in occurrences {
    assert_true(cron.matches_at(occurrence))
    assert_true(cursor < occurrence)
    cursor = occurrence
  }
}
