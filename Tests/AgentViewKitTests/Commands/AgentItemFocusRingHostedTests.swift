@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import struct EditorTestSupport.AccentTheme
import struct EditorTestSupport.CapturedImage
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
/// in the look of ``AccentLook``, in a real key window on the screen
/// (``CaptureMount``): under the red tint of a host and the shared
/// ``AccentTheme`` of EditorKit with a blue accent. It captures the window
/// from the window server before the focus lands and again after, and the
/// ring is the pixels that changed in the first pixel column inside the item:
/// the band of the ring that laps into the item, which the ring of each shape
/// paints down its straight side.
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
  /// The look sets `\.appearsActive` itself, so that a test chooses the
  /// window state of the selection whatever the key window is.
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
    /// A capture holds the rows of the window from the top, as the window
    /// space of EditorKit does, so the column is read from the top, and only
    /// its rows in the capture.
    ///
    /// - Parameters:
    ///   - focused: The capture of the window after the focus lands.
    ///   - baseline: The capture of the window before the focus lands.
    ///   - scope: The rect of the scope, in the window space of EditorKit.
    /// - Throws: An error when a capture has no such column.
    init(focused: CapturedImage, baseline: CapturedImage, scope: CGRect) throws {
      let scale = CaptureGeometry.scale
      let column = Int((scope.minX * scale).rounded())
      let now = try focused.pixelColumn(at: column)
      let before = try baseline.pixelColumn(at: column)
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

  /// The capture of the hosting view of `mount` from the window server, over
  /// the white capture background.
  ///
  /// - Parameter mount: The mount that shows the view.
  /// - Returns: The image.
  /// - Throws: A `WindowCaptureError`, or the error of ScreenCaptureKit.
  static func capture(_ mount: CaptureMount<some View>) async throws -> CapturedImage {
    try await CapturedImage(capturing: mount.hostingView, over: captureBackground)
  }

  /// Captures the window of `mount`, lands the focus with `land`, renders
  /// one pass, and reads the first responder and the ring of `scope`.
  ///
  /// - Parameters:
  ///   - scope: The path of the scope that the focus lands on.
  ///   - mount: The mount that shows the scope.
  ///   - system: The command system of the window.
  ///   - land: Lands the focus on the scope.
  /// - Returns: The first responder, with the area of the scope and its
  ///   ring.
  /// - Throws: An issue when the focus does not land, or an error when a
  ///   capture fails.
  static func focus(
    _ scope: FocusPath, in mount: CaptureMount<some View>, system: CommandSystem,
    by land: () throws -> Void
  ) async throws -> FocusedItem {
    let baseline = try await capture(mount)
    try land()
    mount.render()

    let responder = try #require(mount.window.firstResponder as? NSView)
    let scopeRect = try #require(system.geometry.rect(of: scope))
    let ring = try RingColumn(focused: await capture(mount), baseline: baseline, scope: scopeRect)
    return FocusedItem(
      responder: responder, itemRect: scopeRect, ring: ring, windowSize: mount.hostingView.bounds.size)
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
  static func referenceRing(at rect: CGRect, cornerRadius: CGFloat, windowSize size: CGSize) async throws
    -> RingColumn
  {
    let system = CommandSystem()
    let path = FocusPath.root(referenceSegment)
    let mount = CaptureMount(
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
    defer { mount.close() }

    let focused = try await focus(path, in: mount, system: system) {
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
  static func expectRing(of focused: FocusedItem, cornerRadius: CGFloat) async throws {
    let expected = try await referenceRing(
      at: focused.itemRect, cornerRadius: cornerRadius, windowSize: focused.windowSize)

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
  /// The bed shows the conversation without the bars of ``AgentThreadView``,
  /// so that the Liquid Glass of a bar does not cover a row and its ring.
  ///
  /// - Parameters:
  ///   - model: The session model.
  ///   - system: The command system of the window.
  ///   - isFocusEffectEnabled: `false` to apply `.focusEffectDisabled()`
  ///     above the items.
  /// - Returns: The mount.
  static func mountItems(
    of model: SessionModel, system: CommandSystem, isFocusEffectEnabled: Bool
  ) -> CaptureMount<some View> {
    CaptureMount(
      VStack {
        ConversationView(session: model)
        RequestDeck(session: model)
      }
      .agentCommandScope(session: model)
      .focusEffectDisabled(!isFocusEffectEnabled)
      .modifier(AccentLook())
      .environment(\.sessionModel, model)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true },
      size: AgentCommandScopeHostedTests.windowSize)
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
    _ inspect: (FocusedItem) async throws -> Void
  ) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let mount = mountItems(of: session.model, system: system, isFocusEffectEnabled: isFocusEffectEnabled)
    defer { mount.close() }
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    let item = thread.appending(try await sendItem(kind, to: session, rendering: mount))

    try await inspect(
      try await focus(item, in: mount, system: system) {
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
      try await Self.expectRing(of: focused, cornerRadius: EditorStyle.default.radii.l)
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
