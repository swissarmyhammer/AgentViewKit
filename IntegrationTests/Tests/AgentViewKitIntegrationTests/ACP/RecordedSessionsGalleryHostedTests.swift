import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit
@testable import DemoSupport

/// Hosted tests of the Gallery tab over the agent of the Gallery tab:
/// FoundationModelsACPAgent runs in this process over a stage of the recorded
/// sessions of the demo app, with the stub model (``RecordedSessionsScenario``).
/// No test starts a program. The agent tests are in
/// `RecordedSessionsAgentTests` of the root package.
///
/// The recorded sessions of the demo app are replaced over time, so no test
/// reads their content or counts them.
///
/// The tests run one at a time. A resume of a recorded session whose working
/// directory exists opens the code-context index in that directory, and the
/// stages of all tests hold the same recorded working directories. Two
/// resumes at the same time open the same index database, and one of them
/// fails because the database is locked.
@Suite(.serialized) struct RecordedSessionsGalleryHostedTests {
  /// The list reports the end of its first refresh, so the test waits for
  /// that report, with no clock, and then renders the list.
  @Test(.hostedSerially) func theSessionListOfTheGalleryShowsARowOfARecordedSession() async throws {
    let scenario = try await RecordedSessionsScenario.start()
    let calls = ReportRecorder<String?>()
    let harness = HostedViewHarness(
      SessionListView(connection: scenario.agent.connection, cwd: scenario.agent.workingDirectory, onOpen: { _ in })
        .environment(\.sessionListCallReport, calls.report),
      size: SessionPickerConnectionModelHostedTests.listSize)

    await harness.render { !calls.values.isEmpty }

    #expect(calls.values == [nil])
    #expect(!SessionPickerConnectionModelHostedTests.rowIdentifiers(in: harness).isEmpty)
    harness.close()
    await scenario.stop()
  }

  @Test(.hostedSerially) func theGalleryDetailShowsATranscriptRowOfEachRecordedSession() async throws {
    try await Self.hostTheGalleryWindowOfEachSession { info, harness in
      #expect(!Self.transcriptRowIdentifiers(in: harness).isEmpty, "\(info.sessionId)")
    }
  }

  @Test(.hostedSerially) func theGalleryWindowOfEachRecordedSessionGetsNarrower() async throws {
    try await Self.hostTheGalleryWindowOfEachSession { info, harness in
      harness.window.styleMask.insert(.resizable)
      harness.window.setContentSize(CGSize(width: Self.narrowWindowWidth, height: GalleryWindowReplica.windowSize.height))
      harness.render()

      #expect(harness.hostingView.frame.width == Self.narrowWindowWidth, "\(info.sessionId)")
    }
  }
}

extension RecordedSessionsGalleryHostedTests {
  /// A width of the Gallery window that is less than its first width, and
  /// more than the minimum widths of its columns, in points.
  static let narrowWindowWidth: CGFloat = 1100

  /// Resumes each listed session from the start, shows it in the window of
  /// the Gallery tab, and runs `check`.
  ///
  /// The resume returns after the replay, so the model holds the transcript
  /// of the session. The helper waits for that transcript, with no clock,
  /// and then makes one render pass before `check` reads the window.
  ///
  /// - Parameter check: The checks of one session and its window.
  /// - Throws: The error of the start or of a request.
  static func hostTheGalleryWindowOfEachSession(
    _ check: (SessionInfo, HostedViewHarness<GalleryWindowReplica>) -> Void
  ) async throws {
    let scenario = try await RecordedSessionsScenario.start()
    let connection = scenario.agent.connection
    try await RecordedSessionsScenario.resumeEachSessionFromTheStart(of: scenario.agent) { info, session in
      let harness = HostedViewHarness(
        GalleryWindowReplica(session: session, connection: connection), size: GalleryWindowReplica.windowSize)
      await harness.render { !session.transcript.isEmpty }
      check(info, harness)
      harness.close()
    }
    await scenario.stop()
  }

  /// The identifiers of the transcript rows that show.
  ///
  /// - Parameter harness: The harness that shows the transcript.
  /// - Returns: The row identifiers, in view order.
  static func transcriptRowIdentifiers(in harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements().compactMap(\.identifier).filter { $0.hasPrefix(ItemRow.identifierPrefix) }
  }
}
