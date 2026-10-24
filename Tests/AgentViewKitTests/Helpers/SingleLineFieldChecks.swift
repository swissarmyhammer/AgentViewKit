@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import SwiftUI
import Testing

/// The steps that the hosted tests of a one-line EditorKit field
/// (`SingleLineField`) share: a root command scope that gives the window its
/// undo stack, the focus of the text view of one field, the keys that end an
/// edit of the field, and the checks on the identifier and the hint of that
/// field.
///
/// The harness cannot send a ⌘Z or a ⌃⌘Z through `NSApplication`, so the undo
/// runs `edit.undo` through the command registry of the window, the command
/// that ⌘Z resolves to (``ComposerWindowUndoHostedTests``), and Revert Field
/// presses ⌃⌘Z through the keymap of the window at the scope of the field.
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
  /// With `replacingAllText`, the text view first selects all of its text and
  /// renders one more pass, so the typing takes the place of that text, and
  /// the text view must then show exactly `text`: the way to type into a
  /// field that shows a value, such as a number field.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - replacingAllText: Whether the typing takes the place of all the text
  ///     of the field. The default is `false`: the typing goes in at the
  ///     insertion point.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when no text view carries `identifier`, when it
  ///   cannot take the focus, or, with `replacingAllText`, when the typing
  ///   does not take the place of the text.
  @discardableResult
  static func type(
    _ text: String, intoFieldWith identifier: String, in harness: HostedViewHarness<some View>,
    replacingAllText: Bool = false, sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> NSTextView {
    let textView = try textView(identifier: identifier, in: harness, sourceLocation: sourceLocation)
    try #require(harness.window.makeFirstResponder(textView), sourceLocation: sourceLocation)
    harness.render()
    if replacingAllText {
      textView.selectAll(nil)
      harness.render()
    }
    harness.type(text)
    if replacingAllText {
      try #require(textView.string == text, sourceLocation: sourceLocation)
    }
    return textView
  }

  /// Types `text` into the field with `identifier`, and then presses `key`
  /// with `modifiers`.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - replacingAllText: Whether the typing takes the place of all the text
  ///     of the field, as in ``type(_:intoFieldWith:in:replacingAllText:sourceLocation:)``.
  ///     The default is `false`.
  ///   - key: The key to press after the typing.
  ///   - modifiers: The modifier keys of the press. The default is none.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when the field cannot take the focus, when the
  ///   typing does not reach the field, or when the harness has no key code
  ///   for `key`.
  @discardableResult
  static func type(
    _ text: String, intoFieldWith identifier: String, in harness: HostedViewHarness<some View>,
    replacingAllText: Bool = false, thenPress key: KeyEquivalent, modifiers: SwiftUI.EventModifiers = [],
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> NSTextView {
    let textView = try type(
      text, intoFieldWith: identifier, in: harness, replacingAllText: replacingAllText,
      sourceLocation: sourceLocation)
    try #require(textView.string == text, sourceLocation: sourceLocation)
    try harness.sendKey(key, modifiers: modifiers)
    return textView
  }

  /// Types `text` into the field with `identifier`, and then presses Revert
  /// Field, ⌃⌘Z (`StandardChords.revertField`), the key of
  /// `editor.revertField`.
  ///
  /// The harness cannot send a ⌃⌘ chord through `NSApplication`, so the
  /// press goes through the keymap of the window at the scope of the field:
  /// the chord resolves to the command that the field registers there.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - identifier: The accessibility identifier of the field.
  ///   - window: The mounted window. It shows one field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when the field cannot take the focus, when the
  ///   typing does not reach the field, or when no command takes the chord.
  @discardableResult
  static func typeAndRevertField(
    _ text: String, intoFieldWith identifier: String, in window: MountedThread<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> NSTextView {
    let textView = try type(text, intoFieldWith: identifier, in: window.harness, sourceLocation: sourceLocation)
    try #require(textView.string == text, sourceLocation: sourceLocation)
    let field = try revertFieldScope(in: window.system, sourceLocation: sourceLocation)
    let registry = window.system.registry
    try #require(
      registry.performKey(StandardChords.revertField.asSequence, mode: .cua, at: field),
      sourceLocation: sourceLocation)
    window.harness.render()
    return textView
  }

  /// The scope of the one field of `system` that registers Revert Field
  /// (`editor.revertField`).
  ///
  /// - Parameters:
  ///   - system: The command system of the window.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The scope path of the field.
  /// - Throws: An issue when no scope, or more than one scope, registers
  ///   the command.
  static func revertFieldScope(
    in system: CommandSystem, sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> FocusPath {
    let registry = system.registry
    let scopes = registry.boundScopes.filter { scope in
      registry.definitions(at: scope).contains { $0.id == EditorRevertFieldCommand.commandID }
    }
    try #require(scopes.count == 1, "\(scopes)", sourceLocation: sourceLocation)
    return scopes[0]
  }

  /// The modifier keys of the two Return presses that submit a field:
  /// Return (`.submit`) and Command-Return (`.submitNow`). It is not
  /// isolated to the main actor, because a `@Test(arguments:)` list reads it.
  nonisolated static let submitModifiers: [SwiftUI.EventModifiers] = [[], .command]

  /// Expects that Revert Field took the typing out of the field and kept the
  /// keyboard focus in it.
  ///
  /// - Parameters:
  ///   - textView: The text view of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  static func expectRevertFieldEmptied(
    _ textView: NSTextView, harness: HostedViewHarness<some View>, sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(textView.string.isEmpty, sourceLocation: sourceLocation)
    #expect(harness.window.firstResponder === textView, sourceLocation: sourceLocation)
  }

  /// The accessibility hint of the text view that carries `identifier`: the
  /// accessibility help that VoiceOver reads after the label.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The hint, or `nil` when the text view has none.
  /// - Throws: An issue when no text view carries `identifier`.
  static func hint(
    ofFieldWith identifier: String, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> String? {
    try textView(identifier: identifier, in: harness, sourceLocation: sourceLocation).accessibilityHelp()
  }

  /// Moves the keyboard focus out of the field with `identifier` after the
  /// test typed `text` into it: the window makes no view the first
  /// responder, as a click on an empty part of the window does.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - identifier: The accessibility identifier of the field.
  ///   - harness: The harness that shows the field.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when the field cannot take or give up the focus.
  @discardableResult
  static func typeAndLeaveByFocusLoss(
    _ text: String, intoFieldWith identifier: String, in harness: HostedViewHarness<some View>,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws -> NSTextView {
    let textView = try type(text, intoFieldWith: identifier, in: harness, sourceLocation: sourceLocation)
    try #require(textView.string == text, sourceLocation: sourceLocation)
    try #require(harness.window.makeFirstResponder(nil), sourceLocation: sourceLocation)
    harness.render()
    return textView
  }

  /// Types `text` into the field with `identifier`, and then runs
  /// `edit.undo` of the window until the stack has nothing left to undo.
  ///
  /// - Parameters:
  ///   - text: The text to type.
  ///   - identifier: The accessibility identifier of the field.
  ///   - window: The mounted window.
  ///   - replacingAllText: Whether the typing takes the place of all the text
  ///     of the field, as in ``type(_:intoFieldWith:in:replacingAllText:sourceLocation:)``.
  ///     The default is `false`.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The text view.
  /// - Throws: An issue when the field cannot take the focus, or when the
  ///   typing leaves nothing to undo.
  @discardableResult
  static func typeAndUndoAll(
    _ text: String, intoFieldWith identifier: String, in window: MountedThread<some View>,
    replacingAllText: Bool = false, sourceLocation: SourceLocation = #_sourceLocation
  ) async throws -> NSTextView {
    let textView = try type(
      text, intoFieldWith: identifier, in: window.harness, replacingAllText: replacingAllText,
      sourceLocation: sourceLocation)
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
