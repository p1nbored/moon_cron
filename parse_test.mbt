///|
test "comma lists parse, match and round-trip" {
  let cron = @moon_cron.parse("0,15,30,45 * * * *").unwrap()
  assert_true(cron.matches(@moon_cron.UtcTime::new(15, 3, 6, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(16, 3, 6, 7, 1)))
  assert_eq(cron.to_expression(), "0,15,30,45 * * * *")
}

///|
test "lists combine exact values, ranges and steps" {
  let cron = @moon_cron.parse("* * 1-5,10-20/5,25 * *").unwrap()
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 3, 7, 1)))
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 15, 7, 1)))
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 25, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(0, 0, 11, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(0, 0, 26, 7, 1)))
  assert_eq(cron.to_expression(), "* * 1-5,10-20/5,25 * *")
}

///|
test "month and weekday names are accepted case-insensitively" {
  let cron = @moon_cron.parse("0 9 * jan Mon-FRI").unwrap()
  assert_eq(cron.to_expression(), "0 9 * 1 1-5")
  let full = @moon_cron.parse("0 0 * JANUARY sunday").unwrap()
  assert_eq(full.to_expression(), "0 0 * 1 0")
}

///|
test "unknown names are reported" {
  assert_true(
    @moon_cron.parse("0 0 * FOO *")
    is Err(@moon_cron.CronError::UnknownName("FOO")),
  )
  assert_true(
    @moon_cron.parse("0 0 * * NODAY")
    is Err(@moon_cron.CronError::UnknownName("NODAY")),
  )
}

///|
test "weekday seven means sunday" {
  let exact = @moon_cron.parse("0 0 * * 7").unwrap()
  assert_true(exact.matches(@moon_cron.UtcTime::new(0, 0, 5, 7, 0)))
  assert_false(exact.matches(@moon_cron.UtcTime::new(0, 0, 5, 7, 1)))
  let range = @moon_cron.parse("0 0 * * 5-7").unwrap()
  assert_true(range.matches(@moon_cron.UtcTime::new(0, 0, 5, 7, 6)))
  assert_true(range.matches(@moon_cron.UtcTime::new(0, 0, 5, 7, 0)))
  assert_false(range.matches(@moon_cron.UtcTime::new(0, 0, 5, 7, 1)))
}

///|
test "day-of-month steps anchor at day one" {
  let cron = @moon_cron.parse("0 0 */2 * *").unwrap()
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 1, 7, 1)))
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 3, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(0, 0, 2, 7, 1)))
}

///|
test "a value with a step runs to the top of the field" {
  let cron = @moon_cron.parse("5/15 * * * *").unwrap()
  assert_true(cron.matches(@moon_cron.UtcTime::new(5, 0, 1, 7, 1)))
  assert_true(cron.matches(@moon_cron.UtcTime::new(50, 0, 1, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(0, 0, 1, 7, 1)))
  assert_eq(cron.to_expression(), "5-59/15 * * * *")
}

///|
test "macros expand to standard schedules" {
  assert_eq(@moon_cron.parse("@hourly").unwrap().to_expression(), "0 * * * *")
  assert_eq(@moon_cron.parse("@daily").unwrap().to_expression(), "0 0 * * *")
  assert_eq(@moon_cron.parse("@midnight").unwrap().to_expression(), "0 0 * * *")
  assert_eq(@moon_cron.parse("@weekly").unwrap().to_expression(), "0 0 * * 0")
  assert_eq(@moon_cron.parse("@monthly").unwrap().to_expression(), "0 0 1 * *")
  assert_eq(@moon_cron.parse("@yearly").unwrap().to_expression(), "0 0 1 1 *")
  assert_eq(@moon_cron.parse("@Annually").unwrap().to_expression(), "0 0 1 1 *")
  assert_true(
    @moon_cron.parse("@reboot")
    is Err(@moon_cron.CronError::UnsupportedSyntax("@reboot")),
  )
}

///|
test "tabs and repeated spaces separate fields" {
  let cron = @moon_cron.parse("\t0  12\t* *   1 ").unwrap()
  assert_eq(cron.to_expression(), "0 12 * * 1")
}

///|
test "trailing newlines are tolerated" {
  let cron = @moon_cron.parse("0 12 * * 1\r\n").unwrap()
  assert_eq(cron.to_expression(), "0 12 * * 1")
}

///|
test "oversized numbers cannot wrap into range" {
  assert_true(@moon_cron.parse("4294967296 * * * *") is Err(_))
  assert_true(@moon_cron.parse("99999999999999999999 * * * *") is Err(_))
}

///|
test "empty list elements are rejected" {
  assert_true(@moon_cron.parse("1, * * * *") is Err(_))
  assert_true(@moon_cron.parse("1,,2 * * * *") is Err(_))
}

///|
test "month steps anchor at january" {
  let cron = @moon_cron.parse("0 0 1 */2 *").unwrap()
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 1, 3, 0)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(0, 0, 1, 2, 0)))
  let from = @moon_cron.UtcDateTime::new(2026, 1, 15, 0, 0).unwrap()
  assert_true(
    cron.next_after(from) ==
    Some(@moon_cron.UtcDateTime::new(2026, 3, 1, 0, 0).unwrap()),
  )
}

///|
test "list elements keep step anchoring" {
  let cron = @moon_cron.parse("0 0 */10,7 * *").unwrap()
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 11, 7, 1)))
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 7, 7, 1)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(0, 0, 10, 7, 1)))
}

///|
test "a wall clock weekday of seven matches sunday schedules" {
  let cron = @moon_cron.parse("0 0 * * 0").unwrap()
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 5, 7, 7)))
}

///|
test "field matching honours an explicit lower bound" {
  let cron = @moon_cron.parse("0 0 */2 * *").unwrap()
  assert_true(cron.day_of_month.matches(3, lower=1))
  assert_false(cron.day_of_month.matches(3))
}

///|
test "named ranges match schedules" {
  let cron = @moon_cron.parse("0 0 * mar-may mon,wed,fri").unwrap()
  assert_eq(cron.to_expression(), "0 0 * 3-5 1,3,5")
  assert_true(cron.matches(@moon_cron.UtcTime::new(0, 0, 10, 4, 3)))
  assert_false(cron.matches(@moon_cron.UtcTime::new(0, 0, 10, 6, 3)))
}
