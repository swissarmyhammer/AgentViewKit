import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

@MainActor extension HostedViewHarness {
  /// Requires that a view of the hosting view has the keyboard focus, and
  /// that no text view, text field, or field editor has it.
  ///
  /// Esc then goes to the SwiftUI focus of the window, and not to a text
  /// field. A test calls this function before it sends Esc to a card whose
  /// Esc action answers in a task, such as a permission card. No model state
  /// changes in the same step as that Esc, so this check is the proof that
  /// the key can get to the card. When the keyboard focus is not there, the
  /// test stops here and does not wait for an answer that cannot come.
  ///
  /// - Parameter sourceLocation: The location of the caller, for the failure
  ///   report.
  /// - Throws: An issue when the first responder is not a view of the
  ///   hosting view, or when it edits text.
  func requireKeyboardFocusOutsideText(sourceLocation: SourceLocation = #_sourceLocation) throws {
    let responder = try #require(window.firstResponder as? NSView, sourceLocation: sourceLocation)
    try #require(responder.isDescendant(of: hostingView), sourceLocation: sourceLocation)
    try #require(!(responder is NSText || responder is NSTextField), sourceLocation: sourceLocation)
  }

  /// Requires that the first editable text view of the hosting view shows
  /// `text`.
  ///
  /// A typed key changes the text view in the same step as the key. The
  /// binding of a composer can take the change later, so a test waits for
  /// the binding after this check. When the key went to no text view, the
  /// test stops here and does not wait for a change that cannot come.
  ///
  /// - Parameters:
  ///   - text: The text that the text view must show.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An issue when the hosting view has no editable text view, or
  ///   when its text is not `text`.
  func requireTextViewShows(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
    let textView = try #require(firstEditableTextView(of: NSTextView.self), sourceLocation: sourceLocation)
    try #require(textView.string == text, sourceLocation: sourceLocation)
  }
}
