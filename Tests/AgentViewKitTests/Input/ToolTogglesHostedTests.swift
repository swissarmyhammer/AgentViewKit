import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// The calls of a ``ToolToggles`` host closure.
@Observable final class ToolToggleRecorder {
  /// One call of the host closure.
  struct Call: Equatable {
    /// The identifier of the tool.
    let id: ToolToggleID
    /// The new value.
    let isEnabled: Bool
  }

  /// Each call, in call order.
  private(set) var calls: [Call] = []

  /// Records one call.
  ///
  /// - Parameters:
  ///   - id: The identifier of the tool.
  ///   - isEnabled: The new value.
  func record(_ id: ToolToggleID, _ isEnabled: Bool) {
    calls.append(Call(id: id, isEnabled: isEnabled))
  }
}

/// Hosted tests of ``ToolToggles`` with a host list, with a
/// ``ConnectionStore``, and in the default composer.
@Suite(.serialized, .hostedSerially) @MainActor struct ToolTogglesHostedTests {
  /// The host list of the tests.
  static let tools = [
    ToolToggle(id: ConnectionsViewHostedTests.searchID, name: "Search code", isEnabled: true),
    ToolToggle(id: ConnectionsViewHostedTests.issueID, name: "Create issue", isEnabled: false),
  ]

  // MARK: - Host list

  @Test func aSwitchCallsOnToggleWithTheIdAndTheNewValue() throws {
    let recorder = ToolToggleRecorder()
    let harness = HostedViewHarness(
      ToolToggles(tools: Self.tools, style: .list, onToggle: recorder.record),
      size: ConnectionsViewHostedTests.listSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(
      identifier: ToolToggles.toggleIdentifier(for: ConnectionsViewHostedTests.issueID))
    try harness.press(
      identifier: ToolToggles.toggleIdentifier(for: ConnectionsViewHostedTests.searchID))

    #expect(
      recorder.calls == [
        .init(id: ConnectionsViewHostedTests.issueID, isEnabled: true),
        .init(id: ConnectionsViewHostedTests.searchID, isEnabled: false),
      ])
  }

  @Test func eachSwitchHasTheToolNameAsItsLabel() {
    let harness = HostedViewHarness(
      ToolToggles(tools: Self.tools, style: .list) { _, _ in },
      size: ConnectionsViewHostedTests.listSize)
    defer { harness.close() }
    harness.pump()

    let element = harness.element(
      identifier: ToolToggles.toggleIdentifier(for: ConnectionsViewHostedTests.searchID))
    #expect(element?.label == "Search code")
    #expect(harness.element(identifier: ToolToggles.listIdentifier) != nil)
  }

  @Test func anEmptyListShowsNothing() {
    let harness = HostedViewHarness(ToolToggles(tools: [], style: .list) { _, _ in })
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ToolToggles.listIdentifier) == nil)
  }

  @Test func theMenuStyleShowsAMenuButton() {
    let harness = HostedViewHarness(ToolToggles(tools: Self.tools) { _, _ in })
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ToolToggles.menuIdentifier) != nil)
  }

  // MARK: - Store

  @Test func aStoreSwitchSetsTheToolOfItsConnectionAndCallsOnToggle() throws {
    let store = ConnectionsViewHostedTests.twoConnections()
    let recorder = ToolToggleRecorder()
    let harness = HostedViewHarness(
      ToolToggles(style: .list, onToggle: recorder.record).connectionStore(store),
      size: ConnectionsViewHostedTests.listSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(
      identifier: ToolToggles.toggleIdentifier(
        for: ConnectionsViewHostedTests.searchID, in: ConnectionsViewHostedTests.linearID))

    #expect(
      store.connection(ConnectionsViewHostedTests.linearID)?.tools.map(\.isEnabled) == [false])
    #expect(
      store.connection(ConnectionsViewHostedTests.githubID)?.tools.map(\.isEnabled)
        == [true, false])
    #expect(recorder.calls == [.init(id: ConnectionsViewHostedTests.searchID, isEnabled: false)])
  }

  @Test func theStoreShowsOneSwitchForEachToolOfEachConnection() {
    let store = ConnectionsViewHostedTests.twoConnections()
    let harness = HostedViewHarness(
      ToolToggles(style: .list).connectionStore(store),
      size: ConnectionsViewHostedTests.listSize)
    defer { harness.close() }
    harness.pump()

    let identifiers = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(ToolToggles.toggleIdentifierPrefix)
    }
    #expect(
      Set(identifiers) == [
        "tool-toggle-github-search", "tool-toggle-github-create_issue",
        "tool-toggle-linear-search",
      ])
  }

  @Test func aViewWithNoStoreShowsNothing() {
    let harness = HostedViewHarness(ToolToggles(style: .list))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ToolToggles.listIdentifier) == nil)
  }

  // MARK: - Composer

  @Test func theComposerShowsTheToolMenuOnlyWhenTheStoreHasATool() {
    let withTools = threadViewHarness(
      size: PromptInputViewHostedTests.composerSize, actions: NoopThreadActions()
    ) {
      PromptInputHost(model: PromptInputHostedTestModel())
        .connectionStore(ConnectionsViewHostedTests.twoConnections())
    }
    withTools.pump()
    let hasMenu = withTools.element(identifier: ToolToggles.menuIdentifier) != nil
    withTools.close()

    let withoutTools = threadViewHarness(
      size: PromptInputViewHostedTests.composerSize, actions: NoopThreadActions()
    ) {
      PromptInputHost(model: PromptInputHostedTestModel())
        .connectionStore(ConnectionStore())
    }
    withoutTools.pump()
    let hasNoMenu = withoutTools.element(identifier: ToolToggles.menuIdentifier) == nil
    withoutTools.close()

    #expect(hasMenu)
    #expect(hasNoMenu)
  }
}
