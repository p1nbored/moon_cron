///|
/// A calendar date and wall-clock time in UTC at minute precision. Values
/// are validated on construction, so an instance always denotes a real
/// calendar minute. Ordering compares chronologically.
pub struct UtcDateTime {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
} derive(Eq, Compare, Debug)

///|
/// Build a validated UTC date-time. Years 1 through 9999 are supported.
pub fn UtcDateTime::new(
  year : Int,
  month : Int,
  day : Int,
  hour : Int,
  minute : Int,
) -> Result[UtcDateTime, CronError] {
  if year < 1 ||
    year > 9999 ||
    month < 1 ||
    month > 12 ||
    day < 1 ||
    day > days_in_month(year, month) ||
    hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 {
    return Err(InvalidDate("\{year}-\{month}-\{day} \{hour}:\{minute}"))
  }
  Ok({ year, month, day, hour, minute })
}

///|
/// True for Gregorian leap years.
pub fn is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
/// Number of days in a month, or 0 when the month is outside 1 to 12.
pub fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
/// Weekday of a date in cron's convention: Sunday is 0, Saturday is 6.
/// Uses Sakamoto's algorithm, valid for all Gregorian dates with a
/// positive year.
fn weekday_of(year : Int, month : Int, day : Int) -> Int {
  let offsets = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
  let adjusted = if month < 3 { year - 1 } else { year }
  (
    adjusted +
    adjusted / 4 -
    adjusted / 100 +
    adjusted / 400 +
    offsets[month - 1] +
    day
  ) %
  7
}

///|
/// Weekday of this date: Sunday is 0, Saturday is 6.
pub fn UtcDateTime::weekday(self : UtcDateTime) -> Int {
  weekday_of(self.year, self.month, self.day)
}

///|
/// Project onto the year-less wall-clock view used by `Cron::matches`,
/// with the weekday computed from the date.
pub fn UtcDateTime::to_utc_time(self : UtcDateTime) -> UtcTime {
  {
    minute: self.minute,
    hour: self.hour,
    day_of_month: self.day,
    month: self.month,
    weekday: self.weekday(),
  }
}
