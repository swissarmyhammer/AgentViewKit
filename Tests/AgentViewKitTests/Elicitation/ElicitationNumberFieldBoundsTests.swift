import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The bounds of a number field that come from the schema of the agent. The
/// kit does not trust them: a `minimum` above the `maximum` must not stop the
/// app.
@MainActor @Suite struct ElicitationNumberFieldBoundsTests {
  /// The property name of the field of each test.
  static let name = "field"

  /// The lower bound of a field whose bounds are in order, and the upper
  /// bound of a field whose bounds are not in order.
  static let low: Double = 1

  /// The upper bound of a field whose bounds are in order, and the lower
  /// bound of a field whose bounds are not in order.
  static let high: Double = 9

  /// A production change that fails this test: the number field gives the
  /// schema bounds to the stepper as `minimum...maximum` with no check, so
  /// a `minimum` above the `maximum` traps when the field mounts.
  @Test func aFieldWithItsMinimumAboveItsMaximumMountsAndShowsItsInput() async {
    let kind = ElicitationFieldSchema.Kind.number(integer: false, minimum: Self.high, maximum: Self.low)
    let context = ElicitationFieldContext(
      schema: ElicitationTestFields.field(kind, name: Self.name), value: AnswerBox().binding)

    let role = await ControlProbe.read(
      ElicitationFieldView.controlIdentifier(for: Self.name),
      in: ElicitationNumberField(context: context),
      accessibilityRole(of:))

    #expect(role == NSAccessibility.Role.textArea.rawValue)
  }
}
