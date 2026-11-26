import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The controls of Jump to Session: the filter field is a kit one-line
/// field, which is the EditorKit `SingleLineField`, and each row is an
/// EditorKit `EditorPlainButton` (Docs/decisions/focus-audit.md, "Raw
/// controls").
///
/// Each test lays out the list in a window that is never ordered in
/// (``ControlProbe``), and reads the accessibility element of the field.
@MainActor @Suite struct SessionJumpListFieldTests {
  /// A jump list with no entries.
  static var list: SessionJumpList { SessionJumpList(agent: nil, entries: []) { _ in } }

  /// A production change that fails this test: the filter field is a
  /// system `TextField`, whose element is a text field, in place of the
  /// text view of an EditorKit field, whose element is a text area.
  @Test func theFilterFieldIsTheTextViewOfAnEditorKitField() async {
    let role = await ControlProbe.read(SessionJumpList.fieldIdentifier, in: Self.list, accessibilityRole(of:))

    #expect(role == NSAccessibility.Role.textArea.rawValue)
  }

  /// A production change that fails this test: the filter field draws its
  /// text in a font that is not the `display` face of the theme, the face of
  /// the text that a person writes.
  @Test func theFilterFieldTakesTheDisplayFaceOfTheTheme() async throws {
    let frames = try #require(
      await ControlProbe.frames(of: SessionJumpList.fieldIdentifier, in: Self.list, enlarging: .display))

    #expect(frames.themed.height > frames.plain.height)
  }

  /// The id of the child session of the row test.
  static let child = SessionId(rawValue: "child")

  /// The title of the child session of the row test.
  static let childTitle = "Child"

  /// A production change that fails this test: a row of the list is a plain
  /// system `Button` in place of the EditorKit `EditorPlainButton`, so the
  /// path of the row does not take the caption style of the button tokens
  /// of the theme.
  @Test func aRowTakesTheCaptionStyleOfTheButtonTokens() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.announceChild(Self.child, title: Self.childTitle)
    let entry = try #require(session.model.jumpEntries.first)
    let row = SessionJumpRow(entry: entry, agent: nil) { _ in }

    let frames = try #require(
      await ControlProbe.framesWithLargeButtonCaptions(
        of: SessionJumpList.rowIdentifier(for: entry.sessionId), in: row))

    #expect(frames.themed.height > frames.plain.height)
  }
}
