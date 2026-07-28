///|
/// A closed interval in which ordinary cron occurrences are suppressed.
pub struct ScheduleBlackout {
  range : DateTimeRange
  reason : String
} derive(Eq, Debug)

///|
pub fn ScheduleBlackout::new(
  range : DateTimeRange,
  reason? : String = "",
) -> ScheduleBlackout {
  { range, reason }
}

///|
pub fn ScheduleBlackout::contains(
  self : ScheduleBlackout,
  at : UtcDateTime,
) -> Bool {
  self.range.contains(at)
}

///|
pub fn ScheduleBlackout::overlaps(
  self : ScheduleBlackout,
  range : DateTimeRange,
) -> Bool {
  self.range.overlaps(range)
}

///|
/// A one-off occurrence that is independent of the cron expression.
pub struct ScheduleInclusion {
  at : UtcDateTime
  reason : String
} derive(Eq, Debug)

///|
pub fn ScheduleInclusion::new(
  at : UtcDateTime,
  reason? : String = "",
) -> ScheduleInclusion {
  { at, reason }
}

///|
/// Explanation of why a policy does or does not fire at a minute.
pub(all) enum PolicyDecision {
  Included(String)
  Scheduled
  Excluded(String)
  Disabled
  NotScheduled
} derive(Eq, Debug)

///|
/// Cron plus operational exceptions. Explicit inclusions have the highest
/// priority, allowing a controlled one-off run during a blackout or while the
/// recurring schedule is disabled.
pub struct SchedulePolicy {
  cron : Cron
  enabled : Bool
  blackouts : Array[ScheduleBlackout]
  inclusions : Array[ScheduleInclusion]
} derive(Eq, Debug)

///|
pub fn SchedulePolicy::new(
  cron : Cron,
  enabled? : Bool = true,
) -> Result[SchedulePolicy, CronError] {
  match cron.validate() {
    Err(error) => Err(error)
    Ok(_) => Ok({ cron, enabled, blackouts: [], inclusions: [] })
  }
}

///|
pub fn SchedulePolicy::with_enabled(
  self : SchedulePolicy,
  enabled : Bool,
) -> SchedulePolicy {
  { ..self, enabled, }
}

///|
pub fn SchedulePolicy::with_cron(
  self : SchedulePolicy,
  cron : Cron,
) -> Result[SchedulePolicy, CronError] {
  match cron.validate() {
    Err(error) => Err(error)
    Ok(_) => Ok({ ..self, cron, })
  }
}

///|
pub fn SchedulePolicy::blackout_count(self : SchedulePolicy) -> Int {
  self.blackouts.length()
}

///|
pub fn SchedulePolicy::inclusion_count(self : SchedulePolicy) -> Int {
  self.inclusions.length()
}

///|
pub fn SchedulePolicy::all_blackouts(
  self : SchedulePolicy,
) -> Array[ScheduleBlackout] {
  self.blackouts.copy()
}

///|
pub fn SchedulePolicy::all_inclusions(
  self : SchedulePolicy,
) -> Array[ScheduleInclusion] {
  self.inclusions.copy()
}

///|
fn sort_blackouts(values : Array[ScheduleBlackout]) -> Unit {
  for index in 1..<values.length() {
    let current = values[index]
    let mut position = index
    for ;; {
      if position <= 0 ||
        values[position - 1].range.start <= current.range.start {
        break
      }
      values[position] = values[position - 1]
      position -= 1
    }
    values[position] = current
  }
}

///|
fn sort_inclusions(values : Array[ScheduleInclusion]) -> Unit {
  for index in 1..<values.length() {
    let current = values[index]
    let mut position = index
    for ;; {
      if position <= 0 || values[position - 1].at <= current.at {
        break
      }
      values[position] = values[position - 1]
      position -= 1
    }
    values[position] = current
  }
}

///|
/// Add a blackout unless an identical range and reason already exists.
pub fn SchedulePolicy::add_blackout(
  self : SchedulePolicy,
  blackout : ScheduleBlackout,
) -> SchedulePolicy {
  let values = self.blackouts.copy()
  let mut duplicate = false
  for existing in values {
    if existing == blackout {
      duplicate = true
    }
  }
  if !duplicate {
    values.push(blackout)
    sort_blackouts(values)
  }
  { ..self, blackouts: values }
}

///|
/// Remove every blackout whose interval equals `range`.
pub fn SchedulePolicy::remove_blackout(
  self : SchedulePolicy,
  range : DateTimeRange,
) -> SchedulePolicy {
  let values : Array[ScheduleBlackout] = []
  for blackout in self.blackouts {
    if blackout.range != range {
      values.push(blackout)
    }
  }
  { ..self, blackouts: values }
}

///|
/// Add or replace a one-off inclusion at the same minute.
pub fn SchedulePolicy::add_inclusion(
  self : SchedulePolicy,
  inclusion : ScheduleInclusion,
) -> SchedulePolicy {
  let values : Array[ScheduleInclusion] = []
  let mut replaced = false
  for existing in self.inclusions {
    if existing.at == inclusion.at {
      if !replaced {
        values.push(inclusion)
        replaced = true
      }
    } else {
      values.push(existing)
    }
  }
  if !replaced {
    values.push(inclusion)
  }
  sort_inclusions(values)
  { ..self, inclusions: values }
}

///|
pub fn SchedulePolicy::remove_inclusion(
  self : SchedulePolicy,
  at : UtcDateTime,
) -> SchedulePolicy {
  let values : Array[ScheduleInclusion] = []
  for inclusion in self.inclusions {
    if inclusion.at != at {
      values.push(inclusion)
    }
  }
  { ..self, inclusions: values }
}

///|
pub fn SchedulePolicy::inclusion_at(
  self : SchedulePolicy,
  at : UtcDateTime,
) -> ScheduleInclusion? {
  for inclusion in self.inclusions {
    if inclusion.at == at {
      return Some(inclusion)
    }
  }
  None
}

///|
pub fn SchedulePolicy::blackout_at(
  self : SchedulePolicy,
  at : UtcDateTime,
) -> ScheduleBlackout? {
  for blackout in self.blackouts {
    if blackout.contains(at) {
      return Some(blackout)
    }
  }
  None
}

///|
pub fn SchedulePolicy::decision_at(
  self : SchedulePolicy,
  at : UtcDateTime,
) -> PolicyDecision {
  match self.inclusion_at(at) {
    Some(inclusion) => return Included(inclusion.reason)
    None => ()
  }
  if !self.enabled {
    return Disabled
  }
  match self.blackout_at(at) {
    Some(blackout) => Excluded(blackout.reason)
    None => if self.cron.matches_at(at) { Scheduled } else { NotScheduled }
  }
}

///|
pub fn SchedulePolicy::matches_at(
  self : SchedulePolicy,
  at : UtcDateTime,
) -> Bool {
  match self.decision_at(at) {
    Included(_) | Scheduled => true
    _ => false
  }
}

///|
fn SchedulePolicy::next_inclusion_on_or_after(
  self : SchedulePolicy,
  from : UtcDateTime,
) -> UtcDateTime? {
  for inclusion in self.inclusions {
    if inclusion.at >= from {
      return Some(inclusion.at)
    }
  }
  None
}

///|
fn SchedulePolicy::previous_inclusion_on_or_before(
  self : SchedulePolicy,
  from : UtcDateTime,
) -> UtcDateTime? {
  let mut result : UtcDateTime? = None
  for inclusion in self.inclusions {
    if inclusion.at <= from {
      result = Some(inclusion.at)
    } else {
      break
    }
  }
  result
}

///|
fn earlier_time(left : UtcDateTime?, right : UtcDateTime?) -> UtcDateTime? {
  match (left, right) {
    (Some(a), Some(b)) => Some(if a <= b { a } else { b })
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

///|
fn later_time(left : UtcDateTime?, right : UtcDateTime?) -> UtcDateTime? {
  match (left, right) {
    (Some(a), Some(b)) => Some(if a >= b { a } else { b })
    (Some(a), None) => Some(a)
    (None, Some(b)) => Some(b)
    (None, None) => None
  }
}

///|
/// First effective occurrence at or after `from`.
pub fn SchedulePolicy::next_on_or_after(
  self : SchedulePolicy,
  from : UtcDateTime,
) -> UtcDateTime? {
  let inclusion = self.next_inclusion_on_or_after(from)
  if !self.enabled {
    return inclusion
  }
  let mut scheduled = self.cron.next_on_or_after(from)
  for _ in 0..<10000 {
    match scheduled {
      Some(value) =>
        match self.blackout_at(value) {
          Some(blackout) => {
            let next_minute = blackout.range.end.add_minutes(1)
            scheduled = match next_minute {
              Some(cursor) => self.cron.next_on_or_after(cursor)
              None => None
            }
          }
          None => break
        }
      None => break
    }
  }
  earlier_time(inclusion, scheduled)
}

///|
pub fn SchedulePolicy::next_after(
  self : SchedulePolicy,
  from : UtcDateTime,
) -> UtcDateTime? {
  match from.add_minutes(1) {
    Some(cursor) => self.next_on_or_after(cursor)
    None => None
  }
}

///|
/// Last effective occurrence at or before `from`.
pub fn SchedulePolicy::previous_on_or_before(
  self : SchedulePolicy,
  from : UtcDateTime,
) -> UtcDateTime? {
  let inclusion = self.previous_inclusion_on_or_before(from)
  if !self.enabled {
    return inclusion
  }
  let mut scheduled = self.cron.previous_on_or_before(from)
  for _ in 0..<10000 {
    match scheduled {
      Some(value) =>
        match self.blackout_at(value) {
          Some(blackout) => {
            let previous_minute = blackout.range.start.add_minutes(-1)
            scheduled = match previous_minute {
              Some(cursor) => self.cron.previous_on_or_before(cursor)
              None => None
            }
          }
          None => break
        }
      None => break
    }
  }
  later_time(inclusion, scheduled)
}

///|
pub fn SchedulePolicy::previous_before(
  self : SchedulePolicy,
  from : UtcDateTime,
) -> UtcDateTime? {
  match from.add_minutes(-1) {
    Some(cursor) => self.previous_on_or_before(cursor)
    None => None
  }
}

///|
/// Materialize effective occurrences in an inclusive range.
pub fn SchedulePolicy::occurrences(
  self : SchedulePolicy,
  range : DateTimeRange,
  limit? : Int = 10000,
) -> Array[UtcDateTime] {
  let result : Array[UtcDateTime] = []
  if limit <= 0 {
    return result
  }
  let mut current = self.next_on_or_after(range.start)
  for ;; {
    if result.length() >= limit {
      break
    }
    match current {
      Some(value) if value <= range.end => {
        result.push(value)
        current = self.next_after(value)
      }
      _ => break
    }
  }
  result
}

///|
pub fn SchedulePolicy::count_occurrences(
  self : SchedulePolicy,
  range : DateTimeRange,
  limit? : Int = 100000,
) -> OccurrenceCount {
  let values = self.occurrences(range, limit~)
  let truncated = if values.length() < limit || values.length() == 0 {
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
/// Summarize how exceptions affect a bounded operational window.
pub struct PolicyAudit {
  effective_occurrences : Int
  base_occurrences : Int
  suppressed_occurrences : Int
  included_occurrences : Int
  truncated : Bool
} derive(Eq, Debug)

///|
pub fn SchedulePolicy::audit(
  self : SchedulePolicy,
  range : DateTimeRange,
  limit? : Int = 100000,
) -> PolicyAudit {
  let base = if self.enabled {
    self.cron.count_occurrences(range, limit~)
  } else {
    { count: 0, truncated: false }
  }
  let effective = self.count_occurrences(range, limit~)
  let mut included = 0
  for inclusion in self.inclusions {
    if range.contains(inclusion.at) {
      included += 1
    }
  }
  let retained_base = effective.count - included
  {
    effective_occurrences: effective.count,
    base_occurrences: base.count,
    suppressed_occurrences: if base.count > retained_base {
      base.count - retained_base
    } else {
      0
    },
    included_occurrences: included,
    truncated: base.truncated || effective.truncated,
  }
}

///|
/// Blackouts intersecting a query window.
pub fn SchedulePolicy::blackouts_in(
  self : SchedulePolicy,
  range : DateTimeRange,
) -> Array[ScheduleBlackout] {
  let result : Array[ScheduleBlackout] = []
  for blackout in self.blackouts {
    if blackout.overlaps(range) {
      result.push(blackout)
    }
  }
  result
}

///|
/// Inclusions contained by a query window.
pub fn SchedulePolicy::inclusions_in(
  self : SchedulePolicy,
  range : DateTimeRange,
) -> Array[ScheduleInclusion] {
  let result : Array[ScheduleInclusion] = []
  for inclusion in self.inclusions {
    if range.contains(inclusion.at) {
      result.push(inclusion)
    }
  }
  result
}

///|
/// Copy the policy without operational exceptions.
pub fn SchedulePolicy::clear_exceptions(
  self : SchedulePolicy,
) -> SchedulePolicy {
  { ..self, blackouts: [], inclusions: [] }
}
