///|
test "parse and match a weekday work schedule" {
  let cron = match @moon_cron.parse("*/15 9-17 * * 1-5") {
    Ok(cron) => cron
    Err(error) => fail("parse failed: \{error}")
  }
  assert_true(cron.matches(@moon_cron.UtcTime::new(30, 9, 6, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(31, 9, 6, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(30, 18, 6, 7, 1)))
}
