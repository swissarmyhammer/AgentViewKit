import SwiftUI

/// The data that the kit gives to each elicitation field view
/// (plan.md §13.2).
///
/// A default field view and an override get the same context. The view reads
/// ``schema``, shows the answer of ``value``, writes a new answer to
/// ``value``, and shows the errors of ``validation``.
public struct ElicitationFieldContext {
  /// The field schema: the title, the description, the constraints, the
  /// format, and the choices.
  public let schema: ElicitationFieldSchema

  /// The current answer of the field. `nil` means that there is no answer.
  public let value: Binding<JSONValue?>

  /// The validation state of the current answer.
  public let validation: FieldValidationState

  /// Makes a context.
  ///
  /// - Parameters:
  ///   - schema: The field schema.
  ///   - value: The binding to the answer of the field.
  ///   - validation: The validation state of the answer.
  public init(
    schema: ElicitationFieldSchema,
    value: Binding<JSONValue?>,
    validation: FieldValidationState
  ) {
    self.schema = schema
    self.value = value
    self.validation = validation
  }

  /// Makes a context that validates the current answer with
  /// ``ElicitationValidator/validate(_:against:)``.
  ///
  /// - Parameters:
  ///   - schema: The field schema.
  ///   - value: The binding to the answer of the field.
  public init(schema: ElicitationFieldSchema, value: Binding<JSONValue?>) {
    self.init(
      schema: schema,
      value: value,
      validation: ElicitationValidator.validate(value.wrappedValue, against: schema)
    )
  }

  /// The accessibility identifier of the field.
  ///
  /// This is `elicitation-field-<name>`. See
  /// ``ElicitationFieldView/identifier(for:)``.
  public var identifier: String {
    ElicitationFieldView.identifier(for: schema.name)
  }

  /// The accessibility identifier of the main control of the field.
  ///
  /// This is `elicitation-field-<name>-control`.
  public var controlIdentifier: String {
    ElicitationFieldView.controlIdentifier(for: schema.name)
  }
}
