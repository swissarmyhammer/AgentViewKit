import Foundation

/// The validation result of one elicitation field (plan.md §13.1, §13.2).
///
/// A field view shows ``errors``. `ElicitationView` enables Submit only when
/// each field ``isSatisfied``.
public nonisolated struct FieldValidationState: Sendable, Hashable {
  /// The messages for each failed constraint, in the order of the checks.
  public var errors: [String]

  /// Whether the answer passes each constraint. This is `true` when
  /// ``errors`` is empty.
  public var isSatisfied: Bool { errors.isEmpty }

  /// Makes a validation state.
  ///
  /// - Parameter errors: The messages for each failed constraint.
  public init(errors: [String]) {
    self.errors = errors
  }

  /// The state of an answer that passes each constraint.
  public static let satisfied = FieldValidationState(errors: [])
}

/// The local validation of elicitation answers (plan.md §13.1).
///
/// The kit validates before it sends an answer (plan.md §13.4). The functions
/// are pure, so a view can call them on each change.
public nonisolated enum ElicitationValidator {
  /// Validates one answer against its field schema.
  ///
  /// An answer that is missing, JSON `null`, an empty string, or an empty
  /// array is empty. An empty answer fails only when the field is required.
  /// The other constraints do not apply to an empty answer. `false` is not
  /// empty.
  ///
  /// A `pattern` must match the full text. A pattern that does not compile
  /// as a Swift regular expression is ignored, because the kit cannot apply
  /// it. A ``ElicitationFieldSchema/TextFormat/unknown(_:)`` format is
  /// ignored, as ACP v2 tells a client to do.
  ///
  /// - Parameters:
  ///   - value: The answer, or `nil` when there is no answer.
  ///   - schema: The field schema.
  /// - Returns: The validation state, with one message for each failed
  ///   constraint.
  public static func validate(
    _ value: JSONValue?,
    against schema: ElicitationFieldSchema
  ) -> FieldValidationState {
    guard let value, !isEmpty(value) else {
      return schema.required ? FieldValidationState(errors: [Message.required]) : .satisfied
    }
    return FieldValidationState(errors: errors(for: value, kind: schema.kind))
  }

  /// Tells whether each field of a form passes validation.
  ///
  /// - Parameters:
  ///   - values: The answers, keyed by ``ElicitationFieldSchema/name``.
  ///   - schemas: The field schemas.
  /// - Returns: `true` when each field is satisfied.
  public static func isComplete(
    values: [String: JSONValue],
    schemas: [ElicitationFieldSchema]
  ) -> Bool {
    schemas.allSatisfy { validate(values[$0.name], against: $0).isSatisfied }
  }

  /// Tells whether a field has an answer that passes validation.
  ///
  /// The tab of a field shows the answered mark when this is `true`
  /// (plan.md §13.1).
  ///
  /// - Parameters:
  ///   - value: The answer, or `nil` when there is no answer.
  ///   - schema: The field schema.
  /// - Returns: `true` when the answer is not empty and passes each
  ///   constraint of the field kind.
  public static func isAnswered(
    _ value: JSONValue?,
    against schema: ElicitationFieldSchema
  ) -> Bool {
    guard let value, !isEmpty(value) else { return false }
    return errors(for: value, kind: schema.kind).isEmpty
  }

  // MARK: - Checks

  /// Tells whether an answer is empty.
  private static func isEmpty(_ value: JSONValue) -> Bool {
    switch value {
    case .null: true
    case .string(let text): text.isEmpty
    case .array(let elements): elements.isEmpty
    case .bool, .number, .object: false
    }
  }

  /// The messages for each constraint of `kind` that `value` fails.
  ///
  /// - Parameters:
  ///   - value: An answer that is not empty.
  ///   - kind: The kind of the field.
  /// - Returns: The messages, in the order of the checks.
  private static func errors(for value: JSONValue, kind: ElicitationFieldSchema.Kind) -> [String] {
    switch kind {
    case .text(let minLength, let maxLength, let pattern, let format):
      guard let text = value.stringValue else { return [Message.notText] }
      return textErrors(
        text, minLength: minLength, maxLength: maxLength, pattern: pattern, format: format)
    case .date(let dateTime):
      guard let text = value.stringValue else { return [Message.notText] }
      if dateTime {
        return RFC3339.isDateTime(text) ? [] : [Message.notDateTime]
      }
      return RFC3339.isFullDate(text) ? [] : [Message.notDate]
    case .number(let integer, let minimum, let maximum):
      return numberErrors(value, integer: integer, minimum: minimum, maximum: maximum)
    case .boolean:
      return value.boolValue == nil ? [Message.notBoolean] : []
    case .singleChoice(let choices):
      guard let text = value.stringValue, choices.contains(where: { $0.value == text }) else {
        return [Message.notAChoice]
      }
      return []
    case .multiChoice(let choices, let minItems, let maxItems):
      return multiChoiceErrors(value, choices: choices, minItems: minItems, maxItems: maxItems)
    }
  }

  /// The messages for each text constraint that `text` fails.
  private static func textErrors(
    _ text: String,
    minLength: Int?,
    maxLength: Int?,
    pattern: String?,
    format: ElicitationFieldSchema.TextFormat?
  ) -> [String] {
    var errors: [String] = []
    // JSON Schema counts the length in Unicode code points.
    let length = text.unicodeScalars.count
    if let minLength, length < minLength {
      errors.append(Message.tooShort(minLength))
    }
    if let maxLength, length > maxLength {
      errors.append(Message.tooLong(maxLength))
    }
    if let pattern, !matchesFully(text, pattern: pattern) {
      errors.append(Message.patternMismatch)
    }
    switch format {
    case .email where !isEmailAddress(text):
      errors.append(Message.notEmail)
    case .uri where !isURI(text):
      errors.append(Message.notURI)
    default:
      break
    }
    return errors
  }

  /// The messages for each number constraint that `value` fails.
  private static func numberErrors(
    _ value: JSONValue,
    integer: Bool,
    minimum: Double?,
    maximum: Double?
  ) -> [String] {
    guard let number = value.doubleValue, number.isFinite else { return [Message.notNumber] }
    var errors: [String] = []
    if integer, value.intValue == nil {
      errors.append(Message.notInteger)
    }
    if let minimum, number < minimum {
      errors.append(Message.belowMinimum(minimum))
    }
    if let maximum, number > maximum {
      errors.append(Message.aboveMaximum(maximum))
    }
    return errors
  }

  /// The messages for each multi-choice constraint that `value` fails.
  private static func multiChoiceErrors(
    _ value: JSONValue,
    choices: [ElicitationFieldSchema.Choice],
    minItems: Int?,
    maxItems: Int?
  ) -> [String] {
    guard case .array(let elements) = value else { return [Message.notAList] }
    var errors: [String] = []
    let values = Set(choices.map(\.value))
    let allAreChoices = elements.allSatisfy { element in
      element.stringValue.map(values.contains) ?? false
    }
    if !allAreChoices {
      errors.append(Message.itemNotAChoice)
    }
    if let minItems, elements.count < minItems {
      errors.append(Message.tooFewItems(minItems))
    }
    if let maxItems, elements.count > maxItems {
      errors.append(Message.tooManyItems(maxItems))
    }
    return errors
  }

  /// Tells whether `pattern` matches all of `text`.
  ///
  /// - Returns: `true` for a match, and `true` when the pattern does not
  ///   compile.
  private static func matchesFully(_ text: String, pattern: String) -> Bool {
    guard let regex = try? Regex(pattern) else { return true }
    return (try? regex.wholeMatch(in: text)) != nil
  }

  /// Tells whether `text` has the form `local@domain.tld`, with no space.
  private static func isEmailAddress(_ text: String) -> Bool {
    text.wholeMatch(of: #/[^\s@]+@[^\s@]+\.[^\s@]+/#) != nil
  }

  /// Tells whether `text` is a URI with an RFC 3986 scheme.
  private static func isURI(_ text: String) -> Bool {
    guard text.prefixMatch(of: #/[A-Za-z][A-Za-z0-9+.\-]*:/#) != nil else { return false }
    return URL(string: text, encodingInvalidCharacters: false) != nil
  }

  // MARK: - Messages

  /// The validation messages, in ASD-STE100 Simplified Technical English.
  private enum Message {
    static let required = "This field is necessary."
    static let notText = "The value must be text."
    static let notEmail = "The value must be an email address."
    static let notURI = "The value must be a URI."
    static let patternMismatch = "The text does not match the necessary pattern."
    static let notDate = "The value must be a date in the format YYYY-MM-DD."
    static let notDateTime = "The value must be a date and time in RFC 3339 format."
    static let notNumber = "The value must be a number."
    static let notInteger = "The value must be a whole number."
    static let notBoolean = "The value must be true or false."
    static let notAChoice = "The value must be one of the choices."
    static let notAList = "The value must be a list of choices."
    static let itemNotAChoice = "Each item must be one of the choices."

    static func tooShort(_ count: Int) -> String {
      "The text must have \(count) or more characters."
    }

    static func tooLong(_ count: Int) -> String {
      "The text must have \(count) or fewer characters."
    }

    static func belowMinimum(_ bound: Double) -> String {
      "The value must be \(text(of: bound)) or more."
    }

    static func aboveMaximum(_ bound: Double) -> String {
      "The value must be \(text(of: bound)) or less."
    }

    static func tooFewItems(_ count: Int) -> String {
      "Select \(count) or more items."
    }

    static func tooManyItems(_ count: Int) -> String {
      "Select \(count) or fewer items."
    }

    /// The text of a bound, with no fraction for a whole number.
    private static func text(of bound: Double) -> String {
      Int(exactly: bound).map(String.init) ?? String(bound)
    }
  }
}

// MARK: - RFC 3339

/// The RFC 3339 `full-date` and `date-time` checks.
///
/// The checks read the digits and test them with a fixed Gregorian calendar
/// in UTC. They do not use a date formatter, so the result does not change
/// with the locale or the time zone.
private nonisolated enum RFC3339 {
  /// The number of hours in a day. An hour or an offset hour is less.
  private static let hoursPerDay = 24

  /// The number of minutes in an hour. A minute or an offset minute is less.
  private static let minutesPerHour = 60

  /// The largest second. RFC 3339 allows the second 60 for a leap second.
  private static let maximumSecond = 60

  /// The Gregorian calendar in UTC that validates the day.
  private static let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
  }()

  /// Tells whether `text` is an RFC 3339 `full-date`, for example
  /// `2026-09-16`.
  static func isFullDate(_ text: String) -> Bool {
    guard let match = text.wholeMatch(of: #/(\d{4})-(\d{2})-(\d{2})/#) else { return false }
    return isDate(year: match.1, month: match.2, day: match.3)
  }

  /// Tells whether `text` is an RFC 3339 `date-time`, for example
  /// `2026-09-16T10:00:00Z`.
  static func isDateTime(_ text: String) -> Bool {
    let pattern =
      #/(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(?:[Zz]|[+\-](\d{2}):(\d{2}))/#
    guard let match = text.wholeMatch(of: pattern),
      isDate(year: match.1, month: match.2, day: match.3),
      let hour = Int(match.4), let minute = Int(match.5), let second = Int(match.6)
    else { return false }
    guard hour < hoursPerDay, minute < minutesPerHour, second <= maximumSecond else {
      return false
    }
    if let offsetHour = match.7.flatMap({ Int($0) }),
      let offsetMinute = match.8.flatMap({ Int($0) })
    {
      return offsetHour < hoursPerDay && offsetMinute < minutesPerHour
    }
    return true
  }

  /// Tells whether the digits give a day of the Gregorian calendar.
  private static func isDate(year: Substring, month: Substring, day: Substring) -> Bool {
    guard let year = Int(year), let month = Int(month), let day = Int(day) else { return false }
    let components = DateComponents(year: year, month: month, day: day)
    return components.isValidDate(in: calendar)
  }
}
