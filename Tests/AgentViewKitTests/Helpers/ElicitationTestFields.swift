import AgentViewKit

/// The field kinds and the field schemas that the elicitation suites share.
///
/// The validator tests and the issue text tests make their fields here, so
/// that each helper has one source. The members are nonisolated, because
/// `@Test(arguments:)` lists use them outside the main actor.
nonisolated enum ElicitationTestFields {
  /// The choice values of ``multiChoice(choices:minItems:maxItems:)`` when
  /// the caller gives no choices.
  static let defaultChoiceValues = ["a", "b", "c"]

  /// Makes a field schema with no description and no default value.
  ///
  /// - Parameters:
  ///   - kind: The kind of the field.
  ///   - name: The property name of the field.
  ///   - title: The title of the field.
  ///   - required: Whether the field is required.
  /// - Returns: The field schema.
  static func field(
    _ kind: ElicitationFieldSchema.Kind,
    name: String = "field",
    title: String = "Field",
    required: Bool = false
  ) -> ElicitationFieldSchema {
    ElicitationFieldSchema(
      name: name, title: title, description: nil, required: required, kind: kind,
      defaultValue: nil)
  }

  /// Makes a text kind with the given constraints.
  ///
  /// - Parameters:
  ///   - minLength: The minimum number of code points, or `nil` for no minimum.
  ///   - maxLength: The maximum number of code points, or `nil` for no maximum.
  ///   - pattern: The pattern that the text must match, or `nil` for no pattern.
  ///   - format: The format of the text, or `nil` for no format.
  /// - Returns: The text kind.
  static func text(
    minLength: Int? = nil,
    maxLength: Int? = nil,
    pattern: String? = nil,
    format: ElicitationFieldSchema.TextFormat? = nil
  ) -> ElicitationFieldSchema.Kind {
    .text(minLength: minLength, maxLength: maxLength, pattern: pattern, format: format)
  }

  /// Makes one choice for each value. The title of each choice is its value.
  ///
  /// - Parameter values: The values of the choices, in order.
  /// - Returns: The choices.
  static func choices(_ values: [String]) -> [ElicitationFieldSchema.Choice] {
    values.map { ElicitationFieldSchema.Choice(const: $0, title: $0) }
  }

  /// Makes a multi-choice kind with the given choices and item limits.
  ///
  /// - Parameters:
  ///   - values: The values of the choices. The title of each choice is its
  ///     value.
  ///   - minItems: The minimum number of items, or `nil` for no minimum.
  ///   - maxItems: The maximum number of items, or `nil` for no maximum.
  /// - Returns: The multi-choice kind.
  static func multiChoice(
    choices values: [String] = defaultChoiceValues,
    minItems: Int? = nil,
    maxItems: Int? = nil
  ) -> ElicitationFieldSchema.Kind {
    .multiChoice(choices(values), minItems: minItems, maxItems: maxItems)
  }
}
