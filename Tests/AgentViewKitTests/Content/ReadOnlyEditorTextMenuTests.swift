import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A read-only EditorKit editor of a transcript row that a test mounts.
enum ReadOnlyEditorSite: String, CaseIterable, Sendable {
  /// The Markdown of an agent answer (`RenderedMarkdownView`).
  case renderedMarkdown
  /// A block of code (`CodeBlockView`).
  case codeBlock
  /// The output of a command (`CommandOutputView`).
  case commandOutput
  /// The output of a terminal (`TerminalView`).
  case terminal

  /// The text of each editor.
  static let text = "Some words of the row."

  /// The command of the terminal.
  static let command = "ls"

  /// Makes the view that holds the editor.
  ///
  /// - Returns: The view, with no frame of its own.
  /// - Throws: An error when the preview model makes no terminal entry.
  func makeView() throws -> AnyView {
    switch self {
    case .renderedMarkdown:
      return AnyView(RenderedMarkdownView(Self.text))
    case .codeBlock:
      return AnyView(CodeBlockView(code: Self.text, language: nil))
    case .commandOutput:
      return AnyView(CommandOutputView(command: nil, output: Self.text, exitCode: nil))
    case .terminal:
      let item = PreviewTranscriptItem.terminal(
        command: Self.command, output: Self.text, exitCode: nil)
      let entry = try #require(PreviewFixtures.entry(item, as: TerminalEntry.self))
      return AnyView(TerminalView(entry: entry))
    }
  }
}

/// Tests that a right click on the text of a read-only editor of a
/// transcript row gives the menu of the row, not the text menu of AppKit
/// (D108, D193 (f)).
///
/// Each editor uses `.editorTextMenu(.ancestor)` of EditorKit. The text view
/// then gives the menu of the nearest view above it that has one. The test
/// puts the view in an `NSHostingView` with no window, under a plain view
/// that has a menu, and calls `menu(for:)` of the text view with a right
/// press that it makes and never posts. No test opens a window or takes the
/// focus.
@Suite @MainActor struct ReadOnlyEditorTextMenuTests {
  /// The width of the host, in points.
  static let width: CGFloat = 400

  /// The window number of a press with no window.
  static let noWindowNumber = 0

  /// The event number of the press.
  static let eventNumber = 0

  /// The click count of one right click.
  static let clickCount = 1

  /// The pressure of a right press.
  static let pressure: Float = 1

  /// The time stamp of the press.
  static let timestamp: TimeInterval = 0

  /// Mounts `site` in a host with no window, under a view that has `menu`.
  ///
  /// - Parameters:
  ///   - site: The editor to mount.
  ///   - menu: The menu of the view above the host.
  /// - Returns: The view that has `menu`, which holds the host, and the text
  ///   view of the editor. The caller keeps the row, so the text view keeps
  ///   its ancestors.
  /// - Throws: An error when the view tree has no text view.
  static func mount(_ site: ReadOnlyEditorSite, under menu: NSMenu) throws
    -> (row: NSView, text: NSTextView)
  {
    let hosting = NSHostingView(rootView: try site.makeView().frame(width: width))
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
    hosting.layoutSubtreeIfNeeded()
    let row = NSView(frame: hosting.frame)
    row.menu = menu
    row.addSubview(hosting)
    return (row, try #require(firstView(ofType: NSTextView.self, in: hosting)))
  }

  /// A right press at the center of `view`, which the test never posts.
  ///
  /// - Parameter view: The view under the press.
  /// - Returns: The press.
  /// - Throws: An error when AppKit makes no event.
  static func rightPress(on view: NSView) throws -> NSEvent {
    let center = view.convert(NSPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
    return try #require(
      NSEvent.mouseEvent(
        with: .rightMouseDown, location: center, modifierFlags: [], timestamp: timestamp,
        windowNumber: noWindowNumber, context: nil, eventNumber: eventNumber,
        clickCount: clickCount, pressure: pressure))
  }

  /// A production change that fails this test: an editor of a row keeps the
  /// default text menu (`.system`), so a right click on its text shows Look
  /// Up, Font and the other AppKit items in place of the menu of the row.
  @Test(arguments: ReadOnlyEditorSite.allCases)
  func aRightClickOnTheTextGivesTheMenuOfTheRow(site: ReadOnlyEditorSite) throws {
    let rowMenu = NSMenu(title: "Row")
    let (row, text) = try Self.mount(site, under: rowMenu)
    let press = try Self.rightPress(on: text)

    let shown = withExtendedLifetime(row) { text.menu(for: press) }

    #expect(shown === rowMenu)
  }
}
