@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import SwiftUI
import Testing

/// Tests for the focus ring of an item of a thread that a `nav.*` move or a
/// jump focuses (AVK-7d).
///
/// The item has no focusable view of its own, so EditorKit gives the focus
/// to the beacon of the item scope, and the beacon draws the system focus
/// ring over the item. The ring has the corners of a card of the kit.
///
/// Each test shows one item in the thread, puts the focus on it, and then
/// renders one pass before it reads the first responder of the window.
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

  /// The bits of one channel of a pixel of a mask bitmap.
  static let bitsPerSample = 8

  /// The channels of one pixel of a mask bitmap: red, green, blue and alpha.
  static let samplesPerPixel = 4

  /// The first responder of a window, with the area of the focused item.
  struct FocusedItem {
    /// The first responder of the window.
    let responder: NSView

    /// The rect of the item scope, in the window space of EditorKit.
    let itemRect: CGRect
  }

  /// Shows one item of `kind`, lands the focus on it by `landing`, renders
  /// one pass, and gives the first responder to `inspect`.
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

    try land(on: item, in: thread, system: system, by: landing)
    harness.render()

    let responder = try #require(harness.window.firstResponder as? NSView)
    try inspect(FocusedItem(responder: responder, itemRect: try #require(system.geometry.rect(of: item))))
  }

  /// Sends one item of `kind` from the agent, and renders `harness` after the
  /// session model holds it.
  ///
  /// - Parameters:
  ///   - kind: The kind of the item.
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view.
  /// - Returns: The segment of the item scope.
  /// - Throws: The error of the transport.
  static func sendItem(
    _ kind: ItemKind, to session: ScriptedSession, rendering harness: HostedViewHarness<some View>
  ) async throws -> FocusSegment {
    switch kind {
    case .message:
      try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)
      return AgentScopeKind.message(rowKey: try #require(session.model.transcript.first).rowKey)
    case .toolCall:
      let toolCall = try await AgentScopeSubjectHostedTests.sendScopeToolCall(to: session, rendering: harness)
      return AgentScopeKind.toolCall(toolCall.toolCallId)
    case .request:
      return AgentScopeKind.request(try await session.sendPermissionRequest(id: requestID, rendering: harness))
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

  /// The pixels that `draw` paints into a clear bitmap of `bounds`, in the
  /// coordinates of `bounds`.
  ///
  /// - Parameters:
  ///   - bounds: The area of the bitmap.
  ///   - draw: The drawing, in the current graphics context.
  /// - Returns: The bytes of the bitmap.
  /// - Throws: An issue when AppKit makes no bitmap.
  static func pixels(of bounds: CGRect, drawing draw: () -> Void) throws -> Data {
    let bitmap = try #require(
      NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(bounds.width.rounded(.up)),
        pixelsHigh: Int(bounds.height.rounded(.up)), bitsPerSample: bitsPerSample,
        samplesPerPixel: samplesPerPixel, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0))
    let context = try #require(NSGraphicsContext(bitmapImageRep: bitmap))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.translateBy(x: -bounds.minX, y: -bounds.minY)
    draw()
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    let bytes = try #require(bitmap.bitmapData)
    return Data(bytes: bytes, count: bitmap.bytesPerRow * bitmap.pixelsHigh)
  }

  /// Expects the focus ring mask of `responder` to be the rounded rectangle
  /// of `cornerRadius` over the bounds of `responder`.
  ///
  /// - Parameters:
  ///   - responder: The view that holds the focus.
  ///   - cornerRadius: The radius of the corners of the expected ring.
  /// - Throws: An issue when AppKit makes no bitmap.
  static func expectFocusRingMask(of responder: NSView, cornerRadius: CGFloat) throws {
    let bounds = responder.bounds
    let ring = RoundedRectangle(cornerRadius: cornerRadius).path(in: bounds).cgPath
    let expected = try pixels(of: bounds) {
      let context = NSGraphicsContext.current?.cgContext
      context?.addPath(ring)
      context?.fillPath()
    }

    let mask = try pixels(of: bounds) { responder.drawFocusRingMask() }

    #expect(mask == expected)
  }

  /// The focus ring of the focused item is over the whole item.
  @Test(arguments: ItemKind.allCases, FocusLanding.allCases)
  func theFocusRingOfAFocusedItemCoversTheItem(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
      #expect(focused.responder.focusRingMaskBounds == focused.responder.bounds)
    }
  }

  /// The focus ring of the focused item has the corners of a card of the
  /// kit: the large radius of the style.
  @Test(arguments: ItemKind.allCases, FocusLanding.allCases)
  func theFocusRingOfAFocusedItemHasTheCornersOfACard(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      try Self.expectFocusRingMask(of: focused.responder, cornerRadius: EditorStyle.default.radii.l)
    }
  }

  /// `.focusEffectDisabled()` above the thread turns off the focus ring of
  /// a focused item, and the focus still lands on the item.
  @Test(arguments: ItemKind.allCases)
  func aFocusedItemHasNoFocusRingUnderFocusEffectDisabled(kind: ItemKind) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: .nav, isFocusEffectEnabled: false) { focused in
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
      #expect(focused.responder.focusRingMaskBounds == .zero)
    }
  }
}
