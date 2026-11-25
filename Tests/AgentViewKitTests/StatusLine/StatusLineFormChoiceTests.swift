import Foundation
import Testing

@testable import AgentViewKit

/// A module of the status line shows the widest of its forms that fits the
/// width that the line gives to it, and its narrowest form when no form
/// fits (^2n9ymsh).
///
/// The forms are from the widest. The tests give the measured widths of
/// three forms, so that each test needs no view.
@MainActor @Suite struct StatusLineFormChoiceTests {
  /// The measured widths of three forms, from the widest.
  static let formWidths: [CGFloat] = [300, 200, 120]

  /// A width, and the index of the form that the module shows in it.
  nonisolated struct Case: Sendable, CustomTestStringConvertible {
    /// The width that the line gives to the module, in points.
    let width: CGFloat
    /// The index of the form that the module shows.
    let shownIndex: Int

    var testDescription: String { "\(width) pt shows form \(shownIndex)" }
  }

  /// Three widths: room for the whole form, room for the second form
  /// only, and room for the third form only.
  nonisolated static let cases = [
    Case(width: 320, shownIndex: 0),
    Case(width: 250, shownIndex: 1),
    Case(width: 150, shownIndex: 2),
  ]

  /// A production change that fails this test: the module shows a form
  /// that is wider than the width, or a narrower form when a wider form
  /// fits.
  @Test(arguments: cases) func theShownFormIsTheWidestThatFits(_ testCase: Case) {
    let index = StatusLineFormLayout.indexOfWidestForm(fitting: testCase.width, in: Self.formWidths)

    #expect(index == testCase.shownIndex)
  }

  /// A production change that fails this test: with no form that fits,
  /// the module shows the whole form, and not its narrowest form.
  @Test func noFormThatFitsShowsTheNarrowestForm() {
    let narrowWidth: CGFloat = 60

    let index = StatusLineFormLayout.indexOfWidestForm(fitting: narrowWidth, in: Self.formWidths)

    #expect(index == Self.formWidths.count - 1)
  }

  /// A production change that fails this test: a proposal with no width,
  /// which asks for the ideal size, shows a narrower form.
  @Test func noWidthShowsTheWholeForm() {
    let index = StatusLineFormLayout.indexOfWidestForm(fitting: nil, in: Self.formWidths)

    #expect(index == 0)
  }
}
