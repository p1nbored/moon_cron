///|
/// A calendar-only value in the proleptic Gregorian calendar.
pub struct UtcDate {
  year : Int
  month : Int
  day : Int
} derive(Eq, Compare, Debug)

///|
/// Construct a validated UTC calendar date.
pub fn UtcDate::new(
  year : Int,
  month : Int,
  day : Int,
) -> Result[UtcDate, CronError] {
  match UtcDateTime::new(year, month, day, 0, 0) {
    Ok(_) => Ok({ year, month, day })
    Err(error) => Err(error)
  }
}

///|
/// Convert a date-time to its calendar date.
pub fn UtcDateTime::date(self : UtcDateTime) -> UtcDate {
  { year: self.year, month: self.month, day: self.day }
}

///|
/// Start of this calendar date.
pub fn UtcDate::start(self : UtcDate) -> UtcDateTime {
  { year: self.year, month: self.month, day: self.day, hour: 0, minute: 0 }
}

///|
/// Last minute of this calendar date.
pub fn UtcDate::end(self : UtcDate) -> UtcDateTime {
  { year: self.year, month: self.month, day: self.day, hour: 23, minute: 59 }
}

///|
/// Create a date-time on this date with a validated hour and minute.
pub fn UtcDate::at(
  self : UtcDate,
  hour : Int,
  minute : Int,
) -> Result[UtcDateTime, CronError] {
  UtcDateTime::new(self.year, self.month, self.day, hour, minute)
}

///|
fn days_before_year(year : Int) -> Int {
  let previous = year - 1
  previous * 365 + previous / 4 - previous / 100 + previous / 400
}

///|
fn days_before_month(year : Int, month : Int) -> Int {
  let cumulative = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
  let base = cumulative[month - 1]
  if month > 2 && is_leap_year(year) {
    base + 1
  } else {
    base
  }
}

///|
/// Zero-based Gregorian ordinal, where 0001-01-01 is day zero.
fn UtcDate::ordinal(self : UtcDate) -> Int {
  days_before_year(self.year) +
  days_before_month(self.year, self.month) +
  self.day -
  1
}

///|
/// Number of whole calendar days from `self` to `other`.
pub fn UtcDate::days_until(self : UtcDate, other : UtcDate) -> Int {
  other.ordinal() - self.ordinal()
}

///|
fn date_from_ordinal(ordinal : Int) -> UtcDate? {
  if ordinal < 0 || ordinal > days_before_year(10000) - 1 {
    return None
  }
  let mut low = 1
  let mut high = 10000
  for ;; {
    if low >= high {
      break
    }
    let middle = low + (high - low) / 2
    if days_before_year(middle) <= ordinal {
      low = middle + 1
    } else {
      high = middle
    }
  }
  let year = low - 1
  let day_of_year = ordinal - days_before_year(year)
  let mut month = 1
  for ;; {
    if month > 12 || day_of_year < days_before_month(year, month) {
      break
    }
    if month == 12 || day_of_year < days_before_month(year, month + 1) {
      break
    }
    month += 1
  }
  let day = day_of_year - days_before_month(year, month) + 1
  Some({ year, month, day })
}

///|
/// Add signed calendar days, returning `None` outside years 1 through 9999.
pub fn UtcDate::add_days(self : UtcDate, amount : Int) -> UtcDate? {
  date_from_ordinal(self.ordinal() + amount)
}

///|
/// Add signed calendar days while preserving the wall-clock time.
pub fn UtcDateTime::add_days(self : UtcDateTime, amount : Int) -> UtcDateTime? {
  match self.date().add_days(amount) {
    Some(date) =>
      Some({
        year: date.year,
        month: date.month,
        day: date.day,
        hour: self.hour,
        minute: self.minute,
      })
    None => None
  }
}

///|
fn floor_div(value : Int, divisor : Int) -> Int {
  if value >= 0 {
    value / divisor
  } else {
    -((-value + divisor - 1) / divisor)
  }
}

///|
fn positive_mod(value : Int, divisor : Int) -> Int {
  let remainder = value % divisor
  if remainder < 0 {
    remainder + divisor
  } else {
    remainder
  }
}

///|
/// Add signed minutes, carrying across all calendar boundaries.
pub fn UtcDateTime::add_minutes(
  self : UtcDateTime,
  amount : Int,
) -> UtcDateTime? {
  let minute_of_day = self.hour * 60 + self.minute
  let total = minute_of_day + amount
  let day_delta = floor_div(total, 1440)
  let target_minute = positive_mod(total, 1440)
  match self.date().add_days(day_delta) {
    Some(date) =>
      Some({
        year: date.year,
        month: date.month,
        day: date.day,
        hour: target_minute / 60,
        minute: target_minute % 60,
      })
    None => None
  }
}

///|
/// Signed minute distance from `self` to `other`.
///
/// Intended for operational windows rather than the entire 9999-year range.
pub fn UtcDateTime::minutes_until(
  self : UtcDateTime,
  other : UtcDateTime,
) -> Int {
  let day_delta = self.date().days_until(other.date())
  let self_minute = self.hour * 60 + self.minute
  let other_minute = other.hour * 60 + other.minute
  day_delta * 1440 + other_minute - self_minute
}

///|
fn two_digits(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn four_digits(value : Int) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
/// ISO-like UTC representation at minute precision.
pub fn UtcDateTime::to_iso8601(self : UtcDateTime) -> String {
  four_digits(self.year) +
  "-" +
  two_digits(self.month) +
  "-" +
  two_digits(self.day) +
  "T" +
  two_digits(self.hour) +
  ":" +
  two_digits(self.minute) +
  "Z"
}

///|
/// ISO calendar-date representation.
pub fn UtcDate::to_iso8601(self : UtcDate) -> String {
  four_digits(self.year) +
  "-" +
  two_digits(self.month) +
  "-" +
  two_digits(self.day)
}

///|
fn ascii_decimal_slice(text : String, start : Int, end : Int) -> Int? {
  if start < 0 || end > text.length() || start >= end {
    return None
  }
  let mut value = 0
  for index in start..<end {
    let code = text[index].to_int()
    if code < 48 || code > 57 {
      return None
    }
    value = value * 10 + code - 48
  }
  Some(value)
}

///|
/// Parse `YYYY-MM-DD`.
pub fn parse_utc_date(text : String) -> Result[UtcDate, CronError] {
  if text.length() != 10 || text[4] != '-' || text[7] != '-' {
    return Err(InvalidDate(text))
  }
  match
    (
      ascii_decimal_slice(text, 0, 4),
      ascii_decimal_slice(text, 5, 7),
      ascii_decimal_slice(text, 8, 10),
    ) {
    (Some(year), Some(month), Some(day)) => UtcDate::new(year, month, day)
    _ => Err(InvalidDate(text))
  }
}

///|
/// Parse `YYYY-MM-DDTHH:MMZ`.
pub fn parse_utc_datetime(text : String) -> Result[UtcDateTime, CronError] {
  if text.length() != 17 ||
    text[4] != '-' ||
    text[7] != '-' ||
    text[10] != 'T' ||
    text[13] != ':' ||
    text[16] != 'Z' {
    return Err(InvalidDate(text))
  }
  match
    (
      ascii_decimal_slice(text, 0, 4),
      ascii_decimal_slice(text, 5, 7),
      ascii_decimal_slice(text, 8, 10),
      ascii_decimal_slice(text, 11, 13),
      ascii_decimal_slice(text, 14, 16),
    ) {
    (Some(year), Some(month), Some(day), Some(hour), Some(minute)) =>
      UtcDateTime::new(year, month, day, hour, minute)
    _ => Err(InvalidDate(text))
  }
}

///|
/// A closed minute interval.
pub struct DateTimeRange {
  start : UtcDateTime
  end : UtcDateTime
} derive(Eq, Debug)

///|
/// Construct a non-empty closed interval.
pub fn DateTimeRange::new(
  start : UtcDateTime,
  end : UtcDateTime,
) -> Result[DateTimeRange, CronError] {
  if start <= end {
    Ok({ start, end })
  } else {
    Err(InvalidDate("range starts after it ends"))
  }
}

///|
pub fn DateTimeRange::contains(
  self : DateTimeRange,
  value : UtcDateTime,
) -> Bool {
  value >= self.start && value <= self.end
}

///|
pub fn DateTimeRange::overlaps(
  self : DateTimeRange,
  other : DateTimeRange,
) -> Bool {
  self.start <= other.end && other.start <= self.end
}

///|
pub fn DateTimeRange::intersection(
  self : DateTimeRange,
  other : DateTimeRange,
) -> DateTimeRange? {
  if !self.overlaps(other) {
    return None
  }
  let start = if self.start >= other.start { self.start } else { other.start }
  let end = if self.end <= other.end { self.end } else { other.end }
  Some({ start, end })
}

///|
/// Inclusive minute count in the range.
pub fn DateTimeRange::minute_count(self : DateTimeRange) -> Int {
  self.start.minutes_until(self.end) + 1
}

///|
/// Split the range into closed chunks containing at most `minutes` minutes.
pub fn DateTimeRange::chunks(
  self : DateTimeRange,
  minutes : Int,
) -> Array[DateTimeRange] {
  let result : Array[DateTimeRange] = []
  if minutes <= 0 {
    return result
  }
  let mut cursor = self.start
  for ;; {
    if cursor > self.end {
      break
    }
    let candidate = cursor.add_minutes(minutes - 1).unwrap_or(self.end)
    let chunk_end = if candidate <= self.end { candidate } else { self.end }
    result.push({ start: cursor, end: chunk_end })
    match chunk_end.add_minutes(1) {
      Some(next) => cursor = next
      None => break
    }
  }
  result
}
