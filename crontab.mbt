///|
/// An environment assignment declared in a crontab document.
pub struct CrontabVariable {
  name : String
  value : String
  line_number : Int
} derive(Eq, Debug)

///|
/// Construct a validated crontab environment assignment.
pub fn CrontabVariable::new(
  name : String,
  value : String,
  line_number? : Int = 0,
) -> Result[CrontabVariable, CronError] {
  if !valid_variable_name(name) {
    Err(InvalidCrontabLine(line_number, "invalid environment variable name"))
  } else {
    Ok({ name, value, line_number })
  }
}

///|
/// A schedulable command from a crontab document.
pub struct CrontabEntry {
  schedule_text : String
  cron : Cron
  command : String
  line_number : Int
} derive(Eq, Debug)

///|
pub fn CrontabEntry::new(
  schedule_text : String,
  command : String,
  line_number? : Int = 0,
) -> Result[CrontabEntry, CronError] {
  if command.trim().length() == 0 {
    return Err(InvalidCrontabLine(line_number, "command must not be empty"))
  }
  match parse(schedule_text) {
    Ok(cron) => Ok({ schedule_text, cron, command, line_number })
    Err(_) => Err(InvalidCrontabLine(line_number, "invalid cron expression"))
  }
}

///|
/// Replace a command while preserving its schedule and source line.
pub fn CrontabEntry::with_command(
  self : CrontabEntry,
  command : String,
) -> Result[CrontabEntry, CronError] {
  if command.trim().length() == 0 {
    Err(InvalidCrontabLine(self.line_number, "command must not be empty"))
  } else {
    Ok({ ..self, command, })
  }
}

///|
/// Replace a schedule while preserving the command and source line.
pub fn CrontabEntry::with_schedule(
  self : CrontabEntry,
  schedule_text : String,
) -> Result[CrontabEntry, CronError] {
  match parse(schedule_text) {
    Ok(cron) => Ok({ ..self, schedule_text, cron })
    Err(_) =>
      Err(InvalidCrontabLine(self.line_number, "invalid cron expression"))
  }
}

///|
/// True when this command is due at the supplied UTC minute.
pub fn CrontabEntry::matches_at(self : CrontabEntry, at : UtcDateTime) -> Bool {
  self.cron.matches_at(at)
}

///|
/// A source-preserving crontab line.
pub(all) enum CrontabLine {
  Blank
  Comment(String)
  Variable(CrontabVariable)
  Entry(CrontabEntry)
} derive(Eq, Debug)

///|
/// A parsed crontab document. Blank lines and comments are retained so tools
/// can inspect and render documents without throwing away useful context.
pub struct CrontabDocument {
  lines : Array[CrontabLine]
} derive(Eq, Debug)

///|
pub fn CrontabDocument::new() -> CrontabDocument {
  { lines: [] }
}

///|
pub fn CrontabDocument::from_lines(
  lines : Array[CrontabLine],
) -> CrontabDocument {
  { lines: lines.copy() }
}

///|
pub fn CrontabDocument::line_count(self : CrontabDocument) -> Int {
  self.lines.length()
}

///|
pub fn CrontabDocument::entry_count(self : CrontabDocument) -> Int {
  let mut count = 0
  for line in self.lines {
    if line is Entry(_) {
      count += 1
    }
  }
  count
}

///|
pub fn CrontabDocument::variable_count(self : CrontabDocument) -> Int {
  let mut count = 0
  for line in self.lines {
    if line is Variable(_) {
      count += 1
    }
  }
  count
}

///|
pub fn CrontabDocument::comment_count(self : CrontabDocument) -> Int {
  let mut count = 0
  for line in self.lines {
    if line is Comment(_) {
      count += 1
    }
  }
  count
}

///|
pub fn CrontabDocument::all_lines(self : CrontabDocument) -> Array[CrontabLine] {
  self.lines.copy()
}

///|
pub fn CrontabDocument::entries(self : CrontabDocument) -> Array[CrontabEntry] {
  let result : Array[CrontabEntry] = []
  for line in self.lines {
    match line {
      Entry(entry) => result.push(entry)
      _ => ()
    }
  }
  result
}

///|
pub fn CrontabDocument::variables(
  self : CrontabDocument,
) -> Array[CrontabVariable] {
  let result : Array[CrontabVariable] = []
  for line in self.lines {
    match line {
      Variable(variable) => result.push(variable)
      _ => ()
    }
  }
  result
}

///|
pub fn CrontabDocument::comments(self : CrontabDocument) -> Array[String] {
  let result : Array[String] = []
  for line in self.lines {
    match line {
      Comment(comment) => result.push(comment)
      _ => ()
    }
  }
  result
}

///|
pub fn CrontabDocument::append_entry(
  self : CrontabDocument,
  entry : CrontabEntry,
) -> Unit {
  self.lines.push(Entry(entry))
}

///|
pub fn CrontabDocument::append_variable(
  self : CrontabDocument,
  variable : CrontabVariable,
) -> Unit {
  self.lines.push(Variable(variable))
}

///|
pub fn CrontabDocument::append_comment(
  self : CrontabDocument,
  comment : String,
) -> Unit {
  self.lines.push(Comment(comment))
}

///|
pub fn CrontabDocument::append_blank(self : CrontabDocument) -> Unit {
  self.lines.push(Blank)
}

///|
/// Return the last value assigned to `name`, matching crontab override rules.
pub fn CrontabDocument::variable(
  self : CrontabDocument,
  name : String,
) -> String? {
  let mut result : String? = None
  for line in self.lines {
    match line {
      Variable(variable) if variable.name == name =>
        result = Some(variable.value)
      _ => ()
    }
  }
  result
}

///|
/// Entries whose command contains a literal text fragment.
pub fn CrontabDocument::find_commands(
  self : CrontabDocument,
  fragment : String,
) -> Array[CrontabEntry] {
  let result : Array[CrontabEntry] = []
  for entry in self.entries() {
    if entry.command.contains(fragment) {
      result.push(entry)
    }
  }
  result
}

///|
/// Commands due at an exact UTC minute, in document order.
pub fn CrontabDocument::due_at(
  self : CrontabDocument,
  at : UtcDateTime,
) -> Array[CrontabEntry] {
  let result : Array[CrontabEntry] = []
  for entry in self.entries() {
    if entry.matches_at(at) {
      result.push(entry)
    }
  }
  result
}

///|
/// Convert document entries to a named schedule registry. Line numbers make
/// otherwise duplicate commands independently addressable.
pub fn CrontabDocument::to_schedule_book(
  self : CrontabDocument,
) -> ScheduleBook {
  let book = ScheduleBook::new()
  for entry in self.entries() {
    let name = "line-" + entry.line_number.to_string()
    book.add(NamedSchedule::new(name, entry.cron).unwrap()).unwrap()
  }
  book
}

///|
/// Remove all comments and blank lines while preserving executable semantics.
pub fn CrontabDocument::compact(self : CrontabDocument) -> CrontabDocument {
  let result : Array[CrontabLine] = []
  for line in self.lines {
    match line {
      Variable(_) | Entry(_) => result.push(line)
      _ => ()
    }
  }
  { lines: result }
}

///|
/// Render a normalized document. Cron macros are retained as entered, while
/// whitespace between schedule fields and commands is canonicalized.
pub fn CrontabDocument::to_text(self : CrontabDocument) -> String {
  let writer = StringBuilder::new()
  for index, line in self.lines {
    if index > 0 {
      writer.write_char('\n')
    }
    match line {
      Blank => ()
      Comment(comment) => {
        writer.write_char('#')
        if comment.length() > 0 {
          writer.write_char(' ')
          writer.write_string(comment)
        }
      }
      Variable(variable) => {
        writer.write_string(variable.name)
        writer.write_char('=')
        writer.write_string(variable.value)
      }
      Entry(entry) => {
        writer.write_string(entry.schedule_text)
        writer.write_char(' ')
        writer.write_string(entry.command)
      }
    }
  }
  writer.to_string()
}

///|
fn valid_variable_name(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  for index, char in name {
    let code = char.to_int()
    let alphabetic = (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
    let numeric = code >= 48 && code <= 57
    if index == 0 {
      if !alphabetic && code != 95 {
        return false
      }
    } else if !alphabetic && !numeric && code != 95 {
      return false
    }
  }
  true
}

///|
fn split_assignment(line : String) -> (String, String)? {
  let name = StringBuilder::new()
  let value = StringBuilder::new()
  let mut found = false
  for char in line {
    if !found && char == '=' {
      found = true
    } else if found {
      value.write_char(char)
    } else {
      name.write_char(char)
    }
  }
  if found {
    Some(
      (name.to_string().trim().to_owned(), value.to_string().trim().to_owned()),
    )
  } else {
    None
  }
}

///|
fn join_tokens(tokens : Array[String], start : Int, end : Int) -> String {
  let writer = StringBuilder::new()
  for index in start..<end {
    if index > start {
      writer.write_char(' ')
    }
    writer.write_string(tokens[index])
  }
  writer.to_string()
}

///|
fn parse_crontab_entry(
  trimmed : String,
  line_number : Int,
) -> Result[CrontabEntry, CronError] {
  let tokens = tokenize(trimmed)
  if tokens.length() == 0 {
    return Err(InvalidCrontabLine(line_number, "empty entry"))
  }
  let macro_entry = starts_with_at(tokens[0])
  let schedule_fields = if macro_entry { 1 } else { 5 }
  if tokens.length() <= schedule_fields {
    return Err(InvalidCrontabLine(line_number, "entry has no command"))
  }
  let schedule_text = join_tokens(tokens, 0, schedule_fields)
  let command = join_tokens(tokens, schedule_fields, tokens.length())
  CrontabEntry::new(schedule_text, command, line_number~)
}

///|
fn parse_crontab_line(
  source : String,
  line_number : Int,
) -> Result[CrontabLine, CronError] {
  let trimmed = source.trim().to_owned()
  if trimmed.length() == 0 {
    return Ok(Blank)
  }
  if trimmed[0] == '#' {
    let comment = StringBuilder::new()
    let mut first = true
    for char in trimmed {
      if first {
        first = false
      } else {
        comment.write_char(char)
      }
    }
    return Ok(Comment(comment.to_string().trim().to_owned()))
  }
  match split_assignment(trimmed) {
    Some((name, value)) if valid_variable_name(name) =>
      Ok(Variable(CrontabVariable::new(name, value, line_number~).unwrap()))
    _ =>
      match parse_crontab_entry(trimmed, line_number) {
        Ok(entry) => Ok(Entry(entry))
        Err(error) => Err(error)
      }
  }
}

///|
/// Parse a portable crontab document. Each error carries the one-based source
/// line number needed by editors and CI diagnostics.
pub fn parse_crontab(text : String) -> Result[CrontabDocument, CronError] {
  let lines : Array[CrontabLine] = []
  let mut line_number = 0
  for view in text.split("\n") {
    line_number += 1
    let source = view.to_owned().replace(old="\r", new="")
    match parse_crontab_line(source, line_number) {
      Ok(line) => lines.push(line)
      Err(error) => return Err(error)
    }
  }
  Ok({ lines, })
}
