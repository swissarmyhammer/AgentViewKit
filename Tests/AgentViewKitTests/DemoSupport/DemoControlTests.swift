import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

@testable import AgentViewKitDemoSupport

/// The controls of the views of the demo app: each one is an EditorKit
/// control (Docs/decisions/focus-audit.md, "Raw controls"). The scroll view
/// of the settings sheet is a ``ScrollingSample`` of
/// ``ScrollViewControlTests``.
///
/// Each test lays out the view in a window that is never ordered in
/// (``ControlProbe``), and reads its accessibility elements or its scroll
/// view.
@MainActor @Suite struct DemoControlTests {
  /// The number of values of a Gallery look: the theme, the appearance, the
  /// density and the text size.
  static let lookValueCount = 4

  /// The controls of the default Gallery look.
  static var lookControls: GalleryLookControls { GalleryLookControls(look: .constant(GalleryLook())) }

  /// A production change that fails this test: the start view shows a
  /// system `ProgressView` in place of the EditorKit `EditorProgressView`.
  /// A `ProgressView` with no title does not speak the starting text, and a
  /// `ProgressView` with the starting text as its title draws that title in
  /// its own element, so the element is not the square of a spinner.
  @Test func theSpinnerOfTheStartIsASquareThatSpeaksTheStartingText() async throws {
    let view = DemoStartView<Void>(phase: .starting, tab: StartingSampleTab())

    let spinner = try #require(
      await ControlProbe.read(StartingSampleTab.startingIdentifier, in: view) {
        (label: accessibilityLabel(of: $0), frame: accessibilityFrame(of: $0))
      })

    let frame = try #require(spinner.frame)
    #expect(spinner.label == StartingSampleTab().startingText && frame.width == frame.height, "spinner: \(spinner)")
  }

  /// A production change that fails this test: the controls of a Gallery
  /// look are system `Picker`s in place of EditorKit `ChoiceField`s, which
  /// name each of their options as an accessibility action.
  @Test func eachValueOfTheGalleryLookHasAChoiceField() async {
    let names = await ControlProbe.customActionNames(in: Self.lookControls)

    #expect(names.count == Self.lookValueCount)
  }

  /// A production change that fails this test: the controls of a Gallery
  /// look are in a SwiftUI `Form` in place of the EditorKit `InspectorForm`,
  /// so the scroll view of the form or one of its scrollers keeps the
  /// default focus ring type and can draw the system focus ring.
  @Test func theFormOfTheGalleryLookDrawsNoSystemFocusRing() async throws {
    let types = try #require(await ControlProbe.outerScrollRingTypes(in: Self.lookControls))

    #expect(types.allSatisfy { $0 == .none }, "ring types: \(types.map(\.rawValue))")
  }
}

/// A demo tab of the tests of ``DemoStartView``, with its own text and
/// identifiers.
private struct StartingSampleTab: DemoStartingTab {
  static let startingIdentifier = "test-start-starting"

  static let failureIdentifier = "test-start-failure"

  var startingText: String { "Starting the sample" }
}
