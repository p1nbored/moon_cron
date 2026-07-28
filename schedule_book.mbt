///|
/// A named, independently enabled schedule.
pub struct NamedSchedule {
  name : String
  cron : Cron
  enabled : Bool
} derive(Eq, Debug)

///|
pub fn NamedSchedule::new(
  name : String,
  cron : Cron,
  enabled? : Bool = true,
) -> Result[NamedSchedule, CronError] {
  if name.trim().length() == 0 {
    return Err(InvalidField("schedule name must not be empty"))
  }
  match cron.validate() {
    Err(error) => Err(error)
    Ok(_) => Ok({ name, cron, enabled })
  }
}

///|
pub fn NamedSchedule::with_enabled(
  self : NamedSchedule,
  enabled : Bool,
) -> NamedSchedule {
  { ..self, enabled, }
}

///|
pub fn NamedSchedule::with_cron(
  self : NamedSchedule,
  cron : Cron,
) -> Result[NamedSchedule, CronError] {
  match cron.validate() {
    Ok(_) => Ok({ ..self, cron, })
    Err(error) => Err(error)
  }
}

///|
/// Mutable registry for application schedules. The contained array is private
/// to callers, so all name-uniqueness rules stay centralized here.
pub struct ScheduleBook {
  entries : Array[NamedSchedule]
} derive(Debug)

///|
pub fn ScheduleBook::new() -> ScheduleBook {
  { entries: [] }
}

///|
pub fn ScheduleBook::from_array(
  entries : Array[NamedSchedule],
) -> Result[ScheduleBook, CronError] {
  let book = ScheduleBook::new()
  for entry in entries {
    match book.add(entry) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  Ok(book)
}

///|
pub fn ScheduleBook::length(self : ScheduleBook) -> Int {
  self.entries.length()
}

///|
pub fn ScheduleBook::enabled_length(self : ScheduleBook) -> Int {
  let mut count = 0
  for entry in self.entries {
    if entry.enabled {
      count += 1
    }
  }
  count
}

///|
fn ScheduleBook::index_of(self : ScheduleBook, name : String) -> Int? {
  for index, entry in self.entries {
    if entry.name == name {
      return Some(index)
    }
  }
  None
}

///|
pub fn ScheduleBook::contains(self : ScheduleBook, name : String) -> Bool {
  self.index_of(name) is Some(_)
}

///|
pub fn ScheduleBook::get(self : ScheduleBook, name : String) -> NamedSchedule? {
  match self.index_of(name) {
    Some(index) => Some(self.entries[index])
    None => None
  }
}

///|
pub fn ScheduleBook::names(self : ScheduleBook) -> Array[String] {
  self.entries.map(entry => entry.name)
}

///|
pub fn ScheduleBook::all(self : ScheduleBook) -> Array[NamedSchedule] {
  self.entries.copy()
}

///|
/// Add a unique name.
pub fn ScheduleBook::add(
  self : ScheduleBook,
  entry : NamedSchedule,
) -> Result[Unit, CronError] {
  if self.contains(entry.name) {
    return Err(DuplicateSchedule(entry.name))
  }
  self.entries.push(entry)
  Ok(())
}

///|
/// Insert a new entry or replace the existing entry with the same name.
pub fn ScheduleBook::upsert(self : ScheduleBook, entry : NamedSchedule) -> Unit {
  match self.index_of(entry.name) {
    Some(index) => self.entries[index] = entry
    None => self.entries.push(entry)
  }
}

///|
pub fn ScheduleBook::remove(
  self : ScheduleBook,
  name : String,
) -> Result[NamedSchedule, CronError] {
  match self.index_of(name) {
    Some(index) => Ok(self.entries.remove(index))
    None => Err(MissingSchedule(name))
  }
}

///|
pub fn ScheduleBook::set_enabled(
  self : ScheduleBook,
  name : String,
  enabled : Bool,
) -> Result[Unit, CronError] {
  match self.index_of(name) {
    Some(index) => {
      self.entries[index] = self.entries[index].with_enabled(enabled)
      Ok(())
    }
    None => Err(MissingSchedule(name))
  }
}

///|
pub fn ScheduleBook::replace_cron(
  self : ScheduleBook,
  name : String,
  cron : Cron,
) -> Result[Unit, CronError] {
  match self.index_of(name) {
    Some(index) =>
      match self.entries[index].with_cron(cron) {
        Ok(updated) => {
          self.entries[index] = updated
          Ok(())
        }
        Err(error) => Err(error)
      }
    None => Err(MissingSchedule(name))
  }
}

///|
/// Schedules due at this exact minute, in registry order.
pub fn ScheduleBook::due_at(
  self : ScheduleBook,
  at : UtcDateTime,
) -> Array[NamedSchedule] {
  let due : Array[NamedSchedule] = []
  for entry in self.entries {
    if entry.enabled && entry.cron.matches_at(at) {
      due.push(entry)
    }
  }
  due
}

///|
pub struct ScheduledEvent {
  schedule_name : String
  at : UtcDateTime
} derive(Eq, Debug)

///|
fn ScheduledEvent::comes_before(
  self : ScheduledEvent,
  other : ScheduledEvent,
) -> Bool {
  self.at < other.at ||
  (self.at == other.at && self.schedule_name < other.schedule_name)
}

///|
fn sort_events(events : Array[ScheduledEvent]) -> Unit {
  for index in 1..<events.length() {
    let current = events[index]
    let mut position = index
    for ;; {
      if position <= 0 || !current.comes_before(events[position - 1]) {
        break
      }
      events[position] = events[position - 1]
      position -= 1
    }
    events[position] = current
  }
}

///|
/// Merge enabled schedules into a chronological event stream.
pub fn ScheduleBook::events(
  self : ScheduleBook,
  range : DateTimeRange,
  per_schedule_limit? : Int = 10000,
) -> Array[ScheduledEvent] {
  let events : Array[ScheduledEvent] = []
  if per_schedule_limit <= 0 {
    return events
  }
  let query = OccurrenceQuery::new(range, per_schedule_limit).unwrap()
  for entry in self.entries {
    if entry.enabled {
      for at in entry.cron.occurrences(query) {
        events.push({ schedule_name: entry.name, at })
      }
    }
  }
  sort_events(events)
  events
}

///|
/// Next event from each enabled schedule after the cursor.
pub fn ScheduleBook::next_events_after(
  self : ScheduleBook,
  cursor : UtcDateTime,
) -> Array[ScheduledEvent] {
  let events : Array[ScheduledEvent] = []
  for entry in self.entries {
    if entry.enabled {
      match entry.cron.next_after(cursor) {
        Some(at) => events.push({ schedule_name: entry.name, at })
        None => ()
      }
    }
  }
  sort_events(events)
  events
}

///|
/// Batch of events sharing a minute.
pub struct EventBatch {
  at : UtcDateTime
  schedule_names : Array[String]
} derive(Eq, Debug)

///|
pub fn ScheduleBook::event_batches(
  self : ScheduleBook,
  range : DateTimeRange,
  per_schedule_limit? : Int = 10000,
) -> Array[EventBatch] {
  let batches : Array[EventBatch] = []
  for event in self.events(range, per_schedule_limit~) {
    if batches.length() == 0 || batches[batches.length() - 1].at != event.at {
      batches.push({ at: event.at, schedule_names: [event.schedule_name] })
    } else {
      batches[batches.length() - 1].schedule_names.push(event.schedule_name)
    }
  }
  batches
}

///|
pub struct NamedCollision {
  left_name : String
  right_name : String
  at : UtcDateTime
} derive(Eq, Debug)

///|
/// Pairwise collisions among enabled schedules.
pub fn ScheduleBook::collisions(
  self : ScheduleBook,
  range : DateTimeRange,
  per_pair_limit? : Int = 100,
) -> Array[NamedCollision] {
  let result : Array[NamedCollision] = []
  if per_pair_limit <= 0 {
    return result
  }
  for left_index in 0..<self.entries.length() {
    let left = self.entries[left_index]
    if !left.enabled {
      continue
    }
    for right_index in (left_index + 1)..<self.entries.length() {
      let right = self.entries[right_index]
      if right.enabled {
        for
          collision in left.cron.collisions_with(
            right.cron,
            range,
            limit=per_pair_limit,
          ) {
          result.push({
            left_name: left.name,
            right_name: right.name,
            at: collision.at,
          })
        }
      }
    }
  }
  result
}

///|
pub struct ScheduleAudit {
  total : Int
  enabled : Int
  disabled_names : Array[String]
  dormant_names : Array[String]
  collision_pairs : Int
} derive(Eq, Debug)

///|
/// Audit enabled schedules inside a representative window.
pub fn ScheduleBook::audit(
  self : ScheduleBook,
  range : DateTimeRange,
) -> ScheduleAudit {
  let disabled : Array[String] = []
  let dormant : Array[String] = []
  for entry in self.entries {
    if !entry.enabled {
      disabled.push(entry.name)
    } else if !entry.cron.has_occurrence(range) {
      dormant.push(entry.name)
    }
  }
  let collisions = self.collisions(range, per_pair_limit=1)
  {
    total: self.length(),
    enabled: self.enabled_length(),
    disabled_names: disabled,
    dormant_names: dormant,
    collision_pairs: collisions.length(),
  }
}

///|
/// Copy only enabled entries into a new independent registry.
pub fn ScheduleBook::enabled_only(self : ScheduleBook) -> ScheduleBook {
  let entries : Array[NamedSchedule] = []
  for entry in self.entries {
    if entry.enabled {
      entries.push(entry)
    }
  }
  { entries, }
}

///|
/// Human-readable inventory with one schedule per line.
pub fn ScheduleBook::to_text(self : ScheduleBook) -> String {
  let writer = StringBuilder::new()
  for index, entry in self.entries {
    if index > 0 {
      writer.write_char('\n')
    }
    writer.write_string(
      if entry.enabled {
        "[enabled] "
      } else {
        "[disabled] "
      },
    )
    writer.write_string(entry.name)
    writer.write_string(": ")
    writer.write_string(entry.cron.to_expression())
  }
  writer.to_string()
}
