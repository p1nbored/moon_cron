///|
/// Coarse operational frequency classification.
pub(all) enum FrequencyClass {
  Dormant
  Sparse
  Moderate
  Frequent
  Intense
} derive(Eq, Debug)

///|
pub fn FrequencyClass::label(self : FrequencyClass) -> String {
  match self {
    Dormant => "dormant"
    Sparse => "sparse"
    Moderate => "moderate"
    Frequent => "frequent"
    Intense => "intense"
  }
}

///|
/// Number of occurrences assigned to one UTC hour of day.
pub struct HourlyBucket {
  hour : Int
  count : Int
} derive(Eq, Debug)

///|
/// Number of occurrences assigned to one UTC weekday.
pub struct WeekdayBucket {
  weekday : Int
  count : Int
} derive(Eq, Debug)

///|
/// Bounded statistics for one named schedule.
pub struct ScheduleStatistics {
  name : String
  enabled : Bool
  occurrence_count : Int
  truncated : Bool
  first : UtcDateTime?
  last : UtcDateTime?
  active_days : Int
  minimum_gap_minutes : Int?
  maximum_gap_minutes : Int?
  average_gap_minutes : Int?
  frequency : FrequencyClass
  hourly : Array[HourlyBucket]
  weekdays : Array[WeekdayBucket]
} derive(Eq, Debug)

///|
fn classify_frequency(
  count : Int,
  gap : OccurrenceGapSummary?,
) -> FrequencyClass {
  if count == 0 {
    Dormant
  } else if count == 1 {
    Sparse
  } else {
    match gap {
      Some(summary) =>
        if summary.average_minutes >= 1440 {
          Sparse
        } else if summary.average_minutes >= 60 {
          Moderate
        } else if summary.average_minutes >= 5 {
          Frequent
        } else {
          Intense
        }
      None => Sparse
    }
  }
}

///|
fn hourly_buckets(values : Array[UtcDateTime]) -> Array[HourlyBucket] {
  let counts = Array::make(24, 0)
  for value in values {
    counts[value.hour] += 1
  }
  let result : Array[HourlyBucket] = []
  for hour in 0..<24 {
    result.push({ hour, count: counts[hour] })
  }
  result
}

///|
fn weekday_buckets(values : Array[UtcDateTime]) -> Array[WeekdayBucket] {
  let counts = Array::make(7, 0)
  for value in values {
    counts[value.weekday()] += 1
  }
  let result : Array[WeekdayBucket] = []
  for weekday in 0..<7 {
    result.push({ weekday, count: counts[weekday] })
  }
  result
}

///|
fn count_active_days(values : Array[UtcDateTime]) -> Int {
  let mut count = 0
  let mut previous : UtcDate? = None
  for value in values {
    let date = value.date()
    if previous != Some(date) {
      count += 1
      previous = Some(date)
    }
  }
  count
}

///|
/// Analyze one named schedule in an inclusive operational window.
pub fn analyze_schedule(
  schedule : NamedSchedule,
  range : DateTimeRange,
  limit? : Int = 100000,
) -> ScheduleStatistics {
  if !schedule.enabled || limit <= 0 {
    return {
      name: schedule.name,
      enabled: schedule.enabled,
      occurrence_count: 0,
      truncated: false,
      first: None,
      last: None,
      active_days: 0,
      minimum_gap_minutes: None,
      maximum_gap_minutes: None,
      average_gap_minutes: None,
      frequency: Dormant,
      hourly: hourly_buckets([]),
      weekdays: weekday_buckets([]),
    }
  }
  let query = OccurrenceQuery::new(range, limit).unwrap()
  let values = schedule.cron.occurrences(query)
  let truncated = if values.length() < limit || values.length() == 0 {
    false
  } else {
    match schedule.cron.next_after(values[values.length() - 1]) {
      Some(next) => next <= range.end
      None => false
    }
  }
  let gap = schedule.cron.gap_summary(range, sample_limit=limit)
  {
    name: schedule.name,
    enabled: true,
    occurrence_count: values.length(),
    truncated,
    first: values.get(0),
    last: values.get(values.length() - 1),
    active_days: count_active_days(values),
    minimum_gap_minutes: gap.map(summary => summary.minimum_minutes),
    maximum_gap_minutes: gap.map(summary => summary.maximum_minutes),
    average_gap_minutes: gap.map(summary => summary.average_minutes),
    frequency: classify_frequency(values.length(), gap),
    hourly: hourly_buckets(values),
    weekdays: weekday_buckets(values),
  }
}

///|
pub fn ScheduleStatistics::busiest_hour(
  self : ScheduleStatistics,
) -> HourlyBucket? {
  if self.occurrence_count == 0 {
    return None
  }
  let mut best = self.hourly[0]
  for bucket in self.hourly {
    if bucket.count > best.count {
      best = bucket
    }
  }
  Some(best)
}

///|
pub fn ScheduleStatistics::busiest_weekday(
  self : ScheduleStatistics,
) -> WeekdayBucket? {
  if self.occurrence_count == 0 {
    return None
  }
  let mut best = self.weekdays[0]
  for bucket in self.weekdays {
    if bucket.count > best.count {
      best = bucket
    }
  }
  Some(best)
}

///|
pub fn ScheduleStatistics::hour_count(
  self : ScheduleStatistics,
  hour : Int,
) -> Int {
  if hour < 0 || hour > 23 {
    return 0
  }
  self.hourly[hour].count
}

///|
pub fn ScheduleStatistics::weekday_count(
  self : ScheduleStatistics,
  weekday : Int,
) -> Int {
  if weekday < 0 || weekday > 6 {
    return 0
  }
  self.weekdays[weekday].count
}

///|
/// Pairwise collision statistics.
pub struct CollisionStatistics {
  left_name : String
  right_name : String
  count : Int
  first : UtcDateTime?
  last : UtcDateTime?
  truncated : Bool
} derive(Eq, Debug)

///|
pub fn analyze_collision(
  left : NamedSchedule,
  right : NamedSchedule,
  range : DateTimeRange,
  limit? : Int = 10000,
) -> CollisionStatistics {
  if !left.enabled || !right.enabled || limit <= 0 {
    return {
      left_name: left.name,
      right_name: right.name,
      count: 0,
      first: None,
      last: None,
      truncated: false,
    }
  }
  let values = left.cron.collisions_with(right.cron, range, limit~)
  let truncated = if values.length() < limit || values.length() == 0 {
    false
  } else {
    let cursor = values[values.length() - 1].at
    match left.cron.next_after(cursor) {
      Some(next) => next <= range.end && right.cron.matches_at(next)
      None => false
    }
  }
  {
    left_name: left.name,
    right_name: right.name,
    count: values.length(),
    first: values.get(0).map(item => item.at),
    last: values.get(values.length() - 1).map(item => item.at),
    truncated,
  }
}

///|
/// One minute carrying the maximum number of simultaneous events.
pub struct PeakMinute {
  at : UtcDateTime
  schedule_names : Array[String]
} derive(Eq, Debug)

///|
/// Aggregate event load for one UTC calendar date.
pub struct DailyLoad {
  date : UtcDate
  event_count : Int
  active_minutes : Int
  peak_concurrency : Int
} derive(Eq, Debug)

///|
/// Reviewer-facing health classification derived from bounded evidence.
pub(all) enum ReportHealth {
  Healthy
  NeedsAttention
  Critical
} derive(Eq, Debug)

///|
pub fn ReportHealth::label(self : ReportHealth) -> String {
  match self {
    Healthy => "healthy"
    NeedsAttention => "needs-attention"
    Critical => "critical"
  }
}

///|
/// Aggregate operational report for a schedule registry.
pub struct ScheduleReport {
  range : DateTimeRange
  schedules : Array[ScheduleStatistics]
  collisions : Array[CollisionStatistics]
  daily_load : Array[DailyLoad]
  total_events : Int
  peak : PeakMinute?
  truncated : Bool
} derive(Eq, Debug)

///|
fn build_daily_load(batches : Array[EventBatch]) -> Array[DailyLoad] {
  let result : Array[DailyLoad] = []
  for batch in batches {
    let date = batch.at.date()
    let concurrency = batch.schedule_names.length()
    if result.length() == 0 || result[result.length() - 1].date != date {
      result.push({
        date,
        event_count: concurrency,
        active_minutes: 1,
        peak_concurrency: concurrency,
      })
    } else {
      let last = result.length() - 1
      let previous = result[last]
      result[last] = {
        date,
        event_count: previous.event_count + concurrency,
        active_minutes: previous.active_minutes + 1,
        peak_concurrency: if concurrency > previous.peak_concurrency {
          concurrency
        } else {
          previous.peak_concurrency
        },
      }
    }
  }
  result
}

///|
pub fn ScheduleBook::report(
  self : ScheduleBook,
  range : DateTimeRange,
  per_schedule_limit? : Int = 100000,
  per_pair_limit? : Int = 10000,
) -> ScheduleReport {
  let statistics : Array[ScheduleStatistics] = []
  let collisions : Array[CollisionStatistics] = []
  let entries = self.all()
  let mut total_events = 0
  let mut truncated = false
  for entry in entries {
    let stats = analyze_schedule(entry, range, limit=per_schedule_limit)
    total_events += stats.occurrence_count
    if stats.truncated {
      truncated = true
    }
    statistics.push(stats)
  }
  for left_index in 0..<entries.length() {
    for right_index in (left_index + 1)..<entries.length() {
      let stats = analyze_collision(
        entries[left_index],
        entries[right_index],
        range,
        limit=per_pair_limit,
      )
      if stats.count > 0 {
        collisions.push(stats)
      }
      if stats.truncated {
        truncated = true
      }
    }
  }
  let batches = self.event_batches(range, per_schedule_limit~)
  let mut peak : PeakMinute? = None
  for batch in batches {
    match peak {
      Some(current) =>
        if batch.schedule_names.length() > current.schedule_names.length() {
          peak = Some({ at: batch.at, schedule_names: batch.schedule_names })
        }
      None =>
        peak = Some({ at: batch.at, schedule_names: batch.schedule_names })
    }
  }
  {
    range,
    schedules: statistics,
    collisions,
    daily_load: build_daily_load(batches),
    total_events,
    peak,
    truncated,
  }
}

///|
pub fn ScheduleReport::schedule_count(self : ScheduleReport) -> Int {
  self.schedules.length()
}

///|
pub fn ScheduleReport::collision_pair_count(self : ScheduleReport) -> Int {
  self.collisions.length()
}

///|
pub fn ScheduleReport::active_day_count(self : ScheduleReport) -> Int {
  self.daily_load.length()
}

///|
pub fn ScheduleReport::peak_concurrency(self : ScheduleReport) -> Int {
  match self.peak {
    Some(peak) => peak.schedule_names.length()
    None => 0
  }
}

///|
pub fn ScheduleReport::average_events_per_active_day(
  self : ScheduleReport,
) -> Int {
  if self.daily_load.length() == 0 {
    0
  } else {
    self.total_events / self.daily_load.length()
  }
}

///|
pub fn ScheduleReport::busiest_day(self : ScheduleReport) -> DailyLoad? {
  if self.daily_load.length() == 0 {
    return None
  }
  let mut best = self.daily_load[0]
  for load in self.daily_load {
    if load.event_count > best.event_count {
      best = load
    }
  }
  Some(best)
}

///|
pub fn ScheduleReport::load_on(
  self : ScheduleReport,
  date : UtcDate,
) -> DailyLoad? {
  for load in self.daily_load {
    if load.date == date {
      return Some(load)
    }
  }
  None
}

///|
pub fn ScheduleReport::health(self : ScheduleReport) -> ReportHealth {
  if self.truncated || self.peak_concurrency() >= 5 {
    return Critical
  }
  if self.collision_pair_count() > 0 ||
    self.dormant_names().length() > 0 ||
    self.intense_names().length() > 0 {
    NeedsAttention
  } else {
    Healthy
  }
}

///|
/// Deterministic action hints based only on evidence contained in the report.
pub fn ScheduleReport::recommendations(self : ScheduleReport) -> Array[String] {
  let result : Array[String] = []
  if self.truncated {
    result.push(
      "increase report limits or shorten the window before making decisions",
    )
  }
  let dormant = self.dormant_names()
  if dormant.length() > 0 {
    result.push(
      "review " +
      dormant.length().to_string() +
      " dormant or disabled schedule(s)",
    )
  }
  let intense = self.intense_names()
  if intense.length() > 0 {
    result.push(
      "review " + intense.length().to_string() + " intense schedule(s)",
    )
  }
  if self.collision_pair_count() > 0 {
    result.push(
      "stagger " +
      self.collision_pair_count().to_string() +
      " colliding schedule pair(s)",
    )
  }
  if self.peak_concurrency() >= 3 {
    result.push(
      "capacity-test the peak concurrency of " +
      self.peak_concurrency().to_string(),
    )
  }
  if result.length() == 0 {
    result.push("no bounded-window scheduling risks detected")
  }
  result
}

///|
pub fn ScheduleReport::statistics_for(
  self : ScheduleReport,
  name : String,
) -> ScheduleStatistics? {
  for statistics in self.schedules {
    if statistics.name == name {
      return Some(statistics)
    }
  }
  None
}

///|
pub fn ScheduleReport::collision_for(
  self : ScheduleReport,
  left_name : String,
  right_name : String,
) -> CollisionStatistics? {
  for collision in self.collisions {
    let direct = collision.left_name == left_name &&
      collision.right_name == right_name
    let reverse = collision.left_name == right_name &&
      collision.right_name == left_name
    if direct || reverse {
      return Some(collision)
    }
  }
  None
}

///|
pub fn ScheduleReport::dormant_names(self : ScheduleReport) -> Array[String] {
  let result : Array[String] = []
  for statistics in self.schedules {
    if statistics.frequency == Dormant {
      result.push(statistics.name)
    }
  }
  result
}

///|
pub fn ScheduleReport::intense_names(self : ScheduleReport) -> Array[String] {
  let result : Array[String] = []
  for statistics in self.schedules {
    if statistics.frequency == Intense {
      result.push(statistics.name)
    }
  }
  result
}

///|
pub fn ScheduleReport::colliding_names(self : ScheduleReport) -> Array[String] {
  let result : Array[String] = []
  for collision in self.collisions {
    if !string_array_contains(result, collision.left_name) {
      result.push(collision.left_name)
    }
    if !string_array_contains(result, collision.right_name) {
      result.push(collision.right_name)
    }
  }
  result
}

///|
fn string_array_contains(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn option_time_text(value : UtcDateTime?) -> String {
  match value {
    Some(at) => at.to_iso8601()
    None => "-"
  }
}

///|
/// Stable text suitable for CI artifacts and command-line diagnostics.
pub fn ScheduleReport::to_text(self : ScheduleReport) -> String {
  let writer = StringBuilder::new()
  writer.write_string("MoonCron schedule report\n")
  writer.write_string(
    "window: " +
    self.range.start.to_iso8601() +
    " .. " +
    self.range.end.to_iso8601() +
    "\n",
  )
  writer.write_string("schedules: " + self.schedule_count().to_string() + "\n")
  writer.write_string("events: " + self.total_events.to_string() + "\n")
  writer.write_string("health: " + self.health().label() + "\n")
  writer.write_string(
    "active days: " + self.active_day_count().to_string() + "\n",
  )
  writer.write_string(
    "collision pairs: " + self.collision_pair_count().to_string() + "\n",
  )
  match self.peak {
    Some(peak) =>
      writer.write_string(
        "peak: " +
        peak.at.to_iso8601() +
        " (" +
        peak.schedule_names.length().to_string() +
        " schedules)\n",
      )
    None => writer.write_string("peak: -\n")
  }
  writer.write_string("\nSchedule details:\n")
  for statistics in self.schedules {
    writer.write_string("- ")
    writer.write_string(statistics.name)
    writer.write_string(": ")
    writer.write_string(statistics.frequency.label())
    writer.write_string(", occurrences=")
    writer.write_string(statistics.occurrence_count.to_string())
    writer.write_string(", active_days=")
    writer.write_string(statistics.active_days.to_string())
    writer.write_string(", first=")
    writer.write_string(option_time_text(statistics.first))
    writer.write_string(", last=")
    writer.write_string(option_time_text(statistics.last))
    if statistics.truncated {
      writer.write_string(", truncated")
    }
    writer.write_char('\n')
  }
  if self.collisions.length() > 0 {
    writer.write_string("\nCollisions:\n")
    for collision in self.collisions {
      writer.write_string("- ")
      writer.write_string(collision.left_name)
      writer.write_string(" + ")
      writer.write_string(collision.right_name)
      writer.write_string(": ")
      writer.write_string(collision.count.to_string())
      writer.write_string(", first=")
      writer.write_string(option_time_text(collision.first))
      writer.write_char('\n')
    }
  }
  writer.write_string("\nRecommendations:\n")
  for recommendation in self.recommendations() {
    writer.write_string("- ")
    writer.write_string(recommendation)
    writer.write_char('\n')
  }
  writer.to_string()
}
