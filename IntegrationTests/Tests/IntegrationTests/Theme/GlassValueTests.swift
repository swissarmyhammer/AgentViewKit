import SwiftUI
import Testing

/// The facts about the `Glass` values that the AVK-8a decision uses
/// (^dbbyg9w, D110 (f)).
///
/// SwiftUI has no API for the Tinted look of the system, so a kit environment
/// value selects the look, and a test compares `Glass` values.
///
/// When a fact changes in a new SDK, a test here fails. Then do the decision
/// again.
@Suite struct GlassValueTests {
  /// The tint of the tinted glass. It is `nonisolated` because the arguments
  /// of a test use it.
  nonisolated static let tint = Color(red: 0.1, green: 0.3, blue: 0.9)

  /// A tint that differs from ``tint``. It is `nonisolated` because the
  /// arguments of a test use it.
  nonisolated static let otherTint = Color(red: 0.9, green: 0.1, blue: 0.3)

  @Test func twoGlassesWithTheSameTintAreEqual() {
    #expect(Glass.regular.tint(Self.tint) == Glass.regular.tint(Self.tint))
  }

  @Test(arguments: [Glass.regular, .regular.tint(otherTint), .clear.tint(tint)])
  func aTintedGlassIsNotEqualToADifferentGlass(_ other: Glass) {
    #expect(Glass.regular.tint(Self.tint) != other)
  }
}
