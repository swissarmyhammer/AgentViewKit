@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the first responder of an item of a thread that a `nav.*` move
/// or a jump focuses (AVK-7d).
///
/// The item has no focusable view of its own, so EditorKit gives the focus
/// to the beacon of the item scope.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentItemFocusHostedTests {
  /// The kind of an item of a thread.
  enum ItemKind: CaseIterable, Sendable {
    /// A message row.
    case message
    /// A tool call card.
    case toolCall
    /// A permission request card of the deck.
    case request
  }

  /// The way the focus lands on an item.
  enum FocusLanding: CaseIterable, Sendable {
    /// A `nav.*` move, which EditorKit lands with `requestFocus(at:)`.
    case nav
    /// A jump, which commits the jump label of the item.
    case jump
  }

  /// The JSON-RPC id of the permission request of the request card.
  static let requestID = 100

  /// The first responder of a window, with the area of the focused scope.
  struct FocusedItem {
    /// The first responder of the window.
    let responder: NSView

    /// The rect of the scope, in the window space of EditorKit.
    let itemRect: CGRect
  }

  /// Waits for the beacon of `scope`, lands the focus with `land`, and reads
  /// the first responder of the window of `harness` and the area of `scope`.
  ///
  /// - Parameters:
  ///   - scope: The path of the scope that the focus lands on.
  ///   - system: The command system of the window.
  ///   - harness: The harness that shows the scope.
  ///   - land: Lands the focus on the scope.
  /// - Returns: The first responder, with the area of the scope.
  /// - Throws: An issue when the beacon never goes live or the focus does
  ///   not land.
  static func focusedItem(
    at scope: FocusPath, in system: CommandSystem, harness: HostedViewHarness<some View>,
    by land: () throws -> Void
  ) async throws -> FocusedItem {
    try #require(waitForLiveBeacons([scope], in: system))
    try land()
    await RunLoopBlockFence.afterPendingBlocks()
    harness.render()
    let responder = try #require(harness.window.firstResponder as? NSView)
    let itemRect = try #require(system.geometry.rect(of: scope))
    return FocusedItem(responder: responder, itemRect: itemRect)
  }

  /// Shows one item of `kind`, lands the focus on it by `landing`, and gives
  /// the focused item to `inspect`.
  ///
  /// - Parameters:
  ///   - kind: The kind of the item.
  ///   - landing: The way the focus lands on the item.
  ///   - isFocusEffectEnabled: `false` to apply `.focusEffectDisabled()`
  ///     above the thread.
  ///   - inspect: The checks on the focused item.
  /// - Throws: The error of the transport, or an issue when the focus does
  ///   not land.
  static func inspectFocusedItem(
    _ kind: ItemKind, landedBy landing: FocusLanding, isFocusEffectEnabled: Bool = true,
    _ inspect: (FocusedItem) throws -> Void
  ) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(
      session: session, system: system, outerScope: true, isFocusEffectEnabled: isFocusEffectEnabled)
    defer { harness.close() }
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    let item = thread.appending(try await sendItem(kind, to: session, rendering: harness))

    try inspect(
      try await focusedItem(at: item, in: system, harness: harness) {
        try land(on: item, in: thread, system: system, by: landing)
      })
  }

  /// Sends one item of `kind` from the agent, and renders `mount` after the
  /// session model holds it.
  ///
  /// - Parameters:
  ///   - kind: The kind of the item.
  ///   - session: The scripted session.
  ///   - mount: The mount that renders the view.
  /// - Returns: The segment of the item scope.
  /// - Throws: The error of the transport.
  static func sendItem(
    _ kind: ItemKind, to session: ScriptedSession, rendering mount: some RenderedMount
  ) async throws -> FocusSegment {
    switch kind {
    case .message:
      try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: mount)
      return AgentScopeKind.message(rowKey: try #require(session.model.transcript.first).rowKey)
    case .toolCall:
      let toolCall = try await AgentScopeSubjectHostedTests.sendScopeToolCall(to: session, rendering: mount)
      return AgentScopeKind.toolCall(toolCall.toolCallId.rawValue)
    case .request:
      return AgentScopeKind.request(try await session.sendPermissionRequest(id: requestID, rendering: mount))
    }
  }

  /// Lands the focus on `item` by `landing`.
  ///
  /// - Parameters:
  ///   - item: The path of the item scope.
  ///   - thread: The path of the thread scope, the layer of the jump.
  ///   - system: The command system of the window.
  ///   - landing: The way the focus lands.
  /// - Throws: An issue when EditorKit does not land the focus.
  static func land(on item: FocusPath, in thread: FocusPath, system: CommandSystem, by landing: FocusLanding) throws {
    switch landing {
    case .nav:
      try #require(system.geometry.requestFocus(at: item))
    case .jump:
      let jump = JumpModeController(system: system)
      try #require(jump.activate(layer: thread))
      try #require(jump.commit(item))
    }
  }

  /// The first responder covers the focused item, by each way the focus lands.
  @Test(arguments: ItemKind.allCases, FocusLanding.allCases)
  func theFirstResponderCoversAFocusedItem(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
    }
  }

  /// The beacon of a message or a tool call holds the focus: neither has a
  /// focusable view of its own.
  @Test(arguments: [ItemKind.message, .toolCall], FocusLanding.allCases)
  func theBeaconOfAnItemWithNoFocusableViewHoldsTheFocus(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      #expect(focused.responder is GeometryProbeView)
    }
  }

  /// `.focusEffectDisabled()` above the thread leaves the focus on the item.
  @Test(arguments: ItemKind.allCases)
  func theFocusLandsOnAnItemUnderFocusEffectDisabled(kind: ItemKind) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: .nav, isFocusEffectEnabled: false) { focused in
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
    }
  }
}
