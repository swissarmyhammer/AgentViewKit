@testable import AgentViewKit
import AgentViewKitTestSupport
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

  // MARK: - Host list

  @Test func aSwitchCallsOnToggleWithTheIdAndTheNewValue() throws {
    let recorder = ReportRecorder<Call>()
    let harness = HostedViewHarness(
      ToolToggles(tools: Self.tools, style: .list) { recorder.report(Call(id: $0, isEnabled: $1)) },
      size: ConnectionsViewHostedTests.listSize)
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: ToolToggles.toggleIdentifier(for: Self.issueID))
    try harness.press(identifier: ToolToggles.toggleIdentifier(for: Self.searchID))

    #expect(
      recorder.values == [
        .init(id: Self.issueID, isEnabled: true),
        .init(id: Self.searchID, isEnabled: false),
      ])
  }

  @Test func eachSwitchHasTheToolNameAsItsLabel() {
    let harness = HostedViewHarness(
      ToolToggles(tools: Self.tools, style: .list) { _, _ in },
      size: ConnectionsViewHostedTests.listSize)
    defer { harness.close() }
    harness.render()

    let element = harness.element(identifier: ToolToggles.toggleIdentifier(for: Self.searchID))
    #expect(element?.label == "Search code")
    #expect(harness.element(identifier: ToolToggles.listIdentifier) != nil)
  }

  @Test func theListShowsOneSwitchForEachTool() {
    let harness = HostedViewHarness(
      ToolToggles(tools: Self.tools, style: .list) { _, _ in },
      size: ConnectionsViewHostedTests.listSize)
    defer { harness.close() }
    harness.render()

    let identifiers = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(ToolToggles.toggleIdentifierPrefix)
    }
    #expect(Set(identifiers) == ["tool-toggle-search", "tool-toggle-create_issue"])
  }

  @Test func anEmptyListShowsNothing() {
    let harness = HostedViewHarness(ToolToggles(tools: [], style: .list) { _, _ in })
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ToolToggles.listIdentifier) == nil)
  }

  @Test func theMenuStyleShowsAMenuButton() {
    let harness = HostedViewHarness(ToolToggles(tools: Self.tools) { _, _ in })
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ToolToggles.menuIdentifier) != nil)
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
