///|
test "describe renders the unrestricted schedule" {
  assert_eq(@moon_cron.parse("* * * * *").unwrap().describe(), "every minute")
}

///|
test "describe renders a working week schedule" {
  assert_eq(
    @moon_cron.parse("*/15 9-17 * * 1-5").unwrap().describe(),
    "every 15 minutes past hours 9 through 17 on Monday through Friday",
  )
}

///|
test "describe spells out the day or weekday rule" {
  assert_eq(
    @moon_cron.parse("0 9 1 * 1").unwrap().describe(),
    "at minute 0 past hour 9 on day 1 of the month or on Monday",
  )
}

///|
test "describe names months" {
  assert_eq(
    @moon_cron.parse("30 4 * 2 *").unwrap().describe(),
    "at minute 30 past hour 4 in February",
  )
}

///|
test "describe keeps the hour clause for restricted minutes" {
  assert_eq(
    @moon_cron.parse("0 * * * *").unwrap().describe(),
    "at minute 0 past every hour",
  )
}

///|
test "describe joins lists as prose" {
  assert_eq(
    @moon_cron.parse("0,30 8,16 * * 0,6").unwrap().describe(),
    "at minutes 0 and 30 past hours 8 and 16 on Sunday and Saturday",
  )
  assert_eq(
    @moon_cron.parse("0,15,30 * * * *").unwrap().describe(),
    "at minutes 0, 15 and 30 past every hour",
  )
}

///|
test "describe handles offset steps and day lists" {
  assert_eq(
    @moon_cron.parse("5/15 * * * *").unwrap().describe(),
    "every 15 minutes from 5 through 59 past every hour",
  )
  assert_eq(
    @moon_cron.parse("0 0 1,15 * *").unwrap().describe(),
    "at minute 0 past hour 0 on days 1 and 15 of the month",
  )
}

///|
test "describe renders steps with ordinals" {
  assert_eq(
    @moon_cron.parse("0 */2 */3 * *").unwrap().describe(),
    "at minute 0 past every 2nd hour on every 3rd day of the month",
  )
}

///|
test "describe treats weekday seven as sunday" {
  assert_eq(
    @moon_cron.parse("0 0 * * 7").unwrap().describe(),
    "at minute 0 past hour 0 on Sunday",
  )
}

///|
test "describe falls back to prose for mixed lists" {
  assert_eq(
    @moon_cron.parse("0 1,5-9 * * *").unwrap().describe(),
    "at minute 0 past hour 1 and hours 5 through 9",
  )
}

///|
test "describe handles unrestricted minutes with restricted hours" {
  assert_eq(
    @moon_cron.parse("* 9 * * *").unwrap().describe(),
    "every minute past hour 9",
  )
}

///|
test "describe renders yearly schedules" {
  assert_eq(
    @moon_cron.parse("@yearly").unwrap().describe(),
    "at minute 0 past hour 0 on day 1 of the month in January",
  )
}
