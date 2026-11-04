import AgentViewKitTestSupport
import EditorInspector
import EditorInspectorTestSupport
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
/// Each test finds and presses the rows with EditorKit's `InspectorDriver`,
/// by their scheme ids.
@Suite(.serialized, .hostedSerially) @MainActor struct InspectorPanelHostedTests {
  /// The width of a narrow docked panel, in points.
  static let narrowWidth: CGFloat = 240

  /// The height of the panel, in points: tall enough for each row.
  static let panelHeight: CGFloat = 900

  /// The size of a narrow docked panel.
  static let narrowPanel = CGSize(width: narrowWidth, height: panelHeight)

  /// The tools of the panel.
  static let tools = [ToolToggle(id: ToolToggleID("search"), name: "Search code", isEnabled: true)]

  /// The rows that the panel of `session` shows, one of each inspector: the
  /// web search option, the search tool and the id of the session.
  ///
  /// - Parameter session: The session of the panel.
  /// - Returns: The scheme id of each row.
  static func rows(of session: SessionModel) -> [String] {
    let sessionObject = InspectorScheme.objectID(of: [session], key: "")
    let listObject = InspectorScheme.objectID(of: [ToolToggleList(tools: [])], key: ToolToggles.listIdentifier)
    return [
      InspectorDriver.field(
        view: ConfigOptionsView.viewIdentifier, object: sessionObject,
        group: ConfigOptionsView.uncategorizedSectionID, field: "web-search"),
      InspectorDriver.field(
        view: ToolToggles.listIdentifier, object: listObject, group: ToolToggles.groupIdentifier, field: "search"),
      InspectorDriver.field(view: SessionModel.inspection.id, object: sessionObject, group: "session", field: "id"),
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
    let driver = InspectorDriver(window: harness.window, root: harness.hostingView)

    for row in Self.rows(of: session) {
      #expect(driver.elements(row).count == 1, "The panel shows no row \(row).")
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

    try InspectorDriver(window: harness.window, root: harness.hostingView).press(ToolTogglesHostedTests.row(Self.tools[0].id))
    await ObservationWait.until { !recorder.values.isEmpty }

    #expect(recorder.values == [false])
  }
}
