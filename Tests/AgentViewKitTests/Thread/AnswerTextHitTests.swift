import AgentViewKitTestSupport
import AppKit
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A point at the center of the text of an answer reaches the text view of
/// that answer, in a thread after one layout pass.
///
/// A right click gives the menu of the view under the point, or of a view
/// above it. The text view of an answer gives the item menu of the message
/// (`.editorTextMenu(.ancestor)`). Thus a view that is not the text, such as
/// the hidden Scroll to Bottom pill that floats over the last row, must not
/// take the hit at the text. The hosted suite
/// `AnswerTextContextMenuPointerHostedTests` reads the menu in a window on
/// the screen.
///
/// SwiftUI does a hit test only for a hosting view in a window. Thus the
/// test puts the host in a borderless window, and never orders the window
/// in: no window shows, and no window takes the focus.
@MainActor @Suite struct AnswerTextHitTests {
  /// The text of the answer.
  static let answer = "The parser reads each line of the file."

  /// The size of the thread: the window size of the hosted suite.
  static let size = CGSize(width: 480, height: 600)

  /// A thread with one agent answer, laid out one time in a window that
  /// is never ordered in.
  ///
  /// - Returns: The window. Its content view is the host of the thread.
  static func mountAnswer() -> NSWindow {
    let session = SessionModel.preview(transcript: [.agent(answer)])
    let hosting = NSHostingView(
      rootView: AgentThreadView(session: session)
        .commandSystem(CommandSystem())
        .transaction { $0.disablesAnimations = true })
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()
    return window
  }

  /// A production change that fails this test: the hidden pill keeps the
  /// glass of its button in the hit test, so the pill takes the hit at the
  /// text of the last answer, and a right click on the text shows no item
  /// menu.
  @Test func theCenterOfTheAnswerTextHitsTheTextViewOfTheAnswer() throws {
    let window = Self.mountAnswer()
    let hosting = try #require(window.contentView)
    let text = try #require(views(ofType: NSTextView.self, in: hosting).first { $0.string == Self.answer })
    let center = text.convert(NSPoint(x: text.bounds.midX, y: text.bounds.midY), to: nil)

    let hit = try #require(hosting.hitTest(center))

    #expect(hit.isDescendant(of: text))
  }
}
