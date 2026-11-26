import EditorCommands
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The scroll view of an ``AgentRowList``: EditorKit's `EditorScrollView`,
/// which turns the system focus effect off for itself and for each view in
/// it (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Each test lays out the list in a window that is never ordered in
/// (``ControlProbe``), and reads an element of the list.
@MainActor @Suite struct AgentRowListScrollTests {
  /// The scope of the list of the tests.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "scrollList"), rowKind: "scrollRow")

  /// A production change that fails this test: the list scrolls in a system
  /// `ScrollView` in place of the EditorKit `EditorScrollView`, so a view in
  /// the list that does not turn the system focus effect off itself, such
  /// as the footer, can show the system focus ring.
  @Test func theFooterOfTheListHasNoSystemFocusEffect() async {
    let list = AgentRowList(["first"], id: \.self, scope: Self.scope) { id in
      Text(verbatim: id)
    } footer: {
      FocusEffectReport()
    }

    let report = await ControlProbe.read(FocusEffectReport.identifier, in: list, accessibilityValue(of:))

    #expect(report == FocusEffectReport.offText)
  }
}

/// A text that tells whether the system focus effect is on where it stands
/// (`\.isFocusEffectEnabled`).
private struct FocusEffectReport: View {
  /// The accessibility identifier of the text.
  static let identifier = "focus-effect-report"

  /// The text while the system focus effect is on.
  static let onText = "focus effect on"

  /// The text while the system focus effect is off.
  static let offText = "focus effect off"

  @Environment(\.isFocusEffectEnabled) private var isFocusEffectEnabled

  var body: some View {
    Text(verbatim: isFocusEffectEnabled ? Self.onText : Self.offText)
      .accessibilityIdentifier(Self.identifier)
  }
}
