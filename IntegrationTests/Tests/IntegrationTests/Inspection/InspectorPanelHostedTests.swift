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
/// Each test reads the rows by EditorKit's accessibility identifiers: the
/// view, the object, the group and the field.
@Suite(.serialized, .hostedSerially) @MainActor struct InspectorPanelHostedTests {
  /// The width of a narrow docked panel, in points.
  static let narrowWidth: CGFloat = 240

  /// The height of the panel, in points: tall enough for each row.
  static let panelHeight: CGFloat = 900

  /// The size of a narrow docked panel.
  static let narrowPanel = CGSize(width: narrowWidth, height: panelHeight)

  /// The tools of the panel.
  static let tools = [ToolToggle(id: ToolToggleID("search"), name: "Search code", isEnabled: true)]

  /// The rows that the panel shows, one of each inspector.
  ///
  /// - Parameter session: The session of the panel.
  /// - Returns: The web search row of the config options, the search row of
  ///   the tools, and the id row of the session.
  static func rows(of session: SessionModel) -> [String] {
    let configOptions = ConfigOptionsView.viewIdentifier
    return [
      InspectorScheme.rowIdentifier(
        view: configOptions, object: InspectorScheme.objectID(of: [session], key: configOptions),
        group: ConfigOptionsView.uncategorizedSectionID, field: "web-search"),
      ToolTogglesHostedTests.row(ToolToggleID("search")),
      ClientModelInspectionHostedTests.row("session", "id", of: session),
    ]
  }

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
    let session = PreviewFixtures.configuredSession
    let harness = HostedViewHarness(Panel(session: session), size: Self.narrowPanel)
    defer { harness.close() }
    harness.render()

    let shown = Set(harness.accessibilityElements().compactMap(\.identifier))
    for row in Self.rows(of: session) {
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

    try harness.press(identifier: ToolTogglesHostedTests.row(ToolToggleID("search")))
    await ObservationWait.until { !recorder.values.isEmpty }

    #expect(recorder.values == [false])
  }
}
