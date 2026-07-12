///|
/// Display names indexed by cron weekday value; index 7 is Sunday again so
/// both spellings of Sunday render identically.
let weekday_display : Array[String] = [
  "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
]

///|
let month_display : Array[String] = [
  "January", "February", "March", "April", "May", "June", "July", "August", "September",
  "October", "November", "December",
]

///|
fn weekday_name(value : Int) -> String {
  if value >= 0 && value <= 7 {
    weekday_display[value]
  } else {
    value.to_string()
  }
}

///|
fn month_name(value : Int) -> String {
  if value >= 1 && value <= 12 {
    month_display[value - 1]
  } else {
    value.to_string()
  }
}

///|
fn ordinal(value : Int) -> String {
  let remainder = value % 100
  let suffix = if remainder >= 11 && remainder <= 13 {
    "th"
  } else {
    match value % 10 {
      1 => "st"
      2 => "nd"
      3 => "rd"
      _ => "th"
    }
  }
  value.to_string() + suffix
}

///|
/// Join phrases as English prose: "a", "a and b", "a, b and c".
fn join_and(parts : Array[String]) -> String {
  match parts.length() {
    0 => ""
    1 => parts[0]
    _ => {
      let writer = StringBuilder::new()
      for index in 0..<(parts.length() - 1) {
        if index > 0 {
          writer.write_string(", ")
        }
        writer.write_string(parts[index])
      }
      writer.write_string(" and ")
      writer.write_string(parts[parts.length() - 1])
      writer.to_string()
    }
  }
}

///|
/// The values of a list whose elements are all exact, or `None`.
fn exact_values(items : Array[Field]) -> Array[Int]? {
  let values : Array[Int] = []
  for item in items {
    match item {
      Exact(value) => values.push(value)
      _ => return None
    }
  }
  Some(values)
}

///|
fn minute_item(field : Field) -> String {
  match field {
    Any => "every minute"
    Exact(value) => "at minute " + value.to_string()
    Every(1) => "every minute"
    Every(step) => "every " + step.to_string() + " minutes"
    Range(start, end) =>
      "every minute from " + start.to_string() + " through " + end.to_string()
    RangeEvery(start, end, 1) =>
      "every minute from " + start.to_string() + " through " + end.to_string()
    RangeEvery(start, end, step) =>
      "every " +
      step.to_string() +
      " minutes from " +
      start.to_string() +
      " through " +
      end.to_string()
    List(items) =>
      match exact_values(items) {
        Some(values) =>
          if values.length() == 1 {
            "at minute " + values[0].to_string()
          } else {
            "at minutes " + join_and(values.map(value => value.to_string()))
          }
        None => join_and(items.map(item => minute_item(item)))
      }
  }
}

///|
fn hour_item(field : Field) -> String {
  match field {
    Any => "every hour"
    Exact(value) => "hour " + value.to_string()
    Every(1) => "every hour"
    Every(step) => "every " + ordinal(step) + " hour"
    Range(start, end) =>
      "hours " + start.to_string() + " through " + end.to_string()
    RangeEvery(start, end, 1) =>
      "hours " + start.to_string() + " through " + end.to_string()
    RangeEvery(start, end, step) =>
      "every " +
      ordinal(step) +
      " hour from " +
      start.to_string() +
      " through " +
      end.to_string()
    List(items) =>
      match exact_values(items) {
        Some(values) =>
          if values.length() == 1 {
            "hour " + values[0].to_string()
          } else {
            "hours " + join_and(values.map(value => value.to_string()))
          }
        None => join_and(items.map(item => hour_item(item)))
      }
  }
}

///|
fn day_of_month_item(field : Field) -> String {
  match field {
    Any => "every day"
    Exact(value) => "day " + value.to_string()
    Every(1) => "every day"
    Every(step) => "every " + ordinal(step) + " day"
    Range(start, end) =>
      "days " + start.to_string() + " through " + end.to_string()
    RangeEvery(start, end, 1) =>
      "days " + start.to_string() + " through " + end.to_string()
    RangeEvery(start, end, step) =>
      "every " +
      ordinal(step) +
      " day from " +
      start.to_string() +
      " through " +
      end.to_string()
    List(items) =>
      match exact_values(items) {
        Some(values) =>
          if values.length() == 1 {
            "day " + values[0].to_string()
          } else {
            "days " + join_and(values.map(value => value.to_string()))
          }
        None => join_and(items.map(item => day_of_month_item(item)))
      }
  }
}

///|
fn weekday_item(field : Field) -> String {
  match field {
    Any => "every day of the week"
    Exact(value) => weekday_name(value)
    Every(1) => "every day of the week"
    Every(step) => "every " + ordinal(step) + " day of the week"
    Range(start, end) => weekday_name(start) + " through " + weekday_name(end)
    RangeEvery(start, end, 1) =>
      weekday_name(start) + " through " + weekday_name(end)
    RangeEvery(start, end, step) =>
      "every " +
      ordinal(step) +
      " day of the week from " +
      weekday_name(start) +
      " through " +
      weekday_name(end)
    List(items) =>
      match exact_values(items) {
        Some(values) => join_and(values.map(value => weekday_name(value)))
        None => join_and(items.map(item => weekday_item(item)))
      }
  }
}

///|
fn month_item(field : Field) -> String {
  match field {
    Any => "every month"
    Exact(value) => month_name(value)
    Every(1) => "every month"
    Every(step) => "every " + ordinal(step) + " month"
    Range(start, end) => month_name(start) + " through " + month_name(end)
    RangeEvery(start, end, 1) =>
      month_name(start) + " through " + month_name(end)
    RangeEvery(start, end, step) =>
      "every " +
      ordinal(step) +
      " month from " +
      month_name(start) +
      " through " +
      month_name(end)
    List(items) =>
      match exact_values(items) {
        Some(values) => join_and(values.map(value => month_name(value)))
        None => join_and(items.map(item => month_item(item)))
      }
  }
}

///|
/// Render the schedule as an English sentence fragment, for example
/// "every 15 minutes past hours 9 through 17 on Monday through Friday".
/// When both day fields are restricted the wording mirrors cron's OR rule.
pub fn Cron::describe(self : Cron) -> String {
  let writer = StringBuilder::new()
  writer.write_string(minute_item(self.minute))
  if !(self.minute is Any && self.hour is Any) {
    writer.write_string(" past ")
    writer.write_string(hour_item(self.hour))
  }
  match (self.day_of_month, self.weekday) {
    (Any, Any) => ()
    (Any, _) => {
      writer.write_string(" on ")
      writer.write_string(weekday_item(self.weekday))
    }
    (_, Any) => {
      writer.write_string(" on ")
      writer.write_string(day_of_month_item(self.day_of_month))
      writer.write_string(" of the month")
    }
    _ => {
      writer.write_string(" on ")
      writer.write_string(day_of_month_item(self.day_of_month))
      writer.write_string(" of the month or on ")
      writer.write_string(weekday_item(self.weekday))
    }
  }
  if !(self.month is Any) {
    writer.write_string(" in ")
    writer.write_string(month_item(self.month))
  }
  writer.to_string()
}
