///|
fn main {
  match @cron.parse("*/30 9-17 * * 1-5") {
    Ok(schedule) => {
      let sample = @cron.UtcTime::new(30, 9, 6, 7, 1)
      let result = if schedule.matches(sample) {
        "scheduled"
      } else {
        "not scheduled"
      }
      println("2026-07-06 09:30 UTC is \{result}")
    }
    Err(_) => println("invalid built-in example")
  }
}
