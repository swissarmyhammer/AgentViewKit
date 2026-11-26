import AgentViewKitTestSupport
import AppKit
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The scroll view of each view of the kit that scrolls: EditorKit's
/// `EditorScrollView` (Docs/decisions/focus-audit.md, "Raw controls").
///
/// The `EditorScrollView` turns the system focus effect off for the scroll
/// view, and sets the focus ring type `.none` on its scrollers, so neither
/// draws the system focus ring. A SwiftUI `ScrollView` and its scrollers
/// keep the default type. A horizontal scroll view whose content fits has no
/// scroller.
///
/// Each test lays out the view in a window that is never ordered in
/// (``ControlProbe``), and reads the outermost scroll view of the view and
/// its scrollers.
@MainActor @Suite struct ScrollViewControlTests {
  /// A production change that fails this test: the view scrolls in a
  /// SwiftUI `ScrollView` in place of EditorKit's `EditorScrollView`, so the
  /// scroll view or a scroller of the view keeps the default focus ring type
  /// and can draw the system focus ring.
  @Test(arguments: ScrollingSample.allCases)
  func theScrollViewOfTheViewDrawsNoSystemFocusRing(_ sample: ScrollingSample) async throws {
    let types = try #require(await ControlProbe.outerScrollRingTypes(in: sample.view))

    #expect(types.allSatisfy { $0 == .none }, "ring types: \(types.map(\.rawValue))")
  }
}

/// A view of the kit that scrolls in a scroll view of its own, which a
/// ``ScrollViewControlTests`` test lays out.
enum ScrollingSample: CaseIterable, CustomTestStringConvertible {
  case suggestions
  case attachmentChips
  case activityTimeline
  case elicitationTabs
  case stackedAttachmentInspector
  case conversation
  case conversationEmptyState

  var testDescription: String { String(describing: self) }

  /// The view of the sample.
  @MainActor var view: AnyView {
    switch self {
    case .suggestions: Self.suggestionsView
    case .attachmentChips: AnyView(AttachmentChips(attachments: .constant(PreviewFixtures.attachments)))
    case .activityTimeline: AnyView(ActivityTimeline(session: .previewSample))
    case .elicitationTabs: Self.elicitationTabsView
    case .stackedAttachmentInspector: AnyView(AttachmentInspector(PreviewFixtures.attachments))
    case .conversation: AnyView(ConversationView(session: .previewSample))
    case .conversationEmptyState: AnyView(ConversationEmptyState(markdown: "Ask about the **code**."))
    }
  }

  /// The suggestion chips of a composer, which show only where a prompt text
  /// is in the environment.
  @MainActor private static var suggestionsView: AnyView {
    AnyView(
      SuggestionsView(suggestions: PreviewFixtures.suggestions)
        .environment(\.promptText, .constant(AttributedString())))
  }

  /// A form of each kind of field, which shows a tab for each field.
  @MainActor private static var elicitationTabsView: AnyView {
    let fields = PreviewFixtures.ElicitationFields.all.map {
      PreviewFixtures.fieldContext($0, answers: .constant([:]))
    }
    return AnyView(
      ElicitationLayout(
        context: ElicitationLayoutContext(fields: fields, tabThreshold: ElicitationLayout.defaultTabThreshold)))
  }
}
