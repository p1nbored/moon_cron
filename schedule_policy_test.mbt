///|
fn policy_fixture() -> @moon_cron.SchedulePolicy {
  let cron = @moon_cron.parse("0 9-17 * * MON-FRI").unwrap()
  let blackout = @moon_cron.ScheduleBlackout::new(
    @moon_cron.DateTimeRange::new(
      @moon_cron.parse_utc_datetime("2026-07-27T12:00Z").unwrap(),
      @moon_cron.parse_utc_datetime("2026-07-27T14:00Z").unwrap(),
    ).unwrap(),
    reason="maintenance",
  )
  @moon_cron.SchedulePolicy::new(cron).unwrap().add_blackout(blackout)
}

///|
test "policy explains scheduled excluded and included minutes" {
  let policy = policy_fixture()
  let morning = @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap()
  let noon = @moon_cron.parse_utc_datetime("2026-07-27T12:00Z").unwrap()
  assert_eq(policy.decision_at(morning), @moon_cron.Scheduled)
  assert_eq(policy.decision_at(noon), @moon_cron.Excluded("maintenance"))
  let included = policy.add_inclusion(
    @moon_cron.ScheduleInclusion::new(noon, reason="manual override"),
  )
  assert_eq(included.decision_at(noon), @moon_cron.Included("manual override"))
}

///|
test "policy jumps across blackout boundaries" {
  let policy = policy_fixture()
  let cursor = @moon_cron.parse_utc_datetime("2026-07-27T11:00Z").unwrap()
  assert_eq(
    policy.next_after(cursor).unwrap().to_iso8601(),
    "2026-07-27T15:00Z",
  )
  let after = @moon_cron.parse_utc_datetime("2026-07-27T15:30Z").unwrap()
  assert_eq(
    policy.previous_before(after).unwrap().to_iso8601(),
    "2026-07-27T15:00Z",
  )
}

///|
test "disabled policy still permits explicit inclusions" {
  let at = @moon_cron.parse_utc_datetime("2026-07-27T10:15Z").unwrap()
  let policy = policy_fixture()
    .with_enabled(false)
    .add_inclusion(@moon_cron.ScheduleInclusion::new(at, reason="one-off"))
  assert_true(policy.matches_at(at))
  assert_eq(
    policy.next_on_or_after(at).unwrap().to_iso8601(),
    "2026-07-27T10:15Z",
  )
}

///|
test "policy audit measures suppressed and included occurrences" {
  let start = @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap()
  let end = @moon_cron.parse_utc_datetime("2026-07-27T17:00Z").unwrap()
  let range = @moon_cron.DateTimeRange::new(start, end).unwrap()
  let policy = policy_fixture().add_inclusion(
    @moon_cron.ScheduleInclusion::new(
      @moon_cron.parse_utc_datetime("2026-07-27T12:30Z").unwrap(),
    ),
  )
  let audit = policy.audit(range)
  assert_eq(audit.base_occurrences, 9)
  assert_eq(audit.suppressed_occurrences, 3)
  assert_eq(audit.included_occurrences, 1)
  assert_eq(audit.effective_occurrences, 7)
}
