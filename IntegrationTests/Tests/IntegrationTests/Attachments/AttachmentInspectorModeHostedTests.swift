import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// The attachment selection of a host inspector, as a test host keeps it.
///
/// The host gives the binding of ``selection`` to
/// ``SwiftUI/View/agentAttachmentInspector(_:)``. The test reads the value
/// that a press writes, and it changes ``shownThread`` to change the tab of
/// the host.
@MainActor @Observable final class HostAttachmentState {
  /// The attachment that the host inspector shows, or `nil`.
  var selection: AgentAttachmentSelection?

  /// The tag of the thread tab that the host shows.
  var shownThread = 0
}

extension View {
  /// Gives this view the inspector of a test host, and gives the host mode
  /// with `selection` to each thread view in this view.
  ///
  /// The inspector shows a text with the identifier
  /// ``SplitViewHostWithThreadTabs/hostInspectorIdentifier``.
  ///
  /// - Parameter selection: The attachment selection of the host.
  /// - Returns: A view with the inspector of the host.
  func testHostInspector(selection: Binding<AgentAttachmentSelection?>) -> some View {
    inspector(isPresented: .constant(true)) {
      Text("Host inspector")
        .accessibilityIdentifier(SplitViewHostWithThreadTabs.hostInspectorIdentifier)
    }
    .agentAttachmentInspector(.host(selection))
  }
}

/// A host layout of TestudoApp: a `NavigationSplitView` with its own
/// inspector, and one tab for each thread view. The host gives its own
/// selection to the thread views with
/// ``SwiftUI/View/agentAttachmentInspector(_:)``.
///
/// The composer slot of each thread view shows the tag of its thread and a
/// chip of its attachment.
struct SplitViewHostWithThreadTabs: View {
  /// The accessibility identifier of the content of the host inspector.
  static let hostInspectorIdentifier = "host-inspector"

  /// The scripted sessions of the threads, in tab order.
  let sessions: [ScriptedSession]

  /// The attachment of the chip of each thread, in tab order.
  let attachments: [AgentViewKit.Attachment]

  /// The state of the host.
  @Bindable var state: HostAttachmentState

  /// The accessibility identifier of the tag of a thread.
  ///
  /// - Parameter index: The index of the thread.
  /// - Returns: The identifier.
  static func threadIdentifier(_ index: Int) -> String {
    "host-thread-\(index)"
  }

  var body: some View {
    NavigationSplitView {
      Text("Threads")
    } detail: {
      TabView(selection: $state.shownThread) {
        ForEach(sessions.indices, id: \.self) { index in
          AgentThreadView(session: sessions[index].model, connection: sessions[index].connection) {
            Text("Thread \(index)")
              .accessibilityIdentifier(Self.threadIdentifier(index))
            AttachmentView(attachments[index])
          }
          .tabItem { Text("Thread \(index)") }
          .tag(index)
        }
      }
    }
    .testHostInspector(selection: $state.selection)
  }
}

/// The tests of the inspector mode of ``AgentThreadView``: the built-in
/// inspector, and the inspector of the host (AVK-10).
///
/// The tests make their files with ``AttachmentFixtures``, and use the helpers
/// of ``AttachmentInspectorHostedTests``: the press with no animation, and the
/// reads of the inspector items of the AppKit split view.
@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentInspectorModeHostedTests {
  /// The suite whose helpers the tests use.
  typealias Shared = AttachmentInspectorHostedTests

  /// The size of a host window with a sidebar, a thread and an inspector.
  static let splitHostSize = CGSize(width: 1_400, height: 800)

  /// The raw session id of the second scripted session.
  static let secondSessionID = "second-thread"

  // MARK: - Built-in mode

  @Test func theDefaultInspectorModeIsTheBuiltInInspector() {
    let isBuiltIn =
      switch EnvironmentValues().agentAttachmentInspector {
      case .builtIn: true
      case .host: false
      }

    #expect(isBuiltIn)
  }

  /// A thread view with no inspector mode shows the kit inspector after a
  /// press on a chip in the thread, as before AVK-10.
  ///
  /// The press makes a render pass. The fence and one more render pass then
  /// show the inspector item, as in
  /// ``AttachmentInspectorHostedTests/aPressOnAChipShowsTheInspectorItemOfTheSplitView()``.
  @Test func aThreadViewWithTheDefaultModeShowsTheKitInspectorAfterAPress() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Shared.mountThreadView(of: session) {
      AttachmentView(attachment)
    } modifier: {
      $0
    }
    defer { harness.close() }
    try #require(Shared.inspectorItem(in: harness)?.isCollapsed == true)

    try Shared.withoutAnimation {
      try harness.press(identifier: AttachmentView.identifier(for: .chip))
    }
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()

    try Shared.requireInspectorItem(in: harness, showsTheNameOf: "blob.bin")
  }

  // MARK: - Host mode

  /// A thread view in the host mode, in a host that has its own inspector,
  /// adds no inspector of the kit. A press on a chip in the thread writes the
  /// attachment and the session id of the thread to the binding of the host.
  ///
  /// The chip writes in the same step as the press, so the test reads the
  /// binding at once.
  @Test func aThreadViewInTheHostModeAddsNoInspectorAndAPressSetsTheHostSelection() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachment = try AttachmentFixtures.attachment(named: "blob.bin", in: directory)
    let state = HostAttachmentState()
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mountInHostMode(session, state: state) { AttachmentView(attachment) }
    defer { harness.close() }
    try #require(Shared.inspectorItems(in: harness).count == 1)

    try harness.press(identifier: AttachmentView.identifier(for: .chip))

    #expect(
      state.selection
        == AgentAttachmentSelection(attachment: attachment, sessionId: session.model.sessionId))
    #expect(Shared.inspectorItems(in: harness).count == 1)
    #expect(harness.element(identifier: AttachmentInspector.nameIdentifier) == nil)
    #expect(harness.element(identifier: SplitViewHostWithThreadTabs.hostInspectorIdentifier) != nil)
  }

  /// A press on an image in a thread view in the host mode writes the file of
  /// the image and the session id of the thread to the binding of the host.
  /// The window keeps only the inspector of the host.
  ///
  /// The image writes its file in a task, then writes the binding. The test
  /// waits for that write of the observable host state.
  @Test func aPressOnAnImageInTheHostModeSetsTheHostSelection() async throws {
    let state = HostAttachmentState()
    let (png, image) = try TestImage.makePNGContent(uri: WireContentBlockViewHostedTests.imageURI)
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mountInHostMode(session, state: state) { ImageView(image: image) }
    defer { harness.close() }

    try harness.press(identifier: ImageView.imageIdentifier)
    await ObservationWait.until { state.selection != nil }

    let selection = try #require(state.selection)
    #expect(selection.sessionId == session.model.sessionId)
    #expect(selection.attachment.name == WireContentBlockViewHostedTests.imageName)
    #expect(try Data(contentsOf: selection.attachment.url) == png)
    #expect(Shared.inspectorItems(in: harness).count == 1)
  }

  /// A `NavigationSplitView` with its own inspector and two thread views in
  /// the host mode, in two tabs, mounts, renders and switches between the
  /// tabs. A press in the second tab writes the attachment and the session id
  /// of the second thread to the binding of the host.
  ///
  /// What the test proves: in one off-screen window, with the host mode, the
  /// window has only the inspector of the host before and after each switch
  /// of the tab, the mount, the render passes and the switches end with no
  /// exception, and the selection holds the session id of the thread that
  /// the user pressed. TestudoApp tied the NSGenericException "more Update
  /// Constraints in Window passes than there are views in the window" to the
  /// kit inspector in a window with its own inspector. The test checks that
  /// cause: the count of inspector items.
  ///
  /// What the test does not prove: that this harness can show the
  /// exception. With the built-in mode in this host (a check on 2026-10-21),
  /// the test did not stop with the exception. It failed only on its checks:
  /// the window had more than one inspector item, and the host selection
  /// stayed `nil`. The test does not open a second window, and it does not
  /// use the tab bar of a window.
  @Test func aSplitViewHostWithItsOwnInspectorSwitchesBetweenTwoThreadTabs() async throws {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    defer { directory.remove() }
    let attachments = [
      try AttachmentFixtures.attachment(named: "first.bin", in: directory),
      try AttachmentFixtures.attachment(named: "second.bin", in: directory),
    ]
    let first = try await ScriptedSession.open()
    defer { first.close() }
    let second = try await ScriptedSession.open {
      $0.results["session/new"] = #"{"sessionId": "\#(Self.secondSessionID)"}"#
    }
    defer { second.close() }
    let state = HostAttachmentState()
    let harness = HostedViewHarness(
      SplitViewHostWithThreadTabs(
        sessions: [first, second], attachments: attachments, state: state),
      size: Self.splitHostSize)
    defer { harness.close() }
    harness.render()
    try #require(harness.element(identifier: Self.threadTag(0)) != nil)
    #expect(Shared.inspectorItems(in: harness).count == 1)

    state.shownThread = 1
    harness.render()
    try #require(harness.element(identifier: Self.threadTag(1)) != nil)
    try #require(harness.element(identifier: Self.threadTag(0)) == nil)
    try harness.press(identifier: AttachmentView.identifier(for: .chip))

    #expect(
      state.selection
        == AgentAttachmentSelection(attachment: attachments[1], sessionId: second.model.sessionId))
    #expect(Shared.inspectorItems(in: harness).count == 1)

    state.shownThread = 0
    harness.render()
    #expect(harness.element(identifier: Self.threadTag(0)) != nil)
    #expect(Shared.inspectorItems(in: harness).count == 1)
  }

  // MARK: - Helpers

  /// Mounts the thread view of a scripted session in the host mode, in a host
  /// that has its own inspector (``SwiftUI/View/testHostInspector(selection:)``),
  /// and makes one render pass.
  ///
  /// - Parameters:
  ///   - session: The scripted session that the thread view shows.
  ///   - state: The state of the host, whose selection the thread view gets.
  ///   - composer: The view in the composer slot of the thread view.
  /// - Returns: The harness of the view. The caller closes it.
  static func mountInHostMode<Composer: View>(
    _ session: ScriptedSession, state: HostAttachmentState, @ViewBuilder composer: () -> Composer
  ) -> HostedViewHarness<some View> {
    Shared.mountThreadView(of: session, composer: composer) {
      $0.testHostInspector(selection: Bindable(state).selection)
    }
  }

  /// The accessibility identifier of the tag of a thread of the split view
  /// host.
  ///
  /// - Parameter index: The index of the thread.
  /// - Returns: ``SplitViewHostWithThreadTabs/threadIdentifier(_:)``.
  static func threadTag(_ index: Int) -> String {
    SplitViewHostWithThreadTabs.threadIdentifier(index)
  }
}
