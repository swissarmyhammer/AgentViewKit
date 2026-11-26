import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit
@testable import AgentViewKitStyle

/// The one focus look of the kit (Docs/decisions/focus-audit.md): no view of
/// the kit shows a system focus effect, and an item that takes the keyboard
/// focus shows the one focus background of EditorKit
/// (`EditorFocusIndicatorKind.background`), which EditorKit's
/// `.selectableItem` draws in a `SelectableSurface`.
///
/// A test of the system focus effect lays out the view in a hosting view
/// with no window. A test of the focus look puts the view in a window that is
/// never ordered in, and gives the focus with the key view loop of the window
/// or with the EditorKit focus request of a scope, so no test shows a window
/// or takes the focus of the screen.
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

  /// The positive control of ``theViewShowsNoSystemFocusEffect(_:)``: a
  /// plain focusable SwiftUI button with no `.focusEffectDisabled()` shows
  /// the system focus ring, and the census finds it. Thus an empty census of
  /// a sample proves that the sample shows no ring.
  ///
  /// A change that fails this test: ``SystemFocusEffects`` stops finding the
  /// system focus ring, for example after SwiftUI gives a new name to the
  /// class of its ring view.
  @Test func theCensusFindsTheFocusRingOfAPlainButton() {
    let hosting = StyleViewHost.host(Button("Focus") {}, size: Self.hostSize)

    #expect(!SystemFocusEffects.census(under: hosting).isEmpty)
  }

  /// A production change that fails this test: an EditorKit control that the
  /// kit uses with no `.withoutSystemFocusEffect()` of its own shows the
  /// system focus ring. The kit then needs the modifier on that control
  /// again.
  @Test(arguments: EditorKitControlSample.allCases)
  func theEditorKitControlShowsNoSystemFocusEffect(_ sample: EditorKitControlSample) {
    let hosting = StyleViewHost.host(sample.view, size: Self.hostSize)

    #expect(SystemFocusEffects.census(under: hosting).isEmpty)
  }

  /// A production change that fails this test: the permission card shows
  /// its keyboard focus with no EditorKit focus background, for example with
  /// a fill or an outline of its own.
  @Test func theFocusedPermissionCardShowsTheEditorKitFocusBackground() throws {
    let session = SessionModel.previewSample
    let request = try #require(session.pendingPermissions.first)

    let look = FocusedHost.focusIndicator(of: PermissionView(request: request, session: session))

    #expect(look == .background)
  }

  /// A production change that fails this test: the elicitation form takes
  /// the keyboard focus and shows no EditorKit focus background.
  @Test func theFocusedElicitationFormShowsTheEditorKitFocusBackground() throws {
    let session = PreviewFixtures.elicitationSession
    let request = try #require(session.pendingElicitations.first)

    let look = FocusedHost.focusIndicator(of: ElicitationView(request: request, owner: session))

    #expect(look == .background)
  }

  /// A production change that fails this test: the URL consent card takes
  /// the keyboard focus and shows no EditorKit focus background.
  @Test func theFocusedURLConsentCardShowsTheEditorKitFocusBackground() throws {
    let session = PreviewFixtures.elicitationSession
    let request = try #require(session.pendingElicitations.last)

    let look = FocusedHost.focusIndicator(of: ElicitationURLConsentView(request: request, owner: session))

    #expect(look == .background)
  }

  /// A production change that fails this test: the elicitation card of a
  /// ``RequestDeck`` takes the keyboard focus and the deck shows no EditorKit
  /// focus background at the frame of the card.
  @Test func theFocusedElicitationCardOfADeckShowsTheEditorKitFocusBackground() {
    let look = FocusedHost.focusIndicator(of: RequestDeck(session: PreviewFixtures.elicitationSession))

    #expect(look == .background)
  }

  /// A production change that fails this test: the focused row of an
  /// ``AgentRowList`` shows its focus with no EditorKit focus background.
  @Test func theFocusedRowOfARowListShowsTheEditorKitFocusBackground() {
    let list = AgentRowList(
      ["first", "second"], id: \.self,
      scope: AgentRowListScope(list: FocusSegment(kind: "focusLookList"), rowKind: "focusLookRow")
    ) { id in Text(verbatim: id) }

    let look = FocusedHost.focusIndicator(of: list)

    #expect(look == .background)
  }

  /// A production change that fails this test: an attachment chip shows the
  /// focus of its scope with no EditorKit focus background, for example with
  /// the focus ring of the scope, or with a fill of its own.
  @Test func theChipWithTheFocusOfItsScopeShowsTheEditorKitFocusBackground() throws {
    let attachment = try #require(PreviewFixtures.attachments.first)

    let look = try FocusedHost.focusIndicator(
      ofScope: AgentScopeKind.attachment(attachment.id), in: AttachmentChip(attachment))

    #expect(look == .background)
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
  case elicitationDeck
  case codeBlock
  case outputCap
  case reasoning
  case toolCall
  case configMenu
  case toolTogglesMenu

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
    case .sessionList: AnyView(SessionListView(connection: .previewSample, onOpen: { _ in }, onNewSession: {}))
    case .sessionJumpList: AnyView(SessionJumpList(agent: nil, entries: []) { _ in })
    case .diff: Self.diffView
    case .sources: AnyView(SourcesView(payload: PreviewFixtures.citations))
    case .activityTimeline: AnyView(ActivityTimeline(session: .previewSample))
    case .statusBar: Self.statusBarView
    case .elicitationDeck: AnyView(RequestDeck(session: PreviewFixtures.elicitationSession))
    case .codeBlock: AnyView(CodeBlockView(code: "let x = 1", language: "swift"))
    case .outputCap: Self.outputCapView
    case .reasoning: Self.reasoningView
    case .toolCall: Self.toolCallView
    case .configMenu: AnyView(ConfigOptionsView(session: PreviewFixtures.configuredSession, style: .menu))
    case .toolTogglesMenu: Self.toolTogglesMenuView
    }
  }

  /// A diff with the actions of a hunk and the attach action, so the view
  /// shows its buttons.
  @MainActor private static var diffView: AnyView {
    AnyView(
      DiffView(
        patch: PreviewFixtures.smallPatch, onAccept: { _, _ in }, onReject: { _, _ in }, onAttach: { _ in }))
  }

  /// The row of an output that shows its last rows, with its Show All
  /// button.
  @MainActor private static var outputCapView: AnyView {
    AnyView(
      OutputCapRow(
        rows: PreviewFixtures.cappedOutputRows, capIdentifier: CommandOutputView.capIdentifier,
        showAllIdentifier: CommandOutputView.showAllIdentifier, showAll: {}))
  }

  /// The first thought of the preview session, with its show reasoning
  /// toggle.
  @MainActor private static var reasoningView: AnyView {
    AnyView(PreviewFixtures.firstEntry(in: .previewSample, as: ThoughtEntry.self).map { ReasoningView(entry: $0) })
  }

  /// A tool call card with its row toggle.
  @MainActor private static var toolCallView: AnyView {
    let item = PreviewTranscriptItem.toolCall(title: "Read the file", kind: .read, status: .completed)
    return AnyView(PreviewFixtures.entry(item, as: ToolCallEntry.self).map { ToolCallView(entry: $0) })
  }

  /// The tools menu with one tool.
  @MainActor private static var toolTogglesMenuView: AnyView {
    AnyView(
      ToolToggles(
        tools: [ToolToggle(id: ToolToggleID("web-search"), name: "Web search", isEnabled: true)], style: .menu
      ) { _, _ in })
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

/// An EditorKit control that the kit uses with no
/// `.withoutSystemFocusEffect()` of its own, enabled, with no modifier of the
/// kit (Docs/decisions/focus-audit.md).
///
/// The command form of `EditorToolbarButton` draws through the same body and
/// look as the title form, so the title form stands for both.
enum EditorKitControlSample: CaseIterable, CustomTestStringConvertible {
  case button
  case actionButton
  case toolbarButton
  case toolbarToggle
  case menuButton

  var testDescription: String { String(describing: self) }

  /// The title of each control.
  static let title = "Focus"

  /// The symbol of each control.
  static let systemImage = "star"

  /// The view of the sample.
  @MainActor var view: AnyView {
    switch self {
    case .button: AnyView(EditorButton(Self.title, systemImage: Self.systemImage) {})
    case .actionButton: AnyView(EditorButton(Self.title, systemImage: Self.systemImage, look: .action) {})
    case .toolbarButton: AnyView(EditorToolbarButton(Self.title, systemImage: Self.systemImage) {})
    case .toolbarToggle:
      AnyView(EditorToolbarButton(Self.title, symbol: .action(.disclosure), isOn: .constant(false)))
    case .menuButton:
      AnyView(EditorMenuButton(Self.title, systemImage: Self.systemImage) { EditorMenuItem(Self.title) {} })
    }
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
/// keyboard focus to the first view of the key view loop of the window, or to
/// one command scope of the view.
@MainActor enum FocusedHost {
  /// The EditorKit focus look that `view` shows after the window gives the
  /// focus to its first focusable view.
  ///
  /// The host takes the first responder, and the window then takes the next
  /// key view, as the Tab key does: the first focusable view in the order of
  /// the view tree, which is the item, because the item stands above its
  /// controls.
  ///
  /// - Parameter view: The view to focus.
  /// - Returns: The kind of the EditorKit focus indicator that a selectable
  ///   surface in the view shows, or `nil` when no surface shows the focus.
  static func focusIndicator(of view: some View) -> EditorFocusIndicatorKind? {
    mount(view) { window, hosting in
      window.makeFirstResponder(hosting)
      window.selectNextKeyView(nil)
    }
  }

  /// The EditorKit focus look that `view` shows after the scope whose last
  /// segment is `segment` takes the focus, as a jump or a `nav.*` move gives
  /// it.
  ///
  /// The view stands in the agent command scope of the preview session, with
  /// a command system, so its item scopes are live. The focus request of
  /// EditorKit (`GeometryRegistry.requestFocus(at:)`) gives the focus to the
  /// beacon of the scope, or to the focusable view of its content.
  ///
  /// - Parameters:
  ///   - segment: The last segment of the path of the scope.
  ///   - view: The view to focus.
  /// - Returns: The kind of the EditorKit focus indicator that a selectable
  ///   surface in the view shows, or `nil` when no surface shows the focus.
  /// - Throws: An issue when no live scope has the segment, or when the scope
  ///   does not take the focus.
  static func focusIndicator(ofScope segment: FocusSegment, in view: some View) throws
    -> EditorFocusIndicatorKind?
  {
    let system = CommandSystem()
    var focusIssue: (any Error)?
    let look = mount(view.agentCommandScope(session: .previewSample).commandSystem(system)) { _, _ in
      do {
        let path = try #require(system.geometry.livePaths.first { $0.segments.last == segment })
        try #require(system.geometry.requestFocus(at: path))
      } catch {
        focusIssue = error
      }
    }
    if let focusIssue { throw focusIssue }
    return look
  }

  /// Mounts `view` in a window that is never ordered in, gives the focus with
  /// `focus`, and reads the newest ``SurfaceFocusIndicatorKey`` of the view.
  ///
  /// The host lays out the view again after the focus, and the test runs one
  /// pass of the run loop that does not wait, so SwiftUI gives the
  /// preferences of the new focus to the host.
  ///
  /// - Parameters:
  ///   - view: The view to mount.
  ///   - focus: Gives the focus, from the window and its hosting view.
  /// - Returns: The newest value of the key.
  private static func mount(
    _ view: some View, focus: (NSWindow, NSView) -> Void
  ) -> EditorFocusIndicatorKind? {
    let recorder = FocusLookRecorder()
    let hosting = NSHostingView(
      rootView: view
        .frame(width: FocusLookTests.hostSize.width, height: FocusLookTests.hostSize.height)
        .onPreferenceChange(SurfaceFocusIndicatorKey.self) { recorder.look = $0 })
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: FocusLookTests.hostSize), styleMask: [.titled],
      backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    defer { window.close() }
    StyleViewHost.layOut(hosting)
    focus(window, hosting)
    StyleViewHost.layOut(hosting)
    RunLoop.main.run(mode: .default, before: .distantPast)
    return recorder.look
  }
}

/// The newest value of ``SurfaceFocusIndicatorKey`` at a host.
@MainActor final class FocusLookRecorder {
  /// The kind of the EditorKit focus indicator that a selectable surface in
  /// the host shows, or `nil`.
  var look: EditorFocusIndicatorKind?
}
