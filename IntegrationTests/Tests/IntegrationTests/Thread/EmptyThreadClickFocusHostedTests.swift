import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit
@testable import EditorCommandsUI

/// The composer takes the focus in a thread with no transcript entry: when
/// the thread shows, and when a click on the empty space of the thread
/// focuses the scope of the thread (Testudo, 2026-11-20).
///
/// The host applies EditorKit `.focusesScopeOnClick(.emptySpaceOnly,
/// segment:)` outside the agent command scope, below a window scope, as
/// TestudoApp does on its chat. The composer has a scope of its own, as the
/// composer of TestudoApp. The host shows the attachments in its own
/// inspector, so the thread has no inspector split view. The click is at the
/// center of the width, at 15% of the height from the top: the point that the
/// Testudo UI tests click.
///
/// Production changes that fail these tests:
/// - The content of ``ConversationEmptyState`` does not fill the visible
///   area of its scroll view. Then the click hits the AppKit scroll view, and
///   the tap gesture of the host does not fire.
/// - The read-only text of the empty state is in the scope of the thread.
///   Then the focus of the thread lands in that text.
/// - ``EmptyThreadComposerFocus`` is not in the thread, or it does not call
///   the composer. Then the focus of the thread stays on the beacon of the
///   thread.
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

  /// The longest wait for the focus move of the click, and for a report of
  /// the composer focus. The tap gesture of the host and the task of the
  /// thread can run on a later turn of the main run loop.
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
  ///   - focuses: The recorder of the composer focus reports of the thread.
  /// - Returns: The harness.
  static func mount(
    session: ScriptedSession, system: CommandSystem, focuses: ReportRecorder<Bool>
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: AgentCommandScopeHostedTests.windowSize) {
      AgentThreadView(session: session.model, connection: session.connection) {
        DefaultThreadComposer().commandScope(segment: composerSegment)
      }
      .agentCommandScope(session: session.model)
      .focusesScopeOnClick(.emptySpaceOnly, segment: AgentCommandTarget.segment(for: session.model))
      .agentAttachmentInspector(.host(.constant([])))
      .commandScope(segment: windowSegment)
      .environment(\.sessionModel, session.model)
      .environment(\.emptyThreadFocusReport, focuses.report)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
  }

  /// Waits until the thread gave `count` composer focus reports, and renders.
  ///
  /// - Parameters:
  ///   - count: The number of reports to wait for.
  ///   - focuses: The recorder of the composer focus reports.
  ///   - harness: The harness of the thread.
  static func waitForReports(
    _ count: Int, in focuses: ReportRecorder<Bool>, rendering harness: HostedViewHarness<some View>
  ) async {
    await ObservationWait.until(within: focusMoveBound) { focuses.values.count >= count }
    harness.render()
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

  /// A thread with no transcript entry gives the first responder to the
  /// editor of the composer when it shows.
  @Test func anEmptyThreadGivesTheFocusToTheComposerWhenItShows() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let focuses = ReportRecorder<Bool>()
    let harness = Self.mount(session: session, system: system, focuses: focuses)
    defer { harness.close() }
    try #require(session.model.transcript.isEmpty)

    await Self.waitForReports(1, in: focuses, rendering: harness)

    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    #expect(focuses.values == [true])
    #expect(harness.window.firstResponder === editor)
  }

  /// A click on the empty space of a thread with no transcript entry focuses
  /// the thread scope, and the editor of the composer takes the first
  /// responder.
  @Test func aClickOnTheEmptySpaceOfAnEmptyThreadFocusesTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let focuses = ReportRecorder<Bool>()
    let harness = Self.mount(session: session, system: system, focuses: focuses)
    defer { harness.close() }
    let thread = Self.threadPath(of: session.model)
    try #require(session.model.transcript.isEmpty)
    await Self.waitForReports(1, in: focuses, rendering: harness)
    harness.window.makeFirstResponder(nil)
    harness.render()

    let focused = try await Self.clickEmptySpace(of: harness, system: system, thread: thread)
    await Self.waitForReports(2, in: focuses, rendering: harness)

    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    #expect(focused == thread)
    #expect(focuses.values.last == true)
    #expect(harness.window.firstResponder === editor)
  }

  /// A click on the empty space of a thread with one message focuses the
  /// thread scope, and the beacon of the thread keeps the first responder:
  /// the composer does not take it.
  @Test func aClickOnTheEmptySpaceOfAThreadWithAMessageFocusesTheThread() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let focuses = ReportRecorder<Bool>()
    let harness = Self.mount(session: session, system: system, focuses: focuses)
    defer { harness.close() }
    let thread = Self.threadPath(of: session.model)
    await Self.waitForReports(1, in: focuses, rendering: harness)
    try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)

    let focused = try await Self.clickEmptySpace(of: harness, system: system, thread: thread)
    await Self.waitForReports(2, in: focuses, rendering: harness)

    #expect(focused == thread)
    #expect(focuses.values.last == false)
    #expect(
      harness.window.firstResponder is GeometryProbeView,
      "\(String(describing: harness.window.firstResponder))")
  }
}
