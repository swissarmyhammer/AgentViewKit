import FoundationModelsACP
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

  /// The validation state that the field shows.
  ///
  /// ``ElicitationView`` gives ``FieldValidationState/satisfied`` until the
  /// user changes the answer of the field or tries to submit the form, so a
  /// new form shows no error. After that, it gives the state of the current
  /// answer.
  public let validation: FieldValidationState

  /// `true` when the answer is sensitive, such as a secret: the agent marks
  /// the request with `"sensitive": true` in its `_meta`
  /// (``FoundationModelsACPClient/PendingElicitation/isSensitive``).
  ///
  /// The field stays a plain text field (the user decided against a masked
  /// field). A field view must not log the answer, keep it after the form
  /// closes, put it in undo history, or put it on the pasteboard by an
  /// automatic action. ``ElicitationTextField`` edits a model that keeps no
  /// undo history for a sensitive answer.
  public let isSensitive: Bool

  /// Makes a context.
  ///
  /// - Parameters:
  ///   - schema: The field schema.
  ///   - value: The binding to the answer of the field.
  ///   - validation: The validation state of the answer.
  ///   - isSensitive: `true` when the answer is sensitive.
  public init(
    schema: ElicitationFieldSchema,
    value: Binding<JSONValue?>,
    validation: FieldValidationState,
    isSensitive: Bool = false
  ) {
    self.schema = schema
    self.value = value
    self.validation = validation
    self.isSensitive = isSensitive
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
