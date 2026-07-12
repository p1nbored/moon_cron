///|
/// The position of a field inside a five-field cron expression. Each
/// position carries its own numeric bounds and, for month and weekday,
/// a table of accepted names.
priv enum FieldKind {
  MinuteField
  HourField
  DayOfMonthField
  MonthField
  WeekdayField
}

///|
/// Inclusive bounds of the values a field position accepts. The weekday
/// upper bound is 7 because standard cron treats both 0 and 7 as Sunday.
fn FieldKind::bounds(self : FieldKind) -> (Int, Int) {
  match self {
    MinuteField => (0, 59)
    HourField => (0, 23)
    DayOfMonthField => (1, 31)
    MonthField => (1, 12)
    WeekdayField => (0, 7)
  }
}

///|
let month_names : Array[(String, Int)] = [
  ("JAN", 1),
  ("FEB", 2),
  ("MAR", 3),
  ("APR", 4),
  ("MAY", 5),
  ("JUN", 6),
  ("JUL", 7),
  ("AUG", 8),
  ("SEP", 9),
  ("OCT", 10),
  ("NOV", 11),
  ("DEC", 12),
  ("JANUARY", 1),
  ("FEBRUARY", 2),
  ("MARCH", 3),
  ("APRIL", 4),
  ("JUNE", 6),
  ("JULY", 7),
  ("AUGUST", 8),
  ("SEPTEMBER", 9),
  ("OCTOBER", 10),
  ("NOVEMBER", 11),
  ("DECEMBER", 12),
]

///|
let weekday_names : Array[(String, Int)] = [
  ("SUN", 0),
  ("MON", 1),
  ("TUE", 2),
  ("WED", 3),
  ("THU", 4),
  ("FRI", 5),
  ("SAT", 6),
  ("SUNDAY", 0),
  ("MONDAY", 1),
  ("TUESDAY", 2),
  ("WEDNESDAY", 3),
  ("THURSDAY", 4),
  ("FRIDAY", 5),
  ("SATURDAY", 6),
]

///|
/// UTF-16 code units of the text with ASCII lowercase folded to uppercase.
fn ascii_upper_codes(text : String) -> Array[Int] {
  let codes : Array[Int] = []
  for char in text {
    let code = char.to_int()
    if code >= 97 && code <= 122 {
      codes.push(code - 32)
    } else {
      codes.push(code)
    }
  }
  codes
}

///|
fn equals_ignore_case(text : String, name : String) -> Bool {
  ascii_upper_codes(text) == ascii_upper_codes(name)
}

///|
fn lookup_name(text : String, table : Array[(String, Int)]) -> Int? {
  for entry in table {
    if equals_ignore_case(text, entry.0) {
      return Some(entry.1)
    }
  }
  None
}

///|
fn FieldKind::resolve_name(self : FieldKind, text : String) -> Int? {
  match self {
    MonthField => lookup_name(text, month_names)
    WeekdayField => lookup_name(text, weekday_names)
    _ => None
  }
}

///|
fn is_alphabetic(text : String) -> Bool {
  if text.length() == 0 {
    return false
  }
  for char in text {
    let code = char.to_int()
    let is_upper = code >= 65 && code <= 90
    let is_lower = code >= 97 && code <= 122
    if !is_upper && !is_lower {
      return false
    }
  }
  true
}

///|
/// Parse a decimal number and check it against the inclusive bounds.
/// Accumulation bails out as soon as the value exceeds the upper bound, so
/// oversized inputs cannot wrap around the integer range.
fn bounded_number(
  text : String,
  lower : Int,
  upper : Int,
) -> Result[Int, CronError] {
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
    if value > upper {
      return Err(ValueOutOfRange(text, lower, upper))
    }
  }
  if value < lower {
    return Err(ValueOutOfRange(text, lower, upper))
  }
  Ok(value)
}

///|
/// Resolve a single value: a month or weekday name where the field allows
/// one, otherwise a bounds-checked number.
fn bounded_value(text : String, kind : FieldKind) -> Result[Int, CronError] {
  let (lower, upper) = kind.bounds()
  match kind.resolve_name(text) {
    Some(value) => Ok(value)
    None =>
      if is_alphabetic(text) {
        Err(UnknownName(text))
      } else {
        bounded_number(text, lower, upper)
      }
  }
}

///|
fn parse_range(
  text : String,
  kind : FieldKind,
) -> Result[(Int, Int), CronError] {
  match text.split_once("-") {
    Some((start_view, end_view)) => {
      let start_text = start_view.to_owned()
      let end_text = end_view.to_owned()
      match (bounded_value(start_text, kind), bounded_value(end_text, kind)) {
        (Ok(start), Ok(end)) if start <= end => Ok((start, end))
        (Ok(_), Ok(_)) => Err(InvalidRange(text))
        (Err(error), _) => Err(error)
        (_, Err(error)) => Err(error)
      }
    }
    None => Err(UnsupportedSyntax(text))
  }
}

///|
/// Parse one list element: `*`, a value or name, `a-b`, `*/n`, `a-b/n` or
/// the Vixie-style `a/n` which runs from `a` to the top of the field.
fn parse_element(text : String, kind : FieldKind) -> Result[Field, CronError] {
  let (lower, upper) = kind.bounds()
  if text == "*" {
    return Ok(Any)
  }
  match text.split_once("/") {
    Some((base_view, step_view)) => {
      let base = base_view.to_owned()
      let step_text = step_view.to_owned()
      match bounded_number(step_text, 1, upper - lower + 1) {
        Err(error) => Err(error)
        Ok(step) =>
          if base == "*" {
            Ok(Every(step))
          } else if base.split_once("-") is Some(_) {
            parse_range(base, kind).map(bounds => {
              RangeEvery(bounds.0, bounds.1, step)
            })
          } else {
            bounded_value(base, kind).map(start => {
              RangeEvery(start, upper, step)
            })
          }
      }
    }
    None =>
      if text.split_once("-") is Some(_) {
        parse_range(text, kind).map(bounds => Range(bounds.0, bounds.1))
      } else {
        bounded_value(text, kind).map(value => Exact(value))
      }
  }
}

///|
/// Parse a whole field, which may be a comma-separated list of elements.
fn parse_field(text : String, kind : FieldKind) -> Result[Field, CronError] {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_owned())
  }
  if parts.length() == 1 {
    return parse_element(parts[0], kind)
  }
  let items : Array[Field] = []
  for part in parts {
    match parse_element(part, kind) {
      Ok(field) => items.push(field)
      Err(error) => return Err(error)
    }
  }
  Ok(List(items))
}

///|
/// Split an expression into whitespace-separated fields. Spaces and tabs
/// separate fields as in crontab files; stray newlines are tolerated.
fn tokenize(expression : String) -> Array[String] {
  let fields : Array[String] = []
  let mut current = StringBuilder::new()
  let mut pending = false
  for char in expression {
    if char == ' ' || char == '\t' || char == '\n' || char == '\r' {
      if pending {
        fields.push(current.to_string())
        current = StringBuilder::new()
        pending = false
      }
    } else {
      current.write_char(char)
      pending = true
    }
  }
  if pending {
    fields.push(current.to_string())
  }
  fields
}

///|
fn starts_with_at(text : String) -> Bool {
  for char in text {
    return char == '@'
  }
  false
}

///|
/// Expand a `@`-prefixed scheduling macro into its five-field schedule.
/// `@reboot` has no wall-clock meaning and is reported as unsupported.
fn parse_macro(text : String) -> Result[Cron, CronError] {
  if equals_ignore_case(text, "@HOURLY") {
    Ok({
      minute: Exact(0),
      hour: Any,
      day_of_month: Any,
      month: Any,
      weekday: Any,
    })
  } else if equals_ignore_case(text, "@DAILY") ||
    equals_ignore_case(text, "@MIDNIGHT") {
    Ok({
      minute: Exact(0),
      hour: Exact(0),
      day_of_month: Any,
      month: Any,
      weekday: Any,
    })
  } else if equals_ignore_case(text, "@WEEKLY") {
    Ok({
      minute: Exact(0),
      hour: Exact(0),
      day_of_month: Any,
      month: Any,
      weekday: Exact(0),
    })
  } else if equals_ignore_case(text, "@MONTHLY") {
    Ok({
      minute: Exact(0),
      hour: Exact(0),
      day_of_month: Exact(1),
      month: Any,
      weekday: Any,
    })
  } else if equals_ignore_case(text, "@YEARLY") ||
    equals_ignore_case(text, "@ANNUALLY") {
    Ok({
      minute: Exact(0),
      hour: Exact(0),
      day_of_month: Exact(1),
      month: Exact(1),
      weekday: Any,
    })
  } else {
    Err(UnsupportedSyntax(text))
  }
}

///|
/// Parse the portable cron subset: five whitespace-separated fields built
/// from `*`, numbers, month and weekday names, ranges (`a-b`), steps
/// (`*/n`, `a-b/n`, `a/n`) and comma lists, plus `@hourly`-style macros.
pub fn parse(expression : String) -> Result[Cron, CronError] {
  let fields = tokenize(expression)
  if fields.length() == 1 && starts_with_at(fields[0]) {
    return parse_macro(fields[0])
  }
  if fields.length() != 5 {
    return Err(WrongFieldCount(fields.length()))
  }
  match
    (
      parse_field(fields[0], MinuteField),
      parse_field(fields[1], HourField),
      parse_field(fields[2], DayOfMonthField),
      parse_field(fields[3], MonthField),
      parse_field(fields[4], WeekdayField),
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
