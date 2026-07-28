///|
/// The semantic domain in which a cron field is evaluated.
pub(all) enum FieldDomain {
  MinuteDomain
  HourDomain
  DayOfMonthDomain
  MonthDomain
  WeekdayDomain
} derive(Eq, Debug)

///|
/// Programmatic exact-value field. Use `Cron::from_fields` to validate it
/// against its eventual position.
pub fn Field::exact(value : Int) -> Field {
  Exact(value)
}

///|
pub fn Field::any() -> Field {
  Any
}

///|
pub fn Field::every(step : Int) -> Field {
  Every(step)
}

///|
pub fn Field::range(start : Int, end : Int) -> Field {
  Range(start, end)
}

///|
pub fn Field::range_every(start : Int, end : Int, step : Int) -> Field {
  RangeEvery(start, end, step)
}

///|
pub fn Field::list(items : Array[Field]) -> Field {
  List(items)
}

///|
pub fn FieldDomain::bounds(self : FieldDomain) -> (Int, Int) {
  match self {
    MinuteDomain => (0, 59)
    HourDomain => (0, 23)
    DayOfMonthDomain => (1, 31)
    MonthDomain => (1, 12)
    WeekdayDomain => (0, 6)
  }
}

///|
pub fn FieldDomain::name(self : FieldDomain) -> String {
  match self {
    MinuteDomain => "minute"
    HourDomain => "hour"
    DayOfMonthDomain => "day-of-month"
    MonthDomain => "month"
    WeekdayDomain => "weekday"
  }
}

///|
fn Field::matches_domain(
  self : Field,
  value : Int,
  domain : FieldDomain,
) -> Bool {
  let bounds = domain.bounds()
  if domain is WeekdayDomain {
    self.matches(value, lower=bounds.0) ||
    (value == 0 && self.matches(7, lower=bounds.0))
  } else {
    self.matches(value, lower=bounds.0)
  }
}

///|
/// Sorted unique values accepted inside the supplied domain.
pub fn Field::values(self : Field, domain : FieldDomain) -> Array[Int] {
  let bounds = domain.bounds()
  let values : Array[Int] = []
  for value in bounds.0..<=bounds.1 {
    if self.matches_domain(value, domain) {
      values.push(value)
    }
  }
  values
}

///|
pub fn Field::cardinality(self : Field, domain : FieldDomain) -> Int {
  self.values(domain).length()
}

///|
pub fn Field::is_empty_in(self : Field, domain : FieldDomain) -> Bool {
  self.cardinality(domain) == 0
}

///|
pub fn Field::is_full_in(self : Field, domain : FieldDomain) -> Bool {
  let bounds = domain.bounds()
  self.cardinality(domain) == bounds.1 - bounds.0 + 1
}

///|
pub fn Field::first(self : Field, domain : FieldDomain) -> Int? {
  let values = self.values(domain)
  if values.length() == 0 {
    None
  } else {
    Some(values[0])
  }
}

///|
pub fn Field::last(self : Field, domain : FieldDomain) -> Int? {
  let values = self.values(domain)
  if values.length() == 0 {
    None
  } else {
    Some(values[values.length() - 1])
  }
}

///|
/// First accepted value greater than or equal to `value`.
pub fn Field::next_at_or_after(
  self : Field,
  value : Int,
  domain : FieldDomain,
) -> Int? {
  for candidate in self.values(domain) {
    if candidate >= value {
      return Some(candidate)
    }
  }
  None
}

///|
/// Last accepted value less than or equal to `value`.
pub fn Field::previous_at_or_before(
  self : Field,
  value : Int,
  domain : FieldDomain,
) -> Int? {
  let values = self.values(domain)
  for index = values.length() - 1; index >= 0; index = index - 1 {
    if values[index] <= value {
      return Some(values[index])
    }
  }
  None
}

///|
fn contains_int(values : Array[Int], value : Int) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn exact_field_from_values(values : Array[Int], domain : FieldDomain) -> Field {
  let bounds = domain.bounds()
  if values.length() == bounds.1 - bounds.0 + 1 {
    return Any
  }
  if values.length() == 1 {
    return Exact(values[0])
  }
  List(values.map(value => Exact(value)))
}

///|
/// Semantic intersection, independent of the original expression spelling.
pub fn Field::intersection(
  self : Field,
  other : Field,
  domain : FieldDomain,
) -> Field {
  let values : Array[Int] = []
  let other_values = other.values(domain)
  for value in self.values(domain) {
    if contains_int(other_values, value) {
      values.push(value)
    }
  }
  exact_field_from_values(values, domain)
}

///|
/// Semantic union, returned in ascending canonical order.
pub fn Field::union(self : Field, other : Field, domain : FieldDomain) -> Field {
  let values : Array[Int] = []
  let left = self.values(domain)
  let right = other.values(domain)
  let bounds = domain.bounds()
  for value in bounds.0..<=bounds.1 {
    if contains_int(left, value) || contains_int(right, value) {
      values.push(value)
    }
  }
  exact_field_from_values(values, domain)
}

///|
/// Values accepted by `self` but rejected by `other`.
pub fn Field::difference(
  self : Field,
  other : Field,
  domain : FieldDomain,
) -> Field {
  let values : Array[Int] = []
  let other_values = other.values(domain)
  for value in self.values(domain) {
    if !contains_int(other_values, value) {
      values.push(value)
    }
  }
  exact_field_from_values(values, domain)
}

///|
pub fn Field::overlaps(
  self : Field,
  other : Field,
  domain : FieldDomain,
) -> Bool {
  !self.intersection(other, domain).is_empty_in(domain)
}

///|
pub fn Field::is_subset_of(
  self : Field,
  other : Field,
  domain : FieldDomain,
) -> Bool {
  let other_values = other.values(domain)
  for value in self.values(domain) {
    if !contains_int(other_values, value) {
      return false
    }
  }
  true
}

///|
pub fn Field::equivalent_to(
  self : Field,
  other : Field,
  domain : FieldDomain,
) -> Bool {
  self.values(domain) == other.values(domain)
}

///|
/// A compact arithmetic-run representation of a semantic field.
pub fn Field::normalized(self : Field, domain : FieldDomain) -> Field {
  let values = self.values(domain)
  let bounds = domain.bounds()
  if values.length() == 0 {
    return List([])
  }
  if values.length() == bounds.1 - bounds.0 + 1 {
    return Any
  }
  if values.length() == 1 {
    return Exact(values[0])
  }
  let parts : Array[Field] = []
  let mut index = 0
  for ;; {
    if index >= values.length() {
      break
    }
    if index + 2 < values.length() {
      let step = values[index + 1] - values[index]
      let mut end_index = index + 1
      for ;; {
        if end_index + 1 >= values.length() ||
          values[end_index + 1] - values[end_index] != step {
          break
        }
        end_index += 1
      }
      if end_index - index + 1 >= 3 {
        if step == 1 {
          parts.push(Range(values[index], values[end_index]))
        } else {
          parts.push(RangeEvery(values[index], values[end_index], step))
        }
        index = end_index + 1
        continue
      }
    }
    parts.push(Exact(values[index]))
    index += 1
  }
  if parts.length() == 1 {
    parts[0]
  } else {
    List(parts)
  }
}

///|
fn Field::validate_in(
  self : Field,
  domain : FieldDomain,
) -> Result[Unit, CronError] {
  let bounds = domain.bounds()
  let fail = () => {
    Err(InvalidField(domain.name() + ": " + self.to_expression()))
  }
  match self {
    Any => Ok(())
    Exact(value) =>
      if domain is WeekdayDomain && value == 7 {
        Ok(())
      } else if value >= bounds.0 && value <= bounds.1 {
        Ok(())
      } else {
        fail()
      }
    Every(step) =>
      if step >= 1 && step <= bounds.1 - bounds.0 + 1 {
        Ok(())
      } else {
        fail()
      }
    Range(start, end) =>
      if start >= bounds.0 && end <= bounds.1 && start <= end {
        Ok(())
      } else if domain is WeekdayDomain &&
        start >= 0 &&
        end <= 7 &&
        start <= end {
        Ok(())
      } else {
        fail()
      }
    RangeEvery(start, end, step) =>
      if start >= bounds.0 &&
        end <= bounds.1 &&
        start <= end &&
        step >= 1 &&
        step <= bounds.1 - bounds.0 + 1 {
        Ok(())
      } else if domain is WeekdayDomain &&
        start >= 0 &&
        end <= 7 &&
        start <= end &&
        step >= 1 &&
        step <= 8 {
        Ok(())
      } else {
        fail()
      }
    List(items) => {
      if items.length() == 0 {
        return fail()
      }
      for item in items {
        match item.validate_in(domain) {
          Err(error) => return Err(error)
          Ok(_) => ()
        }
      }
      Ok(())
    }
  }
}

///|
/// Validate a programmatically constructed schedule.
pub fn Cron::validate(self : Cron) -> Result[Unit, CronError] {
  match
    (
      self.minute.validate_in(MinuteDomain),
      self.hour.validate_in(HourDomain),
      self.day_of_month.validate_in(DayOfMonthDomain),
      self.month.validate_in(MonthDomain),
      self.weekday.validate_in(WeekdayDomain),
    ) {
    (Ok(_), Ok(_), Ok(_), Ok(_), Ok(_)) => Ok(())
    (Err(error), _, _, _, _) => Err(error)
    (_, Err(error), _, _, _) => Err(error)
    (_, _, Err(error), _, _) => Err(error)
    (_, _, _, Err(error), _) => Err(error)
    (_, _, _, _, Err(error)) => Err(error)
  }
}

///|
/// Construct and validate a schedule from programmatic fields.
pub fn Cron::from_fields(
  minute : Field,
  hour : Field,
  day_of_month : Field,
  month : Field,
  weekday : Field,
) -> Result[Cron, CronError] {
  let cron : Cron = { minute, hour, day_of_month, month, weekday }
  match cron.validate() {
    Ok(_) => Ok(cron)
    Err(error) => Err(error)
  }
}

///|
/// Normalize every field while preserving matching semantics.
pub fn Cron::normalized(self : Cron) -> Cron {
  {
    minute: self.minute.normalized(MinuteDomain),
    hour: self.hour.normalized(HourDomain),
    day_of_month: self.day_of_month.normalized(DayOfMonthDomain),
    month: self.month.normalized(MonthDomain),
    weekday: self.weekday.normalized(WeekdayDomain),
  }
}

///|
/// Structural facts useful for diagnostics and user interfaces.
pub struct CronFieldSummary {
  minute_values : Int
  hour_values : Int
  day_of_month_values : Int
  month_values : Int
  weekday_values : Int
  unrestricted_fields : Int
} derive(Eq, Debug)

///|
pub fn Cron::field_summary(self : Cron) -> CronFieldSummary {
  let domains = [
    (self.minute, MinuteDomain),
    (self.hour, HourDomain),
    (self.day_of_month, DayOfMonthDomain),
    (self.month, MonthDomain),
    (self.weekday, WeekdayDomain),
  ]
  let mut unrestricted = 0
  for item in domains {
    if item.0.is_full_in(item.1) {
      unrestricted += 1
    }
  }
  {
    minute_values: self.minute.cardinality(MinuteDomain),
    hour_values: self.hour.cardinality(HourDomain),
    day_of_month_values: self.day_of_month.cardinality(DayOfMonthDomain),
    month_values: self.month.cardinality(MonthDomain),
    weekday_values: self.weekday.cardinality(WeekdayDomain),
    unrestricted_fields: unrestricted,
  }
}

///|
/// Coarse upper bound on runs in a 24-hour day, ignoring date fields.
pub fn Cron::maximum_daily_runs(self : Cron) -> Int {
  self.minute.cardinality(MinuteDomain) * self.hour.cardinality(HourDomain)
}

///|
/// True when two schedules can share at least one minute/hour/month and
/// calendar selector. This is a fast preflight; use occurrence queries for
/// an exact answer inside a bounded date range.
pub fn Cron::may_overlap(self : Cron, other : Cron) -> Bool {
  if !self.minute.overlaps(other.minute, MinuteDomain) ||
    !self.hour.overlaps(other.hour, HourDomain) ||
    !self.month.overlaps(other.month, MonthDomain) {
    return false
  }
  self.day_of_month.overlaps(other.day_of_month, DayOfMonthDomain) ||
  self.weekday.overlaps(other.weekday, WeekdayDomain)
}
