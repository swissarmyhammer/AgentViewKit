@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import struct EditorTestSupport.FocusRing
import class EditorTestSupport.FocusRingBed
import enum EditorTestSupport.RunLoopBlockFence
import func EditorTestSupport.waitForLiveBeacons
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the focus ring of an item of a thread that a `nav.*` move or a
/// jump focuses (AVK-7d).
///
/// The item has no focusable view of its own, so EditorKit gives the focus
/// to the beacon of the item scope, and the scope draws its focus ring
/// around the item in the theme accent, never in the `.tint` of the host
/// (EditorKit ^d5f8cwa). The ring has the corners of a card of the kit.
///
/// Each test shows one item of a session (``mountItems(of:isFocusEffectEnabled:)``)
/// in a `FocusRingBed` of EditorKit: a real key window on the screen, under
/// the red tint of a host and the shared `AccentTheme` of EditorKit with the
/// blue accent of the bed. It captures the window from the window server
/// before the focus lands, and reads the ring against that capture down the
/// pixel column just outside the left edge of the item.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentItemFocusRingHostedTests {
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

  /// The first responder of the window of a bed, with the area of the
  /// focused scope and the ring it draws.
  struct FocusedItem {
    /// The first responder of the window.
    let responder: NSView

    /// The rect of the scope, in the window space of EditorKit.
    let itemRect: CGRect

    /// The ring of the scope, against a capture before the focus landed. A
    /// test checks its corners with EditorKit's
    /// `FocusRingBed.expectRingCorners(of:size:cornerRadius:)`.
    let ring: FocusRing
  }

  /// Captures the window of `bed`, waits for the beacon of `scope`, lands
  /// the focus with `land`, and reads the first responder and the ring of
  /// `scope`.
  ///
  /// - Parameters:
  ///   - scope: The path of the scope that the focus lands on.
  ///   - bed: The bed that shows the scope.
  ///   - land: Lands the focus on the scope.
  /// - Returns: The first responder, with the area of the scope and its
  ///   ring.
  /// - Throws: An issue when the beacon never goes live or the focus does
  ///   not land, or an error when a capture fails.
  static func focusedItem(
    at scope: FocusPath, in bed: FocusRingBed, by land: () throws -> Void
  ) async throws -> FocusedItem {
    let baseline = try await bed.capture()
    try #require(waitForLiveBeacons([scope], in: bed.system))
    try land()
    await RunLoopBlockFence.afterPendingBlocks()

    let responder = try #require(bed.window.firstResponder as? NSView)
    let itemRect = try #require(bed.system.geometry.rect(of: scope))
    return FocusedItem(responder: responder, itemRect: itemRect, ring: try await bed.ring(of: scope, against: baseline))
  }

  /// Shows the items of `model`, the rows of its conversation and the cards
  /// of its deck, in the agent command scope of the session, in a
  /// `FocusRingBed`.
  ///
  /// The bed shows the conversation without the bars of ``AgentThreadView``,
  /// so that the Liquid Glass of a bar does not cover a row and its ring.
  ///
  /// - Parameters:
  ///   - model: The session model.
  ///   - isFocusEffectEnabled: `false` to apply `.focusEffectDisabled()`
  ///     above the items.
  /// - Returns: The bed.
  static func mountItems(of model: SessionModel, isFocusEffectEnabled: Bool) -> FocusRingBed {
    FocusRingBed(size: AgentCommandScopeHostedTests.windowSize) {
      VStack {
        ConversationView(session: model)
        RequestDeck(session: model)
      }
      .agentCommandScope(session: model)
      .focusEffectDisabled(!isFocusEffectEnabled)
      .environment(\.sessionModel, model)
      .transaction { $0.disablesAnimations = true }
    }
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
    _ inspect: (FocusedItem) async throws -> Void
  ) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let bed = mountItems(of: session.model, isFocusEffectEnabled: isFocusEffectEnabled)
    defer { bed.close() }
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    let item = thread.appending(try await sendItem(kind, to: session, rendering: bed))

    try await inspect(
      try await focusedItem(at: item, in: bed) {
        try land(on: item, in: thread, system: bed.system, by: landing)
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

  /// The beacon of the focused item holds the focus, and the scope draws
  /// its ring around the item in the theme accent, not in the tint of the
  /// host.
  @Test(arguments: ItemKind.allCases, FocusLanding.allCases)
  func theFocusRingOfAFocusedItemTakesTheThemeAccent(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      #expect(focused.responder is GeometryProbeView)
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
      #expect(focused.ring.isDrawn(in: FocusRingBed.defaultAccent))
    }
  }

  /// The focus ring of the focused item has the corners of a card of the
  /// kit: the large radius of the style.
  @Test(arguments: ItemKind.allCases, FocusLanding.allCases)
  func theFocusRingOfAFocusedItemHasTheCornersOfACard(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      try await FocusRingBed.expectRingCorners(
        of: focused.ring, size: focused.itemRect.size, cornerRadius: EditorStyle.default.radii.l)
    }
  }

  /// `.focusEffectDisabled()` above the thread turns off the focus ring of
  /// a focused item, and the focus still lands on the item.
  @Test(arguments: ItemKind.allCases)
  func aFocusedItemHasNoFocusRingUnderFocusEffectDisabled(kind: ItemKind) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: .nav, isFocusEffectEnabled: false) { focused in
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
      #expect(focused.ring.rows.isEmpty)
    }
  }
}
