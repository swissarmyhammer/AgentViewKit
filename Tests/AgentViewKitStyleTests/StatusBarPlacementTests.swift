import AppKit
import AgentViewKitStyle
import EditorStyle
import EditorSwiftUI
import SwiftUI
import Testing

/// Tests for the place of a ``StatusBar`` (TestudoApp D213): a bar that
/// floats over the transcript is on the floating glass of the kit, and a bar
/// in content has no glass.
///
/// Each test reads the surface that the button of the bar stands on. A bar
/// on glass gives its button the glass surface, so the button takes the
/// bordered style, and no glass stands on glass (EditorKit `style.md`,
/// rule 4). Each test lays out the bar in an `NSHostingView` with no window,
/// so no test shows a window or takes the focus.
@Suite @MainActor struct StatusBarPlacementTests {
  /// The text of the bar of the tests.
  static let message = StatusBar.Message(
    title: "The agent is ready", explanation: "Send a message to the agent.",
    symbolName: EditorSymbol.severity(.information).systemImage, identifier: "placement-test")

  /// The button of the bar of the tests.
  static let action = StatusBar.Action(
    title: "Retry", systemImage: EditorSymbol.action(.reload).systemImage, identifier: "placement-test-retry",
    isEnabled: true, perform: {})

  /// The surface that the button of a bar stands on, in the glass container
  /// of a bar of a thread, with the content surface that a banner declares
  /// around its bar.
  ///
  /// - Parameter placement: The place of the bar, or `nil` for no place.
  /// - Returns: The surface that the probe of the button read.
  static func buttonSurface(placement: StatusBarPlacement?) -> EditorStyle.ButtonSurface? {
    let record = SurfaceRecord()
    let bar = StatusBar(message: message, action: action)
      .statusBarActionStyle(SurfaceProbeStyle(record: record))
    return surface(of: bar, placement: placement, record: record)
  }

  /// The surface that a button stands on, in a card with the surface of its
  /// place (``SwiftUI/View/statusBarPlacementSurface(radius:)``), such as the
  /// sign-in card of the bottom bar of a thread.
  ///
  /// - Parameter placement: The place of the card.
  /// - Returns: The surface that the probe of the button read.
  static func cardSurface(placement: StatusBarPlacement) -> EditorStyle.ButtonSurface? {
    let record = SurfaceRecord()
    let card = SurfaceProbe(record: record)
      .statusBarPlacementSurface(radius: EditorStyle.default.radii.l)
    return surface(of: card, placement: placement, record: record)
  }

  /// Lays out `view` in the glass container of a bar of a thread, with the
  /// content surface that a banner declares around it, and returns the
  /// surface that the probe in `view` read.
  ///
  /// - Parameters:
  ///   - view: The view with a probe in it.
  ///   - placement: The place of the view, or `nil` for no place.
  ///   - record: The record of the probe in `view`.
  /// - Returns: The surface that the probe read.
  static func surface(
    of view: some View, placement: StatusBarPlacement?, record: SurfaceRecord
  ) -> EditorStyle.ButtonSurface? {
    let declared = view.editorButtonSurface(.content)
    let root = FloatingGlassContainer(spacing: EditorStyle.default.spacing.s) {
      if let placement {
        declared.statusBarPlacement(placement)
      } else {
        declared
      }
    }
    let hosting = NSHostingView(rootView: root)
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
    hosting.layoutSubtreeIfNeeded()
    return record.surface
  }

  /// A production change that fails this test: a floating bar is not on
  /// glass, so its button keeps the content surface and stands as glass on
  /// the glass of the note.
  @Test func aFloatingBarStandsItsButtonOnGlass() {
    #expect(Self.buttonSurface(placement: .floating) == .glass)
  }

  /// A production change that fails this test: a bar in content gets the
  /// glass of a floating bar.
  @Test func aBarInContentKeepsTheContentSurface() {
    #expect(Self.buttonSurface(placement: .content) == .content)
  }

  /// A production change that fails this test: a bar with no place in the
  /// environment floats, so a status text in a list or an inspector gets
  /// glass.
  @Test func aBarWithNoPlaceIsContent() {
    #expect(Self.buttonSurface(placement: nil) == .content)
  }

  /// A production change that fails this test: a card that floats, such as
  /// the sign-in card of the bottom bar of a thread, is not on glass, so its
  /// buttons keep the content surface and stand as glass on the glass of the
  /// card.
  @Test func aFloatingCardStandsItsButtonsOnGlass() {
    #expect(Self.cardSurface(placement: .floating) == .glass)
  }

  /// A production change that fails this test: a card in content, such as
  /// the sign-in card in the settings of a host, gets the glass of a
  /// floating card.
  @Test func aCardInContentKeepsTheContentSurface() {
    #expect(Self.cardSurface(placement: .content) == .content)
  }
}

/// The record of a ``SurfaceProbe``: the surface that the button read.
@MainActor final class SurfaceRecord {
  /// The surface, or `nil` before the probe shows.
  var surface: EditorStyle.ButtonSurface?
}

/// A style of the button of a bar that shows a ``SurfaceProbe`` in place of
/// the button.
struct SurfaceProbeStyle: StatusBarActionStyle {
  /// The record that gets the surface.
  let record: SurfaceRecord

  /// Shows the probe in place of the button.
  ///
  /// - Parameter configuration: The action and its button.
  /// - Returns: The probe.
  func makeBody(configuration: StatusBarActionConfiguration) -> some View {
    SurfaceProbe(record: record)
  }
}

/// A view that records the surface that a button in its place stands on.
///
/// The probe records in `onChange(of:initial:)`, not in its body, so a layout
/// pass of a host with no window records it one time.
struct SurfaceProbe: View {
  /// The record that gets the surface.
  let record: SurfaceRecord

  /// The surface that the buttons here stand on.
  @Environment(\.buttonSurface) private var surface

  var body: some View {
    Color.clear
      .onChange(of: surface, initial: true) { record.surface = surface }
  }
}
