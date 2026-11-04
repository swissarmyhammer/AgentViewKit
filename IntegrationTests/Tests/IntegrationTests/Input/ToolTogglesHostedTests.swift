@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorInspector
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

  /// The object id of the block of the list style: EditorKit names an
  /// object with no stable id by the key of its type and its position.
  static let listObject = "tooltogglelist-1"

  /// The EditorKit identifier of the block of the list style: the view and
  /// the list.
  static let block = InspectorScheme.blockIdentifier(view: ToolToggles.listIdentifier, object: listObject)

  /// The EditorKit accessibility identifier of the row of a tool in the
  /// list style: the view, the list, the group and the tool.
  ///
  /// - Parameter tool: The identifier of the tool.
  /// - Returns: The identifier, such as
  ///   `inspection:tool-toggles/object:tooltogglelist-1/field:tools.search`.
  static func row(_ tool: ToolToggleID) -> String {
    InspectorScheme.rowIdentifier(
      view: ToolToggles.listIdentifier, object: listObject, group: ToolToggles.groupIdentifier, field: tool.rawValue)
  }

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

    try harness.press(identifier: Self.row(Self.issueID))
    await ObservationWait.until { recorder.values.count == 1 }
    try harness.press(identifier: Self.row(Self.searchID))
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

    #expect(harness.element(identifier: Self.row(Self.searchID))?.value == "1")
    #expect(harness.element(identifier: Self.row(Self.issueID))?.value == "0")
  }

  @Test func theListShowsOneRowForEachTool() {
    let harness = Self.mountList()
    defer { harness.close() }

    let identifiers = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(Self.block) && $0 != InspectorScheme.identifier(of: "name", inRow: Self.block)
    }
    #expect(identifiers == [Self.row(Self.searchID), Self.row(Self.issueID)])
  }

  @Test func anEmptyListShowsNothing() {
    let harness = HostedViewHarness(ToolToggles(tools: [], style: .list) { _, _ in })
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: Self.row(Self.searchID)) == nil)
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

    try harness.press(identifier: ToolToggles.toggleIdentifier(for: Self.issueID))
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
