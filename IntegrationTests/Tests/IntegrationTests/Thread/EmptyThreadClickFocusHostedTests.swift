import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit
@testable import EditorCommandsUI

/// A click on the empty space of a thread focuses the scope of the thread,
/// also when the thread has no transcript entry (Testudo, 2026-11-20).
///
/// The host applies EditorKit `.focusesScopeOnClick(.emptySpaceOnly,
/// segment:)` outside the agent command scope, below a window scope, as
/// TestudoApp does on its chat. The host shows the attachments in its own
/// inspector, so the thread has no inspector split view. The click is at the
/// center of the width, at 15% of the height from the top: the point that the
/// Testudo UI tests click.
///
/// Production changes that fail these tests:
/// - The content of ``ConversationEmptyState`` does not fill the visible
///   area of its scroll view. Then the click hits the AppKit scroll view, and
///   the tap gesture of the host does not fire.
/// - The read-only text of the empty state is in the scope of the thread.
///   Then the focus of the thread lands in that text, and not on the beacon of
///   the thread.
@Suite(.serialized, .hostedSerially) @MainActor struct EmptyThreadClickFocusHostedTests {
  /// The position of the click from the top, as a fraction of the height of
  /// the window.
  static let clickFractionFromTop: CGFloat = 0.15

  /// The position of the click from the leading edge, as a fraction of the
  /// width of the window.
  static let clickFractionFromLeading: CGFloat = 0.5

  /// The segment of the scope of the window, above the thread, as the
  /// window scope of TestudoApp. The click of the host appends the segment
  /// of the thread to the path of this scope.
  static let windowSegment = FocusSegment(kind: "window")

  /// The segment of the scope of the composer of the Testudo bed, as the
  /// composer scope of TestudoApp.
  static let composerSegment = FocusSegment(kind: "composer")

  /// The longest wait for the focus move of the click. The tap gesture of
  /// the host can run on a later turn of the main run loop.
  static let focusMoveBound: Duration = .seconds(10)

  /// The path of the thread scope of `model`, below the window scope.
  ///
  /// - Parameter model: The session model.
  /// - Returns: The path.
  static func threadPath(of model: SessionModel) -> FocusPath {
    FocusPath.root(windowSegment).appending(AgentCommandTarget.segment(for: model))
  }

  /// Shows the thread of `session` with the default composer in a scope of
  /// its own, as TestudoApp does, in the agent command scope, with the
  /// empty-space click of the host outside the scope.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - system: The command system of the window.
  /// - Returns: The harness.
  static func mount(session: ScriptedSession, system: CommandSystem) -> HostedViewHarness<some View>
  {
    HostedViewHarness(size: AgentCommandScopeHostedTests.windowSize) {
      AgentThreadView(session: session.model, connection: session.connection) {
        DefaultThreadComposer().commandScope(segment: composerSegment)
      }
      .agentCommandScope(session: session.model)
      .focusesScopeOnClick(.emptySpaceOnly, segment: AgentCommandTarget.segment(for: session.model))
      .agentAttachmentInspector(.host(.constant([])))
      .commandScope(segment: windowSegment)
      .environment(\.sessionModel, session.model)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
  }

  /// Clicks the empty space of the thread at the Testudo point, and waits
  /// for the focus move of the click.
  ///
  /// - Parameters:
  ///   - harness: The harness of the thread.
  ///   - system: The command system of the window.
  ///   - thread: The path of the thread scope.
  /// - Returns: The path of the last focus move, or `nil` for no move.
  /// - Throws: An issue when the beacon of the thread never goes live, or
  ///   the error of the click.
  static func clickEmptySpace(
    of harness: HostedViewHarness<some View>, system: CommandSystem, thread: FocusPath
  ) async throws -> FocusPath? {
    try #require(waitForLiveBeacons([thread], in: system))
    let size = harness.window.contentView?.bounds.size ?? AgentCommandScopeHostedTests.windowSize
    let point = NSPoint(
      x: size.width * clickFractionFromLeading, y: size.height * (1 - clickFractionFromTop))
    try await harness.sendClick(atWindowPoint: point)
    await ObservationWait.until(within: focusMoveBound) { system.geometry.lastFocusMove != nil }
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
    return system.geometry.lastFocusMove?.path
  }

  /// A click on the empty space of a thread with no transcript entry focuses
  /// the thread scope, and the beacon of the thread takes the first
  /// responder: the chat shows that it holds the focus.
  @Test func aClickOnTheEmptySpaceOfAnEmptyThreadFocusesTheThread() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    let thread = Self.threadPath(of: session.model)
    try #require(session.model.transcript.isEmpty)

    let focused = try await Self.clickEmptySpace(of: harness, system: system, thread: thread)

    #expect(focused == thread)
    #expect(
      harness.window.firstResponder is GeometryProbeView,
      "\(String(describing: harness.window.firstResponder))")
  }

  /// A click on the empty space of a thread with one message focuses the
  /// thread scope, and the beacon of the thread takes the first responder.
  @Test func aClickOnTheEmptySpaceOfAThreadWithAMessageFocusesTheThread() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    let thread = Self.threadPath(of: session.model)
    try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)

    let focused = try await Self.clickEmptySpace(of: harness, system: system, thread: thread)

    #expect(focused == thread)
    #expect(
      harness.window.firstResponder is GeometryProbeView,
      "\(String(describing: harness.window.firstResponder))")
  }
}
