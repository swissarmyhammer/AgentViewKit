import EditorCommands
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// The scroll view of an ``AgentRowList``: EditorKit's `EditorScrollView`
/// (Docs/decisions/focus-audit.md, "Raw controls").
///
/// Since EditorKit f9f70805 (^n8dq9z2), the scroll view turns the system
/// focus effect off for itself only. Its content reads the
/// `\.isFocusEffectEnabled` value of the host above it again, because the
/// one focus ring of EditorKit shows only while that value is `true`. Each
/// control of the kit turns off its own system focus effect.
///
/// Each test lays out the list in a window that is never ordered in
/// (``ControlProbe``), and reads an element of the list.
@MainActor @Suite struct AgentRowListScrollTests {
  /// The scope of the list of the tests.
  static let scope = AgentRowListScope(list: FocusSegment(kind: "scrollList"), rowKind: "scrollRow")

  /// A production change that fails this test: the list turns the system
  /// focus effect off for its whole content (for example with
  /// `.focusEffectDisabled()` around the stack), so a jump that lands on a
  /// control in the list shows no EditorKit focus ring.
  @Test func theFooterOfTheListReadsTheFocusEffectOfItsHost() async {
    let list = AgentRowList(["first"], id: \.self, scope: Self.scope) { id in
      Text(verbatim: id)
    } footer: {
      FocusEffectReport()
    }

    let report = await ControlProbe.read(FocusEffectReport.identifier, in: list, accessibilityValue(of:))

    #expect(report == FocusEffectReport.onText)
  }

  /// A production change that fails this test: the list keeps the system
  /// focus effect of a host that turned it off, so the list differs from
  /// the host above it.
  @Test func theFooterOfTheListReadsAHostWithNoFocusEffect() async {
    let list = AgentRowList(["first"], id: \.self, scope: Self.scope) { id in
      Text(verbatim: id)
    } footer: {
      FocusEffectReport()
    }
    .focusEffectDisabled()

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
