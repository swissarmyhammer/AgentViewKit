@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorInspector
import EditorInspectorTestSupport
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``ToolToggles`` with a host list, and of the default
/// composer.
@Suite(.serialized, .hostedSerially) @MainActor struct ToolTogglesHostedTests {
  /// One call of a ``ToolToggles`` host closure.
  struct Call: Equatable {
    /// The identifier of the tool.
    let id: ToolToggleID
    /// The new value.
    let isEnabled: Bool
  }

  /// The identifier of the search tool.
  static let searchID = ToolToggleID("search")

  /// The identifier of the issue tool.
  static let issueID = ToolToggleID("create_issue")

  /// The host list of the tests.
  static let tools = [
    ToolToggle(id: searchID, name: "Search code", isEnabled: true),
    ToolToggle(id: issueID, name: "Create issue", isEnabled: false),
  ]

  /// The scheme id of the row of a tool in the list style: the view and the
  /// one list object of ``ToolToggles/listIdentifier``, the group and the
  /// tool.
  ///
  /// - Parameter tool: The identifier of the tool.
  /// - Returns: The id that the row carries.
  static func row(_ tool: ToolToggleID) -> String {
    InspectorDriver.field(
      view: ToolToggles.listIdentifier, object: listObject, group: ToolToggles.groupIdentifier, field: tool.rawValue)
  }

  /// The object id of the list of a ``ToolToggles``: the list has no
  /// identity of its own, so EditorKit names it by its inspection and its
  /// position.
  static let listObject = InspectorRowID.object(ToolToggleList(tools: []), view: ToolToggles.listIdentifier)

  /// Mounts the list style of ``tools``, and makes one render pass.
  ///
  /// - Parameter onToggle: The host closure of the view.
  /// - Returns: The harness. The caller closes it.
  static func mountList(onToggle: @escaping ToolToggles.OnToggle = { _, _ in }) -> HostedViewHarness<ToolToggles> {
    let harness = HostedViewHarness(
      ToolToggles(tools: tools, style: .list, onToggle: onToggle), size: ConnectionsViewHostedTests.listSize)
    harness.render()
    return harness
  }

  // MARK: - Host list

  /// Each row commits in a task of its own, so the test waits for the call
  /// of each press before the next press.
  @Test func aToggleRowCallsOnToggleWithTheIdAndTheNewValue() async throws {
    let recorder = ReportRecorder<Call>()
    let harness = Self.mountList { recorder.report(Call(id: $0, isEnabled: $1)) }
    defer { harness.close() }

    try harness.inspectorDriver.press(Self.row(Self.issueID))
    await ObservationWait.until { recorder.values.count == 1 }
    try harness.inspectorDriver.press(Self.row(Self.searchID))
    await ObservationWait.until { recorder.values.count == 2 }

    #expect(
      recorder.values == [
        .init(id: Self.issueID, isEnabled: true),
        .init(id: Self.searchID, isEnabled: false),
      ])
  }

  @Test func eachToggleRowShowsTheStateOfItsTool() {
    let harness = Self.mountList()
    defer { harness.close() }

    #expect(harness.rowValue(Self.row(Self.searchID)) == "1")
    #expect(harness.rowValue(Self.row(Self.issueID)) == "0")
  }

  @Test func theListShowsOneRowForEachTool() {
    let harness = Self.mountList()
    defer { harness.close() }

    let identifiers = harness.inspectorDriver.fieldIDs(
      inBlock: InspectorScheme.blockIdentifier(view: ToolToggles.listIdentifier, object: Self.listObject))
    #expect(identifiers == [Self.row(Self.searchID), Self.row(Self.issueID)])
  }

  @Test func anEmptyListShowsNothing() {
    let harness = HostedViewHarness(ToolToggles(tools: [], style: .list) { _, _ in })
    defer { harness.close() }
    harness.render()

    #expect(!harness.showsRow(Self.row(Self.searchID)))
  }

  @Test func theMenuStyleShowsAMenuButton() {
    let harness = HostedViewHarness(ToolToggles(tools: Self.tools) { _, _ in })
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ToolToggles.menuIdentifier) != nil)
  }

  /// A hosted window cannot open the menu, so the test shows the toggle of
  /// one tool as the menu holds it.
  @Test func aToggleOfTheMenuCallsOnToggleWithTheIdAndTheNewValue() async throws {
    let recorder = ReportRecorder<Call>()
    let harness = HostedViewHarness(
      ToolToggleMenuItem(tool: Self.tools[1]) { recorder.report(Call(id: $0, isEnabled: $1)) })
    defer { harness.close() }
    harness.render()

    try harness.perform(.press, on: ToolToggles.toggleIdentifier(for: Self.issueID))
    await ObservationWait.until { !recorder.values.isEmpty }

    #expect(recorder.values == [.init(id: Self.issueID, isEnabled: true)])
  }

  // MARK: - Composer

  @Test func theDefaultComposerShowsNoToolMenu() {
    let harness = HostedViewHarness(size: PromptInputViewHostedTests.composerSize) {
      PromptInputHost(model: PromptInputHostedTestModel())
    }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
    #expect(harness.element(identifier: ToolToggles.menuIdentifier) == nil)
  }
}
