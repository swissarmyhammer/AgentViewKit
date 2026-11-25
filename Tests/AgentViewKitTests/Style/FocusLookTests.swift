import AgentViewKitTestSupport
import AppKit
import EditorCommands
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit
@testable import AgentViewKitStyle

/// The one focus look of the kit (Docs/decisions/focus-audit.md): no view of
/// the kit shows a system focus effect, and an item that takes the keyboard
/// focus shows the focus fill of its `SelectableSurface`.
///
/// A test of the system focus effect lays out the view in a hosting view
/// with no window. A test of the focus fill puts the view in a window that is
/// never ordered in, and gives the focus with the key view loop of the
/// window, so no test shows a window or takes the focus of the screen.
@MainActor @Suite struct FocusLookTests {
  /// The size of the host of each view.
  static let hostSize = CGSize(width: 640, height: 900)

  /// A production change that fails this test: a view of the kit shows a
  /// system focus ring, for example a button, a field or a focusable card
  /// with no `.focusEffectDisabled()` around it.
  @Test(arguments: FocusLookSample.allCases)
  func theViewShowsNoSystemFocusEffect(_ sample: FocusLookSample) {
    let hosting = StyleViewHost.host(sample.view, size: Self.hostSize)

    #expect(SystemFocusEffects.census(under: hosting).isEmpty)
  }

  /// A production change that fails this test: the permission card shows
  /// its keyboard focus with no focus fill of its selectable surface.
  @Test func theFocusedPermissionCardShowsTheFocusFill() throws {
    let session = SessionModel.previewSample
    let request = try #require(session.pendingPermissions.first)

    let isFilled = FocusedHost.showsFocusFill(PermissionView(request: request, session: session))

    #expect(isFilled)
  }

  /// A production change that fails this test: the elicitation form takes
  /// the keyboard focus and shows no focus fill of its selectable surface.
  @Test func theFocusedElicitationFormShowsTheFocusFill() throws {
    let session = PreviewFixtures.elicitationSession
    let request = try #require(session.pendingElicitations.first)

    let isFilled = FocusedHost.showsFocusFill(ElicitationView(request: request, owner: session))

    #expect(isFilled)
  }

  /// A production change that fails this test: the URL consent card takes
  /// the keyboard focus and shows no focus fill of its selectable surface.
  @Test func theFocusedURLConsentCardShowsTheFocusFill() throws {
    let session = PreviewFixtures.elicitationSession
    let request = try #require(session.pendingElicitations.last)

    let isFilled = FocusedHost.showsFocusFill(ElicitationURLConsentView(request: request, owner: session))

    #expect(isFilled)
  }

  /// A production change that fails this test: the elicitation card of a
  /// ``RequestDeck`` takes the keyboard focus and the deck shows no focus
  /// fill at the frame of the card.
  @Test func theFocusedElicitationCardOfADeckShowsTheFocusFill() {
    let isFilled = FocusedHost.showsFocusFill(RequestDeck(session: PreviewFixtures.elicitationSession))

    #expect(isFilled)
  }

  /// A production change that fails this test: the focused row of an
  /// ``AgentRowList`` shows its focus with no focus fill of its selectable
  /// surface.
  @Test func theFocusedRowOfARowListShowsTheFocusFill() {
    let list = AgentRowList(
      ["first", "second"], id: \.self,
      scope: AgentRowListScope(list: FocusSegment(kind: "focusLookList"), rowKind: "focusLookRow")
    ) { id in Text(verbatim: id) }

    let isFilled = FocusedHost.showsFocusFill(list)

    #expect(isFilled)
  }
}

/// A view of the kit that a ``FocusLookTests`` test lays out: each view of
/// the focus audit that takes the focus, or that holds a control that takes
/// it.
enum FocusLookSample: CaseIterable, CustomTestStringConvertible {
  case permissionCard
  case elicitationForm
  case urlConsent
  case requestDeck
  case conversation
  case thread
  case composer
  case rowList
  case sessionList
  case sessionJumpList
  case diff
  case sources
  case activityTimeline
  case statusBar

  var testDescription: String { String(describing: self) }

  /// The view of the sample.
  @MainActor var view: AnyView {
    switch self {
    case .permissionCard: Self.permissionCardView
    case .elicitationForm: Self.elicitationFormView
    case .urlConsent: Self.urlConsentView
    case .requestDeck: AnyView(RequestDeck(session: .previewSample))
    case .conversation: AnyView(ConversationView(session: .previewSample))
    case .thread: Self.threadView
    case .composer: AnyView(DefaultThreadComposer().environment(\.sessionModel, .previewSample))
    case .rowList: Self.rowListView
    case .sessionList: AnyView(SessionListView(connection: .previewSample) { _ in })
    case .sessionJumpList: AnyView(SessionJumpList(agent: nil, entries: []) { _ in })
    case .diff: AnyView(DiffView(patch: PreviewFixtures.smallPatch))
    case .sources: AnyView(SourcesView(payload: PreviewFixtures.citations))
    case .activityTimeline: AnyView(ActivityTimeline(session: .previewSample))
    case .statusBar: Self.statusBarView
    }
  }

  /// The card of the first pending permission request of the preview session.
  @MainActor private static var permissionCardView: AnyView {
    let session = SessionModel.previewSample
    return AnyView(session.pendingPermissions.first.map { PermissionView(request: $0, session: session) })
  }

  /// The form of the first pending elicitation of the preview session.
  @MainActor private static var elicitationFormView: AnyView {
    let session = PreviewFixtures.elicitationSession
    return AnyView(session.pendingElicitations.first.map { ElicitationView(request: $0, owner: session) })
  }

  /// The URL consent card of the last pending elicitation of the preview
  /// session.
  @MainActor private static var urlConsentView: AnyView {
    let session = PreviewFixtures.elicitationSession
    return AnyView(session.pendingElicitations.last.map { ElicitationURLConsentView(request: $0, owner: session) })
  }

  /// The thread of the first open session of the preview connection, with its
  /// bars and its composer.
  @MainActor private static var threadView: AnyView {
    let connection = ConnectionModel.previewSample
    return AnyView(connection.openSessions.first.map { AgentThreadView(session: $0, connection: connection) })
  }

  /// A row list with two rows.
  @MainActor private static var rowListView: AnyView {
    AnyView(
      AgentRowList(
        PreviewFixtures.suggestions, id: \.self,
        scope: AgentRowListScope(list: FocusSegment(kind: "focusLookList"), rowKind: "focusLookRow")
      ) { suggestion in Text(suggestion) })
  }

  /// A status bar with a button.
  @MainActor private static var statusBarView: AnyView {
    AnyView(
      StatusBar(
        message: StylePreviewFixtures.longExplanationStatusMessage,
        action: StylePreviewFixtures.statusAction(isEnabled: true)))
  }
}

/// The system focus effects that AppKit can show under a hosting view.
///
/// SwiftUI draws the system focus ring of each focusable SwiftUI view, such
/// as a button or a focusable card, in a subview of the host of the private
/// class `_FocusRingView`, and draws none under `.focusEffectDisabled()`. An
/// AppKit control that takes the first responder, such as the text field of
/// a SwiftUI `TextField`, draws its own ring unless its `focusRingType` is
/// `.none`, which `.focusEffectDisabled()` sets. The ring of the table of a
/// SwiftUI `List` is the ring of the scroll view around the table, so the
/// census reads the `focusRingType` of that scroll view, which
/// `.focusEffectDisabled()` sets, and not the type of the table.
@MainActor enum SystemFocusEffects {
  /// The name of the SwiftUI class of the view that draws a system focus
  /// ring.
  static let ringViewClassName = "_FocusRingView"

  /// The views under `root` that show a system focus effect.
  ///
  /// - Parameter root: The view to search, with each view under it.
  /// - Returns: A description of each view that shows a system focus effect.
  static func census(under root: NSView) -> [String] {
    let own = showsEffect(root) ? [String(describing: type(of: root))] : []
    return own + root.subviews.flatMap(census(under:))
  }

  /// Whether `view` shows a system focus effect.
  ///
  /// - Parameter view: The view.
  /// - Returns: `true` for a focus ring view of SwiftUI, for a control that
  ///   takes the first responder and draws its focus ring, and for the
  ///   scroll view of a table that draws the ring of the table.
  private static func showsEffect(_ view: NSView) -> Bool {
    if NSStringFromClass(type(of: view)).hasSuffix(ringViewClassName) { return true }
    if let scrollView = view as? NSScrollView, scrollView.documentView is NSTableView {
      return scrollView.focusRingType != .none
    }
    let drawsOwnRing = view is NSControl && !(view is NSTableView)
    return drawsOwnRing && view.acceptsFirstResponder && view.focusRingType != .none
  }
}

/// A host of one view in a window that is never ordered in, which gives the
/// keyboard focus to the first view of the key view loop of the window.
@MainActor enum FocusedHost {
  /// Whether `view` shows the focus fill of a selectable surface after the
  /// window gives the focus to its first focusable view.
  ///
  /// The host takes the first responder, and the window then takes the next
  /// key view, as the Tab key does: the first focusable view in the order of
  /// the view tree, which is the item, because the item stands above its
  /// controls. The host lays out the view again, and the test runs one pass
  /// of the run loop that does not wait, so SwiftUI gives the preferences of
  /// the new focus to the host.
  ///
  /// - Parameter view: The view to focus.
  /// - Returns: `true` when a selectable surface in the view shows the focus
  ///   fill.
  static func showsFocusFill(_ view: some View) -> Bool {
    let recorder = FocusFillRecorder()
    let hosting = NSHostingView(
      rootView: view
        .frame(width: FocusLookTests.hostSize.width, height: FocusLookTests.hostSize.height)
        .onPreferenceChange(SelectableSurfaceFocusKey.self) { recorder.isFilled = $0 })
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: FocusLookTests.hostSize), styleMask: [.titled],
      backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    defer { window.close() }
    StyleViewHost.layOut(hosting)
    window.makeFirstResponder(hosting)
    window.selectNextKeyView(nil)
    StyleViewHost.layOut(hosting)
    RunLoop.main.run(mode: .default, before: .distantPast)
    return recorder.isFilled
  }
}

/// The newest value of ``SelectableSurfaceFocusKey`` at a host.
@MainActor final class FocusFillRecorder {
  /// Whether a selectable surface in the host shows the focus fill.
  var isFilled = false
}
