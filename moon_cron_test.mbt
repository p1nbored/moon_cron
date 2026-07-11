///|
test "parse and match a weekday work schedule" {
  let cron = match @moon_cron.parse("*/15 9-17 * * 1-5") {
    Ok(cron) => cron
    Err(error) => fail("parse failed: \{error}")
  }
  assert_true(
    cron.matches({ minute: 30, hour: 9, day_of_month: 6, month: 7, weekday: 1 }),
  )
  assert_false(
    cron.matches({ minute: 31, hour: 9, day_of_month: 6, month: 7, weekday: 1 }),
  )
  assert_false(
    cron.matches({ minute: 30, hour: 18, day_of_month: 6, month: 7, weekday: 1 }),
  )
}
