///|
test "field semantic set operations are canonical" {
  let odd = @moon_cron.parse("* * 1-9/2 * *").unwrap().day_of_month
  let low = @moon_cron.parse("* * 1-5 * *").unwrap().day_of_month
  assert_eq(
    odd
    .intersection(low, @moon_cron.DayOfMonthDomain)
    .values(@moon_cron.DayOfMonthDomain),
    [1, 3, 5],
  )
  assert_eq(
    odd
    .difference(low, @moon_cron.DayOfMonthDomain)
    .values(@moon_cron.DayOfMonthDomain),
    [7, 9],
  )
  assert_true(low.overlaps(odd, @moon_cron.DayOfMonthDomain))
}

///|
test "normalization compresses arithmetic runs" {
  let field = @moon_cron.parse("* * 1,3,5,7 * *").unwrap().day_of_month
  assert_eq(field.normalized(@moon_cron.MonthDomain).to_expression(), "1-7/2")
}

///|
test "schedule validation catches invalid programmatic fields" {
  let valid = @moon_cron.parse("*/15 9-17 * * MON-FRI").unwrap()
  assert_true(valid.validate() is Ok(_))
  assert_true(
    @moon_cron.Cron::from_fields(
      @moon_cron.Field::exact(99),
      @moon_cron.Field::any(),
      @moon_cron.Field::any(),
      @moon_cron.Field::any(),
      @moon_cron.Field::any(),
    )
    is Err(_),
  )
}

///|
test "field summary and overlap preflight" {
  let work = @moon_cron.parse("0,30 9-17 * * MON-FRI").unwrap()
  let summary = work.field_summary()
  assert_eq(summary.minute_values, 2)
  assert_eq(summary.hour_values, 9)
  assert_eq(work.maximum_daily_runs(), 18)
  let lunch = @moon_cron.parse("0 12 * * MON-FRI").unwrap()
  let night = @moon_cron.parse("15 23 * * MON-FRI").unwrap()
  assert_true(work.may_overlap(lunch))
  assert_false(work.may_overlap(night))
}
