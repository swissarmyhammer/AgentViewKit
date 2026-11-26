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

  /// A production change that fails this test: the stepper range keeps the
  /// schema bounds in the order of the schema when they are not in order.
  @Test func theStepperRangeOfBoundsNotInOrderGoesFromTheLowerToTheHigher() {
    let range = ElicitationNumberField.stepperRange(minimum: Self.high, maximum: Self.low)

    #expect(range == Self.low...Self.high)
  }

  /// A production change that fails this test: the stepper range of bounds
  /// in order is not the range from the minimum to the maximum.
  @Test func theStepperRangeOfBoundsInOrderGoesFromTheMinimumToTheMaximum() {
    let range = ElicitationNumberField.stepperRange(minimum: Self.low, maximum: Self.high)

    #expect(range == Self.low...Self.high)
  }

  /// A production change that fails this test: a field with no bounds has a
  /// stepper range that does not go across all finite numbers.
  @Test func theStepperRangeOfNoBoundsGoesAcrossAllFiniteNumbers() {
    let range = ElicitationNumberField.stepperRange(minimum: nil, maximum: nil)

    #expect(range == -Double.greatestFiniteMagnitude...Double.greatestFiniteMagnitude)
  }

  /// A production change that fails this test: a bound that is not a number
  /// goes into the stepper range, which then traps.
  @Test func aBoundThatIsNotANumberLeavesThatEndOfTheStepperRangeOpen() {
    let range = ElicitationNumberField.stepperRange(minimum: .nan, maximum: Self.high)

    #expect(range == -Double.greatestFiniteMagnitude...Self.high)
  }
}

/// The range of the stepper of an integer field: whole numbers, in a range
/// whose width fits in `Int`, as EditorKit's `StepperField` needs.
@MainActor @Suite struct ElicitationIntegerStepperRangeTests {
  /// The largest whole number that a JSON number holds with no loss.
  static let limit = ElicitationNumberField.largestExactWholeNumber

  /// A lower bound that is not whole: one half.
  static let halfLower = 0.5

  /// An upper bound that is not whole: eight and one half.
  static let halfUpper = 8.5

  /// The whole numbers between ``halfLower`` and ``halfUpper``.
  static let wholeNumbersBetweenTheHalves = 1...8

  /// Two bounds with no whole number between them.
  static let boundsWithNoWholeNumber = (minimum: 0.2, maximum: 0.8)

  /// The integer range of ``boundsWithNoWholeNumber``: the whole numbers
  /// next to the bounds.
  static let wholeNumbersNextToTheBounds = 0...1

  /// A production change that fails this test: an integer field with no
  /// bounds has a stepper range wider than the exact whole numbers of a JSON
  /// number, so a step overflows `Int`.
  @Test func theIntegerRangeOfNoBoundsStaysInTheExactWholeNumbers() {
    let range = ElicitationNumberField.integerStepperRange(minimum: nil, maximum: nil)

    #expect(range == -Self.limit...Self.limit)
  }

  /// A production change that fails this test: the integer range rounds a
  /// bound that is not whole away from the range of the schema, so a step
  /// goes past a bound of the schema.
  @Test func theIntegerRangeRoundsEachBoundIntoTheRangeOfTheSchema() {
    let range = ElicitationNumberField.integerStepperRange(minimum: Self.halfLower, maximum: Self.halfUpper)

    #expect(range == Self.wholeNumbersBetweenTheHalves)
  }

  /// A production change that fails this test: the integer range of bounds
  /// with no whole number between them has its lower end above its upper
  /// end, which traps.
  @Test func theIntegerRangeOfBoundsWithNoWholeNumberBetweenThemDoesNotTrap() {
    let range = ElicitationNumberField.integerStepperRange(
      minimum: Self.boundsWithNoWholeNumber.minimum, maximum: Self.boundsWithNoWholeNumber.maximum)

    #expect(range == Self.wholeNumbersNextToTheBounds)
  }
}
