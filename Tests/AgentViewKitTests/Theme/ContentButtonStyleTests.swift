import EditorTestSupport
import Foundation
import Testing

/// Checks that the buttons in content use no glass button style (D110 (b),
/// (c)).
///
/// These buttons are in the rows of the thread or in the inspector. The
/// inspector is system glass, so a glass button in it is glass on glass. Only
/// a floating control and the action buttons of a request card can use glass.
///
/// The pixel tests capture a real window from the window server
/// (``GlassRenderProbeTests``), which shows Liquid Glass. These tests check the
/// rule itself: they read the source of each view for the button style that
/// it must use, so a view with no snapshot is checked too.
@Suite struct ContentButtonStyleTests {
  /// A view with buttons in content, and the button style that it must use.
  nonisolated struct ContentButtons: CustomTestStringConvertible, Sendable {
    /// The path of the source of the view, relative to the package root.
    let path: String

    /// The button style modifier that the view must use, as source text.
    let style: String

    var testDescription: String { path }
  }

  /// The views with buttons in content.
  ///
  /// - The Load Earlier row of the thread uses the bordered style.
  /// - The action row of a message uses the borderless style.
  /// - The attachment actions of an artifact and of the inspector use the
  ///   borderless style.
  ///
  /// It is `nonisolated` because the arguments of a test use it.
  nonisolated static let contentButtons = [
    ContentButtons(
      path: "Sources/AgentViewKit/Thread/ConversationView.swift", style: ".buttonStyle(.bordered)"),
    ContentButtons(
      path: "Sources/AgentViewKit/Items/MessageActions.swift", style: ".buttonStyle(.borderless)"),
    ContentButtons(
      path: "Sources/AgentViewKit/Attachments/AttachmentActions.swift",
      style: ".buttonStyle(.borderless)"),
  ]

  @Test(arguments: contentButtons)
  func theButtonsInContentUseNoGlassButtonStyle(_ view: ContentButtons) throws {
    let glass = try Regex(#"\.buttonStyle\(\s*\.glass(Prominent)?\b"#)

    let lines = try SourceLines.matching(glass, inPackageFiles: [view.path])

    #expect(lines.isEmpty, "A button in content uses a glass button style: \(lines)")
  }

  @Test(arguments: contentButtons)
  func theButtonsInContentUseTheirContentButtonStyle(_ view: ContentButtons) throws {
    let source = try String(contentsOf: PackageFiles().file(view.path), encoding: .utf8)

    #expect(source.contains(view.style), "\(view.path) does not use \(view.style)")
  }
}
