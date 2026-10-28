@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import EditorTestSupport
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
/// Each test shows one item of a session (``mountItems(of:system:isFocusEffectEnabled:)``)
/// in the look of ``AccentLook``: a
/// key window, under the red tint of a host and the shared ``AccentTheme``
/// of EditorKit with a blue accent. It reads the window before the focus
/// lands and again after, and the ring is the pixels that changed in the
/// first pixel column inside the item: the band of the ring that laps into
/// the item, which the ring of each shape paints down its straight side.
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

  /// The tint of the host: a red that the ring and the selection must not
  /// take.
  static let hostTint = Color.red

  /// The theme accent of the tests: a blue that no part of the views draws.
  static let accent = Color.blue

  /// The index of the red channel of a pixel, the channel of the host tint.
  static let redChannel = 0

  /// The index of the blue channel of a pixel, the largest channel of a ring
  /// pixel in the blue accent.
  static let accentChannel = 2

  /// The color channels of a pixel, before its alpha: red, green and blue.
  static let colorChannelCount = 3

  /// The color behind each capture: a white that the red tint and the blue
  /// accent both differ from.
  static let captureBackground = CGColor(gray: 1, alpha: 1)

  /// The segment of the one scope of a reference ring bed.
  static let referenceSegment = FocusSegment(kind: "ring", id: "reference")

  /// The look of a bed that shows a focus ring or a selection in the theme
  /// accent: the red tint of a host, the shared ``AccentTheme`` of EditorKit
  /// with the blue accent, and a window that appears active or not.
  ///
  /// The window of a ``HostedViewHarness`` is never key, and a focus ring and
  /// an accent fill show only in a key window, so the look sets
  /// `\.appearsActive` itself.
  struct AccentLook: ViewModifier {
    /// Whether the window appears active.
    var appearsActive = true

    func body(content: Content) -> some View {
      content
        .tint(AgentItemFocusRingHostedTests.hostTint)
        .editorTheme(AccentTheme(accent: AgentItemFocusRingHostedTests.accent))
        .environment(\.appearsActive, appearsActive)
    }
  }

  /// What a focus ring changes in the first pixel column inside a scope.
  struct RingColumn: Equatable {
    /// The rows of the column that the ring changes, in pixels from the top
    /// of the scope.
    let rows: [Int]

    /// The pixels of those rows after the focus lands: the red, green, blue
    /// and alpha bytes of each.
    let pixels: [[UInt8]]

    /// Reads the pixels of the first column inside `scope` that differ
    /// between `baseline` and `focused`.
    ///
    /// The capture of a hosting view reads its flipped layer, so the first
    /// row of a capture is the bottom row of the window. The column is read
    /// from the top of the window, as the window space of EditorKit is, and
    /// only its rows in the capture.
    ///
    /// - Parameters:
    ///   - focused: The window after the focus lands.
    ///   - baseline: The window before the focus lands.
    ///   - scope: The rect of the scope, in the window space of EditorKit.
    /// - Throws: An error when a capture has no such column.
    init(focused: RenderedViewImage, baseline: RenderedViewImage, scope: CGRect) throws {
      let scale = CGFloat(RenderedViewImage.captureScale)
      let column = Int((scope.minX * scale).rounded())
      let now = Array(try focused.pixelColumn(at: column).reversed())
      let before = Array(try baseline.pixelColumn(at: column).reversed())
      let top = Int((scope.minY * scale).rounded())
      let shown = max(top, 0)..<min(Int((scope.maxY * scale).rounded()), now.count)
      let changed = (shown.isEmpty ? [] : Array(shown)).filter { now[$0] != before[$0] }
      rows = changed.map { $0 - top }
      pixels = changed.map { now[$0] }
    }
  }

  /// The first responder of a window, with the area of the focused item and
  /// what its ring changed.
  struct FocusedItem {
    /// The first responder of the window.
    let responder: NSView

    /// The rect of the item scope, in the window space of EditorKit.
    let itemRect: CGRect

    /// What the focus ring changed in the first pixel column inside the
    /// item.
    let ring: RingColumn

    /// The size of the window that shows the item.
    let windowSize: CGSize
  }

  /// The pixels of the hosting view of `harness`, over the white capture
  /// background.
  ///
  /// - Parameter harness: The harness that shows the view.
  /// - Returns: The pixels.
  /// - Throws: An error when the hosting view gives no pixels.
  static func capture(_ harness: HostedViewHarness<some View>) throws -> RenderedViewImage {
    try RenderedViewImage(capturing: harness.hostingView, over: captureBackground)
  }

  /// Reads the window of `harness`, lands the focus with `land`, renders
  /// one pass, and reads the first responder and the ring of `scope`.
  ///
  /// - Parameters:
  ///   - scope: The path of the scope that the focus lands on.
  ///   - harness: The harness that shows the scope.
  ///   - system: The command system of the window.
  ///   - land: Lands the focus on the scope.
  /// - Returns: The first responder, with the area of the scope and its
  ///   ring.
  /// - Throws: An issue when the focus does not land, or an error when a
  ///   capture fails.
  static func focus(
    _ scope: FocusPath, in harness: HostedViewHarness<some View>, system: CommandSystem,
    by land: () throws -> Void
  ) throws -> FocusedItem {
    let baseline = try capture(harness)
    try land()
    harness.render()

    let responder = try #require(harness.window.firstResponder as? NSView)
    let scopeRect = try #require(system.geometry.rect(of: scope))
    let ring = try RingColumn(focused: capture(harness), baseline: baseline, scope: scopeRect)
    return FocusedItem(
      responder: responder, itemRect: scopeRect, ring: ring, windowSize: harness.hostingView.bounds.size)
  }

  /// What the focus ring of a plain scope of EditorKit changes in the first
  /// pixel column inside it, for a scope at `rect` with corners of
  /// `cornerRadius`, in a window of `size` in the ``AccentLook``.
  ///
  /// This is the ring that an item with those corners must draw.
  ///
  /// - Parameters:
  ///   - rect: The rect of the scope, in the window space of EditorKit.
  ///   - cornerRadius: The radius of the corners of the ring.
  ///   - size: The size of the window.
  /// - Returns: What the ring changed.
  /// - Throws: An issue when the focus does not land on the scope, or an
  ///   error when a capture fails.
  static func referenceRing(at rect: CGRect, cornerRadius: CGFloat, windowSize size: CGSize) throws -> RingColumn {
    let system = CommandSystem()
    let path = FocusPath.root(referenceSegment)
    let harness = HostedViewHarness(
      Color.clear
        .frame(width: rect.width, height: rect.height)
        .commandScope(segment: referenceSegment)
        .scopeFocusRing(cornerRadius: cornerRadius)
        .padding(.leading, rect.minX)
        .padding(.top, rect.minY)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .modifier(AccentLook())
        .commandSystem(system),
      size: size)
    defer { harness.close() }
    harness.render()

    let focused = try focus(path, in: harness, system: system) {
      try #require(system.geometry.requestFocus(at: path))
    }

    try #require(focused.itemRect == rect)
    return focused.ring
  }

  /// Expects the ring of `focused` to be the ring of a plain scope of
  /// EditorKit at the same rect with corners of `cornerRadius`.
  ///
  /// - Parameters:
  ///   - focused: The focused scope and its ring.
  ///   - cornerRadius: The radius of the corners of the expected ring.
  /// - Throws: An issue when the reference ring does not land, or an error
  ///   when a capture fails.
  static func expectRing(of focused: FocusedItem, cornerRadius: CGFloat) throws {
    let expected = try referenceRing(at: focused.itemRect, cornerRadius: cornerRadius, windowSize: focused.windowSize)

    #expect(!expected.rows.isEmpty)
    #expect(focused.ring.rows == expected.rows)
  }

  /// Expects each pixel of `ring` to take the theme accent, not the red
  /// tint of the host: blue is the largest channel, and it is larger than
  /// red.
  ///
  /// - Parameter ring: What a focus ring changed.
  static func expectTheThemeAccent(in ring: RingColumn) {
    #expect(!ring.pixels.isEmpty)
    for pixel in ring.pixels {
      #expect(pixel.prefix(colorChannelCount).max() == pixel[accentChannel])
      #expect(pixel[accentChannel] > pixel[redChannel])
    }
  }

  /// Shows the items of `model`, the rows of its conversation and the cards
  /// of its deck, in the agent command scope of the session and in the
  /// ``AccentLook``.
  ///
  /// The bed shows the conversation without the bars of ``AgentThreadView``.
  /// Their Liquid Glass is drawn by the render server, and with it over the
  /// list, a capture of the window in the test process does not show a
  /// change of the rows under it, the focus ring included.
  ///
  /// - Parameters:
  ///   - model: The session model.
  ///   - system: The command system of the window.
  ///   - isFocusEffectEnabled: `false` to apply `.focusEffectDisabled()`
  ///     above the items.
  /// - Returns: The harness.
  static func mountItems(
    of model: SessionModel, system: CommandSystem, isFocusEffectEnabled: Bool
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: AgentCommandScopeHostedTests.windowSize) {
      VStack {
        ConversationView(session: model)
        RequestDeck(session: model)
      }
      .agentCommandScope(session: model)
      .focusEffectDisabled(!isFocusEffectEnabled)
      .modifier(AccentLook())
      .environment(\.sessionModel, model)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
  }

  /// Shows one item of `kind`, lands the focus on it by `landing`, renders
  /// one pass, and gives the focused item to `inspect`.
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
    let harness = mountItems(of: session.model, system: system, isFocusEffectEnabled: isFocusEffectEnabled)
    defer { harness.close() }
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    let item = thread.appending(try await sendItem(kind, to: session, rendering: harness))

    try inspect(
      try focus(item, in: harness, system: system) {
        try land(on: item, in: thread, system: system, by: landing)
      })
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
      return AgentScopeKind.toolCall(toolCall.toolCallId.rawValue)
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

  /// The beacon of the focused item holds the focus, and the scope draws
  /// its ring around the item in the theme accent, not in the tint of the
  /// host.
  @Test(arguments: ItemKind.allCases, FocusLanding.allCases)
  func theFocusRingOfAFocusedItemTakesTheThemeAccent(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      #expect(focused.responder is GeometryProbeView)
      #expect(WindowSpace.rect(of: focused.responder) == focused.itemRect)
      Self.expectTheThemeAccent(in: focused.ring)
    }
  }

  /// The focus ring of the focused item has the corners of a card of the
  /// kit: the large radius of the style.
  @Test(arguments: ItemKind.allCases, FocusLanding.allCases)
  func theFocusRingOfAFocusedItemHasTheCornersOfACard(kind: ItemKind, landing: FocusLanding) async throws {
    try await Self.inspectFocusedItem(kind, landedBy: landing) { focused in
      try Self.expectRing(of: focused, cornerRadius: EditorStyle.default.radii.l)
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
