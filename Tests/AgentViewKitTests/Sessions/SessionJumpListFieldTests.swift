import AppKit
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The filter field of Jump to Session: a kit one-line field, which is the
/// EditorKit `SingleLineField` (Docs/decisions/focus-audit.md, "Raw
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
}
