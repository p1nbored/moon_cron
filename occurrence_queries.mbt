///|
const MAX_REVERSE_SEARCH_DAYS : Int = 3660

///|
fn previous_day(year : Int, month : Int, day : Int) -> (Int, Int, Int) {
  if day > 1 {
    (year, month, day - 1)
  } else if month > 1 {
    let previous_month = month - 1
    (year, previous_month, days_in_month(year, previous_month))
  } else {
    (year - 1, 12, 31)
  }
}

///|
/// Last minute strictly before `from` that satisfies the schedule.
pub fn Cron::previous_before(self : Cron, from : UtcDateTime) -> UtcDateTime? {
  let start = match from.add_minutes(-1) {
    Some(value) => value
    None => return None
  }
  let mut year = start.year
  let mut month = start.month
  let mut day = start.day
  let mut first_hour = start.hour
  let mut first_minute = start.minute
  for _ in 0..<MAX_REVERSE_SEARCH_DAYS {
    if year < 1 {
      return None
    }
    if self.date_matches(year, month, day) {
      for hour = first_hour; hour >= 0; hour = hour - 1 {
        if self.hour.matches(hour) {
          let minute_start = if hour == first_hour { first_minute } else { 59 }
          for minute = minute_start; minute >= 0; minute = minute - 1 {
            if self.minute.matches(minute) {
              return Some({ year, month, day, hour, minute })
            }
          }
        }
      }
    }
    let previous = previous_day(year, month, day)
    year = previous.0
    month = previous.1
    day = previous.2
    first_hour = 23
    first_minute = 59
  }
  None
}

///|
/// First occurrence at or after `from`.
pub fn Cron::next_on_or_after(self : Cron, from : UtcDateTime) -> UtcDateTime? {
  if self.matches_at(from) {
    Some(from)
  } else {
    self.next_after(from)
  }
}

///|
/// Last occurrence at or before `from`.
pub fn Cron::previous_on_or_before(
  self : Cron,
  from : UtcDateTime,
) -> UtcDateTime? {
  if self.matches_at(from) {
    Some(from)
  } else {
    self.previous_before(from)
  }
}

///|
/// Bounded query options for materializing occurrences.
pub struct OccurrenceQuery {
  range : DateTimeRange
  limit : Int
} derive(Eq, Debug)

///|
pub fn OccurrenceQuery::new(
  range : DateTimeRange,
  limit : Int,
) -> Result[OccurrenceQuery, CronError] {
  if limit <= 0 {
    Err(InvalidWindow("occurrence limit must be positive"))
  } else {
    Ok({ range, limit })
  }
}

///|
/// Materialize occurrences in the inclusive range.
pub fn Cron::occurrences(
  self : Cron,
  query : OccurrenceQuery,
) -> Array[UtcDateTime] {
  let result : Array[UtcDateTime] = []
  let mut current = self.next_on_or_after(query.range.start)
  for ;; {
    if result.length() >= query.limit {
      break
    }
    match current {
      Some(value) if value <= query.range.end => {
        result.push(value)
        current = self.next_after(value)
      }
      _ => break
    }
  }
  result
}

///|
/// Count occurrences up to `limit`. The boolean is true when the actual
/// count may be larger because the limit was reached.
pub struct OccurrenceCount {
  count : Int
  truncated : Bool
} derive(Eq, Debug)

///|
pub fn Cron::count_occurrences(
  self : Cron,
  range : DateTimeRange,
  limit? : Int = 100000,
) -> OccurrenceCount {
  if limit <= 0 {
    return { count: 0, truncated: true }
  }
  let query = OccurrenceQuery::new(range, limit).unwrap()
  let values = self.occurrences(query)
  let truncated = if values.length() < limit {
    false
  } else {
    match self.next_after(values[values.length() - 1]) {
      Some(next) => next <= range.end
      None => false
    }
  }
  { count: values.length(), truncated }
}

///|
pub fn Cron::has_occurrence(self : Cron, range : DateTimeRange) -> Bool {
  match self.next_on_or_after(range.start) {
    Some(value) => value <= range.end
    None => false
  }
}

///|
pub fn Cron::first_occurrence(
  self : Cron,
  range : DateTimeRange,
) -> UtcDateTime? {
  match self.next_on_or_after(range.start) {
    Some(value) if value <= range.end => Some(value)
    _ => None
  }
}

///|
pub fn Cron::last_occurrence(
  self : Cron,
  range : DateTimeRange,
) -> UtcDateTime? {
  match self.previous_on_or_before(range.end) {
    Some(value) if value >= range.start => Some(value)
    _ => None
  }
}

///|
/// Summary of minute gaps between sampled occurrences.
pub struct OccurrenceGapSummary {
  samples : Int
  minimum_minutes : Int
  maximum_minutes : Int
  average_minutes : Int
} derive(Eq, Debug)

///|
/// Analyze up to `sample_limit` occurrences in a range.
pub fn Cron::gap_summary(
  self : Cron,
  range : DateTimeRange,
  sample_limit? : Int = 1000,
) -> OccurrenceGapSummary? {
  if sample_limit < 2 {
    return None
  }
  let query = OccurrenceQuery::new(range, sample_limit).unwrap()
  let occurrences = self.occurrences(query)
  if occurrences.length() < 2 {
    return None
  }
  let mut minimum = occurrences[0].minutes_until(occurrences[1])
  let mut maximum = minimum
  let mut total = 0
  for index in 1..<occurrences.length() {
    let gap = occurrences[index - 1].minutes_until(occurrences[index])
    if gap < minimum {
      minimum = gap
    }
    if gap > maximum {
      maximum = gap
    }
    total += gap
  }
  let samples = occurrences.length() - 1
  Some({
    samples,
    minimum_minutes: minimum,
    maximum_minutes: maximum,
    average_minutes: total / samples,
  })
}

///|
/// One minute at which two schedules fire together.
pub struct ScheduleCollision {
  at : UtcDateTime
} derive(Eq, Debug)

///|
/// Find simultaneous occurrences in a bounded range.
pub fn Cron::collisions_with(
  self : Cron,
  other : Cron,
  range : DateTimeRange,
  limit? : Int = 1000,
) -> Array[ScheduleCollision] {
  let collisions : Array[ScheduleCollision] = []
  if limit <= 0 || !self.may_overlap(other) {
    return collisions
  }
  let query = OccurrenceQuery::new(range, limit * 10).unwrap()
  for at in self.occurrences(query) {
    if other.matches_at(at) {
      collisions.push({ at, })
      if collisions.length() >= limit {
        break
      }
    }
  }
  collisions
}

///|
/// True when both schedules fire at least once at the same minute.
pub fn Cron::collides_with(
  self : Cron,
  other : Cron,
  range : DateTimeRange,
) -> Bool {
  self.collisions_with(other, range, limit=1).length() == 1
}

///|
/// Partition occurrences by UTC calendar date.
pub struct DailyOccurrenceCount {
  date : UtcDate
  count : Int
} derive(Eq, Debug)

///|
pub fn Cron::daily_counts(
  self : Cron,
  range : DateTimeRange,
  occurrence_limit? : Int = 100000,
) -> Array[DailyOccurrenceCount] {
  let counts : Array[DailyOccurrenceCount] = []
  if occurrence_limit <= 0 {
    return counts
  }
  let query = OccurrenceQuery::new(range, occurrence_limit).unwrap()
  for occurrence in self.occurrences(query) {
    let date = occurrence.date()
    if counts.length() == 0 || counts[counts.length() - 1].date != date {
      counts.push({ date, count: 1 })
    } else {
      let last = counts.length() - 1
      counts[last] = { date, count: counts[last].count + 1 }
    }
  }
  counts
}

///|
/// A cursor page for APIs that should not expose unbounded arrays.
pub struct OccurrencePage {
  values : Array[UtcDateTime]
  next_cursor : UtcDateTime?
} derive(Eq, Debug)

///|
/// Return a page strictly after `cursor`, capped by both limit and end time.
pub fn Cron::occurrence_page(
  self : Cron,
  cursor : UtcDateTime,
  end : UtcDateTime,
  limit : Int,
) -> Result[OccurrencePage, CronError] {
  if cursor >= end || limit <= 0 {
    return Err(InvalidWindow("invalid occurrence page bounds"))
  }
  let start = match cursor.add_minutes(1) {
    Some(value) => value
    None =>
      return Err(InvalidWindow("cursor is outside the supported calendar"))
  }
  let range = DateTimeRange::new(start, end).unwrap()
  let values = self.occurrences(OccurrenceQuery::new(range, limit).unwrap())
  let next_cursor = if values.length() == limit {
    Some(values[values.length() - 1])
  } else {
    None
  }
  Ok({ values, next_cursor })
}
