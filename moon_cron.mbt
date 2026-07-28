///|
/// A clock value expressed in UTC. `weekday` uses cron's conventional values:
/// Sunday is 0 and Saturday is 6.
pub struct UtcTime {
  minute : Int
  hour : Int
  day_of_month : Int
  month : Int
  weekday : Int
} derive(Eq, Debug)

///|
pub fn UtcTime::new(
  minute : Int,
  hour : Int,
  day_of_month : Int,
  month : Int,
  weekday : Int,
) -> UtcTime {
  { minute, hour, day_of_month, month, weekday }
}

///|
/// One field of a cron schedule. `Every` counts from the lowest value the
/// field allows, so `*/2` in the day-of-month field means days 1, 3, 5 and
/// so on, matching standard cron behaviour.
pub enum Field {
  Any
  Exact(Int)
  Every(Int)
  Range(Int, Int)
  RangeEvery(Int, Int, Int)
  List(Array[Field])
} derive(Eq, Debug)

///|
pub enum CronError {
  WrongFieldCount(Int)
  InvalidNumber(String)
  UnknownName(String)
  ValueOutOfRange(String, Int, Int)
  InvalidRange(String)
  UnsupportedSyntax(String)
  InvalidDate(String)
  InvalidField(String)
  InvalidWindow(String)
} derive(Eq, Debug)

///|
/// A five-field cron schedule: minute, hour, day-of-month, month and weekday.
pub struct Cron {
  minute : Field
  hour : Field
  day_of_month : Field
  month : Field
  weekday : Field
} derive(Eq, Debug)

///|
/// Check whether a value satisfies this field. `lower` is the smallest value
/// the field position allows; `Every` steps count from it, so pass `lower=1`
/// for day-of-month and month fields.
pub fn Field::matches(self : Field, value : Int, lower? : Int = 0) -> Bool {
  match self {
    Any => true
    Exact(expected) => value == expected
    Every(step) => value >= lower && (value - lower) % step == 0
    Range(start, end) => value >= start && value <= end
    RangeEvery(start, end, step) =>
      value >= start && value <= end && (value - start) % step == 0
    List(items) => {
      for item in items {
        if item.matches(value, lower~) {
          return true
        }
      }
      false
    }
  }
}

///|
/// Render a field in the portable expression subset accepted by `parse`.
pub fn Field::to_expression(self : Field) -> String {
  match self {
    Any => "*"
    Exact(value) => value.to_string()
    Every(step) => "*/" + step.to_string()
    Range(start, end) => start.to_string() + "-" + end.to_string()
    RangeEvery(start, end, step) =>
      start.to_string() + "-" + end.to_string() + "/" + step.to_string()
    List(items) => {
      let writer = StringBuilder::new()
      let mut first = true
      for item in items {
        if !first {
          writer.write_char(',')
        }
        writer.write_string(item.to_expression())
        first = false
      }
      writer.to_string()
    }
  }
}

///|
/// True when this schedule's weekday field accepts the given weekday.
/// Sunday may be written as either 0 or 7, so both spellings are honoured.
fn Cron::weekday_field_matches(self : Cron, weekday : Int) -> Bool {
  self.weekday.matches(weekday) ||
  (weekday == 0 && self.weekday.matches(7)) ||
  (weekday == 7 && self.weekday.matches(0))
}

///|
/// Apply cron's calendar rule: when both day-of-month and weekday are
/// restricted, a date matches if either field matches (the OR rule).
fn Cron::calendar_matches(
  self : Cron,
  day_of_month : Int,
  weekday : Int,
) -> Bool {
  let day_matches = self.day_of_month.matches(day_of_month, lower=1)
  let weekday_matches = self.weekday_field_matches(weekday)
  match (self.day_of_month, self.weekday) {
    (Any, Any) => true
    (Any, _) => weekday_matches
    (_, Any) => day_matches
    _ => day_matches || weekday_matches
  }
}

///|
/// Check whether a UTC wall-clock minute satisfies this schedule. When both
/// day-of-month and weekday are restricted, standard cron's OR rule is used.
pub fn Cron::matches(self : Cron, time : UtcTime) -> Bool {
  self.minute.matches(time.minute) &&
  self.hour.matches(time.hour) &&
  self.month.matches(time.month, lower=1) &&
  self.calendar_matches(time.day_of_month, time.weekday)
}

///|
pub fn Cron::to_expression(self : Cron) -> String {
  let writer = StringBuilder::new()
  writer.write_string(self.minute.to_expression())
  writer.write_char(' ')
  writer.write_string(self.hour.to_expression())
  writer.write_char(' ')
  writer.write_string(self.day_of_month.to_expression())
  writer.write_char(' ')
  writer.write_string(self.month.to_expression())
  writer.write_char(' ')
  writer.write_string(self.weekday.to_expression())
  writer.to_string()
}

///|
/// A schedule that fires at minute zero of every hour.
pub fn hourly() -> Cron {
  { minute: Exact(0), hour: Any, day_of_month: Any, month: Any, weekday: Any }
}

///|
/// A schedule that fires at minute zero on every weekday hour.
pub fn weekday_hourly() -> Cron {
  {
    minute: Exact(0),
    hour: Any,
    day_of_month: Any,
    month: Any,
    weekday: Range(1, 5),
  }
}
