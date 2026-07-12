///|
fn checked(value : Int, lower : Int, upper : Int) -> Result[Int, CronError] {
  if value >= lower && value <= upper {
    Ok(value)
  } else {
    Err(ValueOutOfRange(value.to_string(), lower, upper))
  }
}

///|
/// A schedule that fires every minute.
pub fn every_minute() -> Cron {
  { minute: Any, hour: Any, day_of_month: Any, month: Any, weekday: Any }
}

///|
/// A schedule that fires once a day at the given wall-clock time.
pub fn daily_at(hour : Int, minute : Int) -> Result[Cron, CronError] {
  match (checked(hour, 0, 23), checked(minute, 0, 59)) {
    (Ok(hour), Ok(minute)) =>
      Ok({
        minute: Exact(minute),
        hour: Exact(hour),
        day_of_month: Any,
        month: Any,
        weekday: Any,
      })
    (Err(error), _) => Err(error)
    (_, Err(error)) => Err(error)
  }
}

///|
/// A schedule that fires once a week. The weekday accepts 0 through 7;
/// both 0 and 7 mean Sunday and are stored canonically as 0.
pub fn weekly_on(
  weekday : Int,
  hour : Int,
  minute : Int,
) -> Result[Cron, CronError] {
  match (checked(weekday, 0, 7), checked(hour, 0, 23), checked(minute, 0, 59)) {
    (Ok(weekday), Ok(hour), Ok(minute)) => {
      let canonical = if weekday == 7 { 0 } else { weekday }
      Ok({
        minute: Exact(minute),
        hour: Exact(hour),
        day_of_month: Any,
        month: Any,
        weekday: Exact(canonical),
      })
    }
    (Err(error), _, _) => Err(error)
    (_, Err(error), _) => Err(error)
    (_, _, Err(error)) => Err(error)
  }
}

///|
/// A schedule that fires once a month on the given day. Days 29 through
/// 31 simply skip months that are too short, as in standard cron.
pub fn monthly_on(
  day : Int,
  hour : Int,
  minute : Int,
) -> Result[Cron, CronError] {
  match (checked(day, 1, 31), checked(hour, 0, 23), checked(minute, 0, 59)) {
    (Ok(day), Ok(hour), Ok(minute)) =>
      Ok({
        minute: Exact(minute),
        hour: Exact(hour),
        day_of_month: Exact(day),
        month: Any,
        weekday: Any,
      })
    (Err(error), _, _) => Err(error)
    (_, Err(error), _) => Err(error)
    (_, _, Err(error)) => Err(error)
  }
}
