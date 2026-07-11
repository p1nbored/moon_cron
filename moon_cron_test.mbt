///|
test "parse and match a weekday work schedule" {
  let cron = match @moon_cron.parse("*/15 9-17 * * 1-5") {
    Ok(cron) => cron
    Err(_) => fail("parse failed")
  }
  assert_true(cron.matches(@moon_cron.UtcTime::new(30, 9, 6, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(31, 9, 6, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(30, 18, 6, 7, 1)))
}

///|
test "reject invalid cron fields" {
  assert_true(@moon_cron.parse("* * * *") is Err(_))
  assert_true(@moon_cron.parse("60 * * * *") is Err(_))
  assert_true(@moon_cron.parse("*/0 * * * *") is Err(_))
  assert_true(@moon_cron.parse("9-2 * * * *") is Err(_))
}

///|
test "parsed schedules round-trip to a portable expression" {
  let schedule = @moon_cron.parse("*/15 9-17 1-10/2 * 1-5").unwrap()
  assert_eq(schedule.to_expression(), "*/15 9-17 1-10/2 * 1-5")
}
