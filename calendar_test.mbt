///|
test "gregorian leap year rules" {
  assert_true(@moon_cron.is_leap_year(2000))
  assert_true(@moon_cron.is_leap_year(2024))
  assert_false(@moon_cron.is_leap_year(1900))
  assert_false(@moon_cron.is_leap_year(2026))
  assert_false(@moon_cron.is_leap_year(2100))
}

///|
test "days in month follow the calendar" {
  assert_eq(@moon_cron.days_in_month(2026, 1), 31)
  assert_eq(@moon_cron.days_in_month(2026, 4), 30)
  assert_eq(@moon_cron.days_in_month(2026, 2), 28)
  assert_eq(@moon_cron.days_in_month(2024, 2), 29)
  assert_eq(@moon_cron.days_in_month(2026, 13), 0)
  assert_eq(@moon_cron.days_in_month(2026, 0), 0)
}

///|
test "date time construction validates the calendar" {
  assert_true(@moon_cron.UtcDateTime::new(2028, 2, 29, 0, 0) is Ok(_))
  assert_true(@moon_cron.UtcDateTime::new(2026, 2, 29, 0, 0) is Err(_))
  assert_true(@moon_cron.UtcDateTime::new(2026, 2, 30, 0, 0) is Err(_))
  assert_true(@moon_cron.UtcDateTime::new(2026, 13, 1, 0, 0) is Err(_))
  assert_true(@moon_cron.UtcDateTime::new(2026, 0, 1, 0, 0) is Err(_))
  assert_true(@moon_cron.UtcDateTime::new(2026, 1, 1, 24, 0) is Err(_))
  assert_true(@moon_cron.UtcDateTime::new(2026, 1, 1, 0, 60) is Err(_))
  assert_true(@moon_cron.UtcDateTime::new(0, 1, 1, 0, 0) is Err(_))
  assert_true(@moon_cron.UtcDateTime::new(9999, 12, 31, 23, 59) is Ok(_))
  assert_true(@moon_cron.UtcDateTime::new(10000, 1, 1, 0, 0) is Err(_))
}

///|
test "weekday follows cron convention with sunday as zero" {
  assert_eq(
    @moon_cron.UtcDateTime::new(2026, 7, 11, 0, 0).unwrap().weekday(),
    6,
  )
  assert_eq(@moon_cron.UtcDateTime::new(2000, 1, 1, 0, 0).unwrap().weekday(), 6)
  assert_eq(@moon_cron.UtcDateTime::new(1970, 1, 1, 0, 0).unwrap().weekday(), 4)
  assert_eq(
    @moon_cron.UtcDateTime::new(2024, 2, 29, 0, 0).unwrap().weekday(),
    4,
  )
  assert_eq(
    @moon_cron.UtcDateTime::new(2026, 7, 12, 0, 0).unwrap().weekday(),
    0,
  )
}

///|
test "date times order chronologically" {
  let earlier = @moon_cron.UtcDateTime::new(2026, 7, 11, 9, 30).unwrap()
  let later_minute = @moon_cron.UtcDateTime::new(2026, 7, 11, 9, 31).unwrap()
  let later_year = @moon_cron.UtcDateTime::new(2027, 1, 1, 0, 0).unwrap()
  assert_true(earlier < later_minute)
  assert_true(later_minute < later_year)
  assert_true(earlier == earlier)
}

///|
test "projection to wall clock computes the weekday" {
  let date = @moon_cron.UtcDateTime::new(2026, 7, 6, 9, 30).unwrap()
  let time = date.to_utc_time()
  assert_true(time == @moon_cron.UtcTime::new(30, 9, 6, 7, 1))
}
