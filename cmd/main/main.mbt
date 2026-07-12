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
}
