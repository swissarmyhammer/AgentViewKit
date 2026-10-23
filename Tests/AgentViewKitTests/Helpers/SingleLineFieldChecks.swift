@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI
import Testing

/// The steps that the hosted tests of a one-line EditorKit field
/// (`SingleLineField`) share: a root command scope that gives the window its
/// undo stack, the focus of the text view of one field, and the checks on
/// the identifier of that field.
///
/// The harness cannot send a ⌘Z through `NSApplication`, so the undo runs
/// `edit.undo` through the command registry of the window, the command that
/// ⌘Z resolves to (``ComposerWindowUndoHostedTests``).
@MainActor enum SingleLineFieldChecks {
  /// The segment of the root command scope that a test puts around a view
  /// with no command scope of its own.
  static let hostSegment = FocusSegment(kind: "fieldHost")

  /// The root path of the scope of ``hostSegment``.
  static let hostPath = FocusPath.root(hostSegment)

  /// Puts `content` in the root command scope ``hostSegment`` of `system`, so
  /// that EditorKit gives the window its undo stack at ``hostPath``.
  ///
  /// - Parameters:
  ///   - content: The view to scope.
  ///   - system: The command system of the window.
  /// - Returns: The scoped view.
  static func scoped(_ content: some View, in system: CommandSystem) -> some View {
    content
      .commandScope(segment: hostSegment)
      .commandSystem(system)
  }

  /// The window of `harness` with the undo stack of the root scope at
  /// `path`.
  ///
  /// - Parameters:
  ///   - harness: The harness that shows the view.
  ///   - system: The command system of the window.
  ///   - path: The root path of the window. The default is ``hostPath``.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The mounted window.
  /// - Throws: An issue when the window has no undo stack at `path`.
  static func window<Content: View>(
    of harness: HostedViewHarness<Content>, system: CommandSystem, path: FocusPath = hostPath,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> MountedThread<Content> {
    let stack = try #require(system.undo.stack(for: path), sourceLocation: sourceLocation)
    return MountedThread(harness: harness, system: system, path: path, stack: stack)
  }

  /// The text view that carries `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when no text view carries `identifier`.
  static func textView(
    identifier: String, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> NSTextView {
    let view = harness.views(withAccessibilityIdentifier: identifier).first
    return try #require(view as? NSTextView, sourceLocation: sourceLocation)
  }

  /// Makes the text view that carries `identifier` the first responder of
  /// the window, renders one pass, and types `text` into it.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when no text view carries `identifier`, or when it
  ///   cannot take the focus.
  @discardableResult
  static func type(
    _ text: String, intoFieldWith identifier: String, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> NSTextView {
    let textView = try textView(identifier: identifier, in: harness, sourceLocation: sourceLocation)
    try #require(harness.window.makeFirstResponder(textView), sourceLocation: sourceLocation)
    harness.render()
    harness.type(text)
    return textView
  }

  /// Types `text` into the field with `identifier`, and then runs
  /// `edit.undo` of the window until the stack has nothing left to undo.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - identifier: The accessibility identifier of the field.
  ///   - window: The mounted window.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when the field cannot take the focus, or when the
  ///   typing leaves nothing to undo.
  @discardableResult
  static func typeAndUndoAll(
    _ text: String, intoFieldWith identifier: String, in window: MountedThread<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws -> NSTextView {
    let textView = try type(text, intoFieldWith: identifier, in: window.harness, sourceLocation: sourceLocation)
    try #require(textView.string == text, sourceLocation: sourceLocation)
    try #require(window.stack.canUndo, sourceLocation: sourceLocation)
    try await ComposerWindowUndoHostedTests.performWhileAvailable(.undo, in: window, typed: text) {
      window.stack.canUndo
    }
    return textView
  }

  /// Expects that exactly one view and exactly one accessibility element
  /// carry `identifier`, and that the view is the editable text view of the
  /// field: the element that takes typing.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An issue when no text view carries `identifier`.
  static func expectOneTextViewCarries(
    _ identifier: String, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let textView = try textView(identifier: identifier, in: harness, sourceLocation: sourceLocation)
    let elements = harness.accessibilityElements().filter { $0.identifier == identifier }

    #expect(textView.isEditable, sourceLocation: sourceLocation)
    #expect(harness.views(withAccessibilityIdentifier: identifier) == [textView], sourceLocation: sourceLocation)
    #expect(elements.count == 1, "\(elements)", sourceLocation: sourceLocation)
  }
}
