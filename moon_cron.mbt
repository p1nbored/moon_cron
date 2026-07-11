///|
/// A clock value expressed in UTC. `weekday` uses cron's conventional values:
/// Sunday is 0 and Saturday is 6.
pub struct UtcTime {
  pub minute : Int
  pub hour : Int
  pub day_of_month : Int
  pub month : Int
  pub weekday : Int
} derive(Eq, Debug)

///|
pub enum Field {
  Any
  Exact(Int)
  Every(Int)
  Range(Int, Int)
  RangeEvery(Int, Int, Int)
} derive(Eq, Debug)

///|
pub enum CronError {
  WrongFieldCount(Int)
  InvalidNumber(String)
  ValueOutOfRange(String, Int, Int)
  InvalidRange(String)
  InvalidStep(String)
  UnsupportedSyntax(String)
} derive(Eq, Debug)

///|
/// A five-field cron schedule: minute, hour, day-of-month, month and weekday.
pub struct Cron {
  pub minute : Field
  pub hour : Field
  pub day_of_month : Field
  pub month : Field
  pub weekday : Field
} derive(Eq, Debug)

///|
fn parse_number(text : String) -> Result[Int, CronError] {
  if text.length() == 0 {
    return Err(InvalidNumber(text))
  }
  let mut value = 0
  for char in text {
    let code = char.to_int()
    if code < 48 || code > 57 {
      return Err(InvalidNumber(text))
    }
    value = value * 10 + code - 48
  }
  Ok(value)
}

///|
fn bounded_number(
  text : String,
  lower : Int,
  upper : Int,
) -> Result[Int, CronError] {
  match parse_number(text) {
    Ok(value) if value >= lower && value <= upper => Ok(value)
    Ok(_) => Err(ValueOutOfRange(text, lower, upper))
    Err(error) => Err(error)
  }
}

///|
fn parse_field(
  text : String,
  lower : Int,
  upper : Int,
) -> Result[Field, CronError] {
  if text == "*" {
    return Ok(Any)
  }
  match text.split_once("/") {
    Some((base, step_text)) => {
      let step_text = step_text.to_owned()
      match bounded_number(step_text, 1, upper - lower + 1) {
        Err(error) => Err(error)
        Ok(step) => {
          let base = base.to_owned()
          if base == "*" {
            Ok(Every(step))
          } else {
            match base.split_once("-") {
              Some((start, end)) => {
                let start_text = start.to_owned()
                let end_text = end.to_owned()
                match
                  (
                    bounded_number(start_text, lower, upper),
                    bounded_number(end_text, lower, upper),
                  ) {
                  (Ok(start), Ok(end)) if start <= end =>
                    Ok(RangeEvery(start, end, step))
                  (Ok(_), Ok(_)) => Err(InvalidRange(base))
                  (Err(error), _) => Err(error)
                  (_, Err(error)) => Err(error)
                }
              }
              None => Err(UnsupportedSyntax(text))
            }
          }
        }
      }
    }
    None =>
      match text.split_once("-") {
        Some((start, end)) => {
          let start_text = start.to_owned()
          let end_text = end.to_owned()
          match
            (
              bounded_number(start_text, lower, upper),
              bounded_number(end_text, lower, upper),
            ) {
            (Ok(start), Ok(end)) if start <= end => Ok(Range(start, end))
            (Ok(_), Ok(_)) => Err(InvalidRange(text))
            (Err(error), _) => Err(error)
            (_, Err(error)) => Err(error)
          }
        }
        None => bounded_number(text, lower, upper).map(value => Exact(value))
      }
  }
}

///|
/// Parse the portable five-field cron subset: `*`, numbers, `a-b`, `*/n`, and
/// `a-b/n`. Lists, names and timezone handling are intentionally future work.
pub fn parse(expression : String) -> Result[Cron, CronError] {
  let fields : Array[String] = []
  for part in expression.trim().split(" ") {
    let text = part.to_owned()
    if text.length() > 0 {
      fields.push(text)
    }
  }
  if fields.length() != 5 {
    return Err(WrongFieldCount(fields.length()))
  }
  match
    (
      parse_field(fields[0], 0, 59),
      parse_field(fields[1], 0, 23),
      parse_field(fields[2], 1, 31),
      parse_field(fields[3], 1, 12),
      parse_field(fields[4], 0, 6),
    ) {
    (Ok(minute), Ok(hour), Ok(day_of_month), Ok(month), Ok(weekday)) =>
      Ok({ minute, hour, day_of_month, month, weekday })
    (Err(error), _, _, _, _) => Err(error)
    (_, Err(error), _, _, _) => Err(error)
    (_, _, Err(error), _, _) => Err(error)
    (_, _, _, Err(error), _) => Err(error)
    (_, _, _, _, Err(error)) => Err(error)
  }
}
