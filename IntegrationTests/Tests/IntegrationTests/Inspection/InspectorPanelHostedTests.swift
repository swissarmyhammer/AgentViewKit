import AgentViewKitTestSupport
import EditorInspector
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The inspectors of the kit as the content of one host panel: the panel
/// owns the one scroll view (`.inspectorScrolling(.host)`), stacks several
/// inspectors, and is as narrow as a docked panel.
///
/// Each test reads the rows by EditorKit's accessibility identifiers.
/// EditorKit's `InspectorDriver` (^eghwsfh) reads them when its final SHA
/// lands.
@Suite(.serialized, .hostedSerially) @MainActor struct InspectorPanelHostedTests {
  /// The size of a narrow docked panel, in points.
  static let narrowPanel = CGSize(width: 240, height: 900)

  /// The tools of the panel.
  static let tools = [ToolToggle(id: ToolToggleID("search"), name: "Search code", isEnabled: true)]

  /// The rows that the panel shows, one of each inspector.
  static let rows = [
    "config-options.uncategorized.web-search", "tool-toggles.tools.search", "session.session.id",
  ]

  /// A panel of three inspectors of different types.
  struct Panel: View {
    /// The session of the config options and of the session inspector.
    let session: SessionModel

    var body: some View {
      ScrollView {
        VStack(spacing: 0) {
          ConfigOptionsView(session: session, style: .form)
          ToolToggles(tools: InspectorPanelHostedTests.tools, style: .list) { _, _ in }
          InspectorView(session)
        }
      }
      .inspectorScrolling(.host)
    }
  }

  @Test func aNarrowPanelShowsARowOfEachOfItsInspectors() {
    let harness = HostedViewHarness(Panel(session: PreviewFixtures.configuredSession), size: Self.narrowPanel)
    defer { harness.close() }
    harness.render()

    let shown = Set(harness.accessibilityElements().compactMap(\.identifier))
    for row in Self.rows {
      #expect(shown.contains(row), "The panel shows no row \(row).")
    }
  }

  @Test func aToggleRowInAPanelStillCommits() async throws {
    let recorder = ReportRecorder<Bool>()
    let harness = HostedViewHarness(size: Self.narrowPanel) {
      ScrollView {
        ToolToggles(tools: Self.tools, style: .list) { _, isEnabled in recorder.report(isEnabled) }
      }
      .inspectorScrolling(.host)
    }
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: "tool-toggles.tools.search")
    await ObservationWait.until { !recorder.values.isEmpty }

    #expect(recorder.values == [false])
  }
}
