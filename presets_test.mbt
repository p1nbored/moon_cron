///|
test "every minute preset renders the wildcard schedule" {
  assert_eq(@moon_cron.every_minute().to_expression(), "* * * * *")
}

///|
test "daily preset validates and renders its time" {
  assert_eq(@moon_cron.daily_at(9, 30).unwrap().to_expression(), "30 9 * * *")
  assert_true(@moon_cron.daily_at(24, 0) is Err(_))
  assert_true(@moon_cron.daily_at(0, 60) is Err(_))
}

///|
test "weekly preset canonicalises sunday" {
  assert_eq(@moon_cron.weekly_on(1, 9, 0).unwrap().to_expression(), "0 9 * * 1")
  assert_eq(@moon_cron.weekly_on(7, 0, 0).unwrap().to_expression(), "0 0 * * 0")
  assert_true(@moon_cron.weekly_on(8, 0, 0) is Err(_))
}

///|
test "monthly preset validates its day" {
  assert_eq(
    @moon_cron.monthly_on(15, 8, 30).unwrap().to_expression(),
    "30 8 15 * *",
  )
  assert_true(@moon_cron.monthly_on(0, 0, 0) is Err(_))
  assert_true(@moon_cron.monthly_on(32, 0, 0) is Err(_))
}

///|
test "weekly preset matches only its weekday" {
  let schedule = @moon_cron.weekly_on(1, 9, 0).unwrap()
  let monday = @moon_cron.UtcDateTime::new(2026, 7, 6, 9, 0).unwrap()
  let tuesday = @moon_cron.UtcDateTime::new(2026, 7, 7, 9, 0).unwrap()
  assert_true(schedule.matches_at(monday))
  assert_false(schedule.matches_at(tuesday))
}

///|
test "monthly preset skips months without its day" {
  let schedule = @moon_cron.monthly_on(31, 0, 0).unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 4, 1, 0, 0).unwrap()
  assert_true(
    schedule.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2026, 5, 31, 0, 0).unwrap()),
  )
}

///|
test "presets cooperate with occurrence computation" {
  let schedule = @moon_cron.daily_at(9, 30).unwrap()
  let from = @moon_cron.UtcDateTime::new(2026, 7, 11, 12, 0).unwrap()
  assert_true(
    schedule.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2026, 7, 12, 9, 30).unwrap()),
  )
}
