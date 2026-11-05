#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The labels that VoiceOver reads for a list of names or facts, as
  /// accessibility reads them in the locale of the environment: the "who
  /// asks" line of an elicitation card, the banner of a notice and a crumb of
  /// the session path.
  ///
  /// Each label puts its parts in the list format of the locale
  /// (`FormatStyle/spokenParts(locale:)`), so the tests give the English
  /// locale of the United States, whose narrow list puts a comma between two
  /// parts.
  @Suite(.serialized, .hostedSerially) @MainActor struct SpokenListLabelsHostedTests {
    /// The locale of the views.
    static let locale = Locale(identifier: "en_US")

    /// A size that shows each view of the tests.
    static let size = CGSize(width: 640, height: 480)

    /// The id of the child session of the crumb test.
    static let child = SessionId(rawValue: "reviewer")

    @Test func theWhoAsksLineReadsTheAgentPathAndTheSource() throws {
      let harness = HostedViewHarness(size: Self.size) {
        ElicitationWhoAsksLine(agentPath: ["planner", "reviewer"], source: "runCode")
          .environment(\.locale, Self.locale)
      }
      defer { harness.close() }
      harness.render()

      let line = try #require(harness.element(identifier: ElicitationView.whoAsksIdentifier))

      #expect(line.label == "Asked by root, planner, reviewer, from runCode")
    }

    @Test func theNoticeBannerReadsTheSeverityTheTitleAndTheDescription() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model
      let harness = HostedViewHarness(size: Self.size) {
        SessionNoticeBanner(session: model)
          .environment(\.locale, Self.locale)
      }
      defer { harness.close() }

      try await session.sendUpdate(CompactionAndNoticeHostedTests.notice(severity: "warning"))
      await harness.render { !model.notices.isEmpty }
      let notice = try #require(model.notices.first)

      #expect(
        harness.element(identifier: SessionNoticeBanner.identifier(for: notice.id))?.label
          == "Warning, Quota low, Half of the monthly quota is used.")
    }

    @Test func theCrumbOfAChildReadsItsTitleAndItsState() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let child = try await session.announceChild(Self.child, title: "Reviewer")
      let harness = HostedViewHarness(size: Self.size) {
        AgentInfoHeader(connection: session.connection, session: child)
          .environment(\.locale, Self.locale)
      }
      defer { harness.close() }
      harness.render()

      let crumb = try #require(harness.element(identifier: SessionBreadcrumb.crumbIdentifier(for: Self.child)))

      #expect(crumb.label == "Reviewer, In progress")
    }
  }
#endif
