///|
fn pad(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn render(occurrence : @cron.UtcDateTime) -> String {
  occurrence.year.to_string() +
  "-" +
  pad(occurrence.month) +
  "-" +
  pad(occurrence.day) +
  " " +
  pad(occurrence.hour) +
  ":" +
  pad(occurrence.minute) +
  " UTC"
}

///|
fn main {
  match @cron.parse("*/30 9-17 * * MON-FRI") {
    Ok(schedule) => {
      println("expression : \{schedule.to_expression()}")
      println("meaning    : \{schedule.describe()}")
      match @cron.UtcDateTime::new(2026, 7, 6, 9, 30) {
        Ok(now) => {
          let state = if schedule.matches_at(now) { "due" } else { "idle" }
          println("at \{render(now)} the schedule is \{state}")
          for occurrence in schedule.next_occurrences(now, 3) {
            println("next       : \{render(occurrence)}")
          }
        }
        Err(_) => println("invalid built-in date")
      }
    }
    Err(_) => println("invalid built-in example")
  }
  let document = @cron.parse_crontab(
    (
      #|SHELL=/bin/sh
      #|*/15 9-17 * * MON-FRI collect-metrics
      #|0 9-17 * * MON-FRI refresh-dashboard
    ),
  ).unwrap()
  println("\ncrontab entries: \{document.entry_count()}")
  println("shell          : \{document.variable("SHELL").unwrap()}")
  let book = document.to_schedule_book()
  let report_range = @cron.DateTimeRange::new(
    @cron.parse_utc_datetime("2026-07-27T09:00Z").unwrap(),
    @cron.parse_utc_datetime("2026-07-27T10:00Z").unwrap(),
  ).unwrap()
  println("\n\{book.report(report_range).to_text()}")
}
