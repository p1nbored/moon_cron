///|
/// Upper bound on the day-level search in `next_after`. Ten years is far
/// beyond the longest real gap between occurrences (a February the 29th
/// schedule waits at most eight years), so hitting the bound means the
/// schedule can never fire.
const MAX_SEARCH_DAYS : Int = 3660

///|
/// The calendar day immediately after the given one.
fn next_day(year : Int, month : Int, day : Int) -> (Int, Int, Int) {
  if day < days_in_month(year, month) {
    (year, month, day + 1)
  } else if month < 12 {
    (year, month + 1, 1)
  } else {
    (year + 1, 1, 1)
  }
}

///|
/// The minute immediately after `time`, rolling over hours, days, months
/// and years as needed. Internal only: the result may leave the validated
/// year range at the far end of the calendar.
fn next_minute(time : UtcDateTime) -> UtcDateTime {
  if time.minute < 59 {
    return { ..time, minute: time.minute + 1 }
  }
  if time.hour < 23 {
    return { ..time, hour: time.hour + 1, minute: 0 }
  }
  let (year, month, day) = next_day(time.year, time.month, time.day)
  { year, month, day, hour: 0, minute: 0 }
}

///|
/// True when the schedule can fire on the given calendar date.
fn Cron::date_matches(self : Cron, year : Int, month : Int, day : Int) -> Bool {
  self.month.matches(month, lower=1) &&
  self.calendar_matches(day, weekday_of(year, month, day))
}

///|
/// The first minute strictly after `from` that satisfies the schedule, or
/// `None` when no occurrence exists within the ten-year search horizon
/// (for example a schedule pinned to day 30 of February).
pub fn Cron::next_after(self : Cron, from : UtcDateTime) -> UtcDateTime? {
  let start = next_minute(from)
  let mut year = start.year
  let mut month = start.month
  let mut day = start.day
  let mut first_hour = start.hour
  let mut first_minute = start.minute
  for _ in 0..<MAX_SEARCH_DAYS {
    if year > 9999 {
      return None
    }
    if self.date_matches(year, month, day) {
      for hour in first_hour..<24 {
        if self.hour.matches(hour) {
          let minute_start = if hour == first_hour { first_minute } else { 0 }
          for minute in minute_start..<60 {
            if self.minute.matches(minute) {
              return Some({ year, month, day, hour, minute })
            }
          }
        }
      }
    }
    let following = next_day(year, month, day)
    year = following.0
    month = following.1
    day = following.2
    first_hour = 0
    first_minute = 0
  }
  None
}

///|
/// Up to `limit` occurrences strictly after `from`, in chronological
/// order. Fewer are returned when the schedule stops producing matches
/// inside the search horizon.
pub fn Cron::next_occurrences(
  self : Cron,
  from : UtcDateTime,
  limit : Int,
) -> Array[UtcDateTime] {
  let occurrences : Array[UtcDateTime] = []
  let mut cursor = from
  for _ in 0..<limit {
    match self.next_after(cursor) {
      Some(occurrence) => {
        occurrences.push(occurrence)
        cursor = occurrence
      }
      None => break
    }
  }
  occurrences
}

///|
/// Check a schedule directly against a validated date-time.
pub fn Cron::matches_at(self : Cron, at : UtcDateTime) -> Bool {
  self.matches(at.to_utc_time())
}
