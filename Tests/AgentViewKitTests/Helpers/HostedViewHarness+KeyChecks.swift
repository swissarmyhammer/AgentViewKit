import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import SwiftUI
import Testing

@MainActor extension HostedViewHarness {
  /// Requires that the first responder of the window is a view of the
  /// hosting view, and that this view is not an `NSText` (a text view or a
  /// field editor) and not an `NSTextField`.
  ///
  /// - Parameter sourceLocation: The location of the caller, for the failure
  ///   report.
  /// - Throws: An issue when the first responder is not a view of the
  ///   hosting view, or when it is an `NSText` or an `NSTextField`.
  func requireKeyboardFocusOutsideText(sourceLocation: SourceLocation = #_sourceLocation) throws {
    let responder = try #require(window.firstResponder as? NSView, sourceLocation: sourceLocation)
    try #require(responder.isDescendant(of: hostingView), sourceLocation: sourceLocation)
    try #require(!(responder is NSText || responder is NSTextField), sourceLocation: sourceLocation)
  }

  /// Requires that the hosting view has an editable `NSTextView`, and that
  /// the string of the first one is `text`.
  ///
  /// - Parameters:
  ///   - text: The string that the first editable text view must have.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An issue when the hosting view has no editable `NSTextView`,
  ///   or when the string of the first one is not `text`.
  func requireTextViewShows(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) throws {
    let textView = try #require(firstEditableTextView(of: NSTextView.self), sourceLocation: sourceLocation)
    try #require(textView.string == text, sourceLocation: sourceLocation)
  }
}
