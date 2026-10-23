@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import SwiftUI
import Testing

/// A view of the kit with a one-line EditorKit field, hosted under the root
/// command scope of a window, with the command system and the undo stack of
/// that window.
struct MountedOneLineField<Content: View> {
  /// The harness that shows the view.
  let harness: HostedViewHarness<Content>

  /// The command system of the window.
  let system: CommandSystem

  /// The undo stack of the window.
  let stack: WindowUndoStack
}

/// The setup and the checks that the hosted tests of a one-line field of the
/// kit share: a `SingleLineField` of EditorKit (plan.md §15.1 of EditorKit).
///
/// The field has its own `editor:` command scope under the scope that holds
/// it. Return commits the edit, Esc commits the edit and drills out, and
/// Revert Field (Control-Command-Z) puts back the value that the edit started
/// from. Each edit is an entry on the undo stack of the window.
///
/// The harness cannot send a Command chord through `NSApplication`, so the
/// tests run Revert Field and `edit.undo` through the command registry of the
/// window, by their keys and their ids.
@MainActor enum OneLineFieldHarness {
  /// The segment of the root command scope of the window.
  static let rootSegment = FocusSegment(kind: "window")

  /// The path of the root command scope of the window.
  static var rootPath: FocusPath { FocusPath.root(rootSegment) }

  /// The path of the own command scope of the field with `id` in the root
  /// scope of the window.
  ///
  /// - Parameter id: The id of the field: the `id` of its `SingleLineField`.
  /// - Returns: The path.
  static func fieldPath(id: String) -> FocusPath {
    rootPath.appending(.editor(id: id))
  }

  /// Shows `content` under the root command scope of a new command system,
  /// with no animations, and renders it.
  ///
  /// - Parameters:
  ///   - size: The size of the window.
  ///   - sourceLocation: The location of the caller, for the failure report.
  ///   - content: The builder of the view to host.
  /// - Returns: The mounted view.
  /// - Throws: An error when the window has no undo stack.
  static func mount(
    size: CGSize, sourceLocation: SourceLocation = #_sourceLocation, @ViewBuilder _ content: () -> some View
  ) throws -> MountedOneLineField<some View> {
    let system = CommandSystem()
    let view = content()
    let harness = HostedViewHarness(size: size) {
      view
        .commandScope(segment: rootSegment)
        .commandSystem(system)
        .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    let stack = try #require(system.undo.stack(for: rootPath), sourceLocation: sourceLocation)
    return MountedOneLineField(harness: harness, system: system, stack: stack)
  }

  /// The text view of the field with the accessibility identifier
  /// `identifier`: the one view that carries it.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An error when no view or more than one view carries
  ///   `identifier`, or when the view is not an `NSTextView`.
  static func textView(
    identifier: String, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> NSTextView {
    let views = harness.views(withAccessibilityIdentifier: identifier)
    try #require(views.count == 1, "\(views)", sourceLocation: sourceLocation)
    return try #require(views.first as? NSTextView, sourceLocation: sourceLocation)
  }

  /// Gives the keyboard focus to `textView` and types `text` into it.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - textView: The text view of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An error when the text view cannot get the focus or does not
  ///   show `text`.
  static func type(
    _ text: String, into textView: NSTextView, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    try #require(harness.window.makeFirstResponder(textView), sourceLocation: sourceLocation)
    harness.type(text)
    try #require(textView.string == text, sourceLocation: sourceLocation)
  }

  /// Runs Revert Field of the field at `path` by its key,
  /// `StandardChords.revertField`.
  ///
  /// - Parameters:
  ///   - path: The path of the own scope of the field.
  ///   - field: The mounted view.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An error when no command handles the key.
  static func revertField(
    at path: FocusPath, in field: MountedOneLineField<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let handled = field.system.registry.performKey(
      KeySequence(StandardChords.revertField), mode: .cua, at: path)
    try #require(handled, sourceLocation: sourceLocation)
    field.harness.render()
  }

  /// Runs `edit.undo` of the window while its stack holds an entry, one time
  /// for each character of `typed` at most.
  ///
  /// - Parameters:
  ///   - typed: The text that the test typed.
  ///   - field: The mounted view.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An error when the stack has nothing to undo at the start, or
  ///   when `edit.undo` is not available.
  static func undoAll(
    _ typed: String, in field: MountedOneLineField<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws {
    try #require(field.stack.canUndo, sourceLocation: sourceLocation)
    for _ in typed where field.stack.canUndo {
      try #require(field.system.registry.perform(.undo, at: rootPath), sourceLocation: sourceLocation)
      await field.stack.waitUntilIdle()
      field.harness.render()
    }
  }
}
