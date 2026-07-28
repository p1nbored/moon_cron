///|
test "crontab parses comments variables macros and commands" {
  let source =
    #|# production jobs
    #|SHELL=/bin/sh
    #|PATH=/usr/bin:/bin
    #|*/15 9-17 * * MON-FRI backup --incremental
    #|@daily cleanup --older-than 30
  let document = @moon_cron.parse_crontab(source).unwrap()
  assert_eq(document.comment_count(), 1)
  assert_eq(document.variable_count(), 2)
  assert_eq(document.entry_count(), 2)
  assert_eq(document.variable("SHELL"), Some("/bin/sh"))
  assert_eq(document.find_commands("backup").length(), 1)
  assert_eq(document.entries()[1].schedule_text, "@daily")
}

///|
test "crontab due query and schedule book conversion" {
  let document = @moon_cron.parse_crontab(
    "0 9 * * MON-FRI open-office\n*/30 9 * * MON-FRI heartbeat",
  ).unwrap()
  let at = @moon_cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap()
  let due = document.due_at(at)
  assert_eq(due.length(), 2)
  assert_eq(due[0].command, "open-office")
  let book = document.to_schedule_book()
  assert_eq(book.length(), 2)
  assert_true(book.contains("line-1"))
}

///|
test "crontab reports the invalid source line" {
  let result = @moon_cron.parse_crontab(
    "SHELL=/bin/sh\n0 9 * * MON-FRI valid\ninvalid line",
  )
  match result {
    Err(@moon_cron.InvalidCrontabLine(line, _)) => assert_eq(line, 3)
    _ => fail("expected line-aware parse error")
  }
}

///|
test "crontab compact and normalized rendering are stable" {
  let source = "# header\n\nMAILTO=ops@example.com\n@hourly ping service"
  let document = @moon_cron.parse_crontab(source).unwrap()
  assert_eq(
    document.to_text(),
    "# header\n\nMAILTO=ops@example.com\n@hourly ping service",
  )
  assert_eq(
    document.compact().to_text(),
    "MAILTO=ops@example.com\n@hourly ping service",
  )
}
