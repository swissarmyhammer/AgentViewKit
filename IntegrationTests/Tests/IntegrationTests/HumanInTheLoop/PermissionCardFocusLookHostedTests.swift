@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorStyle
import EditorTestSupport
import FoundationModelsACPClient
import QuartzCore
import SwiftUI
import Testing

@testable import EditorCommandsUI

/// The values of the bed of the focus look of a permission card.
private enum PermissionFocusBed {
  /// The red component of the theme accent of the bed: a color that no
  /// other view of the window draws.
  static let accentRed: CGFloat = 0.1

  /// The green component of that accent.
  static let accentGreen: CGFloat = 0.6

  /// The blue component of that accent.
  static let accentBlue: CGFloat = 0.3

  /// The theme accent of the bed.
  static let accent = Color(red: accentRed, green: accentGreen, blue: accentBlue)

  /// The fill of a focused item in a key window: the accent at the focused
  /// opacity of EditorKit.
  static let focusedFill = accent.opacity(EditorStyle.focusedSelectionOpacity)

  /// The side of the reference fill, which stands apart from the card.
  static let referenceSide: CGFloat = 12

  /// The largest difference of one component of a color that a layer holds.
  static let componentTolerance: CGFloat = 0.002

  /// The number of fills of the focused fill color in a window with a
  /// focused card: the reference fill and the fill of the card.
  static let focusedFillCount = 2

  /// The segment of the scope of a card out of a deck.
  static let cardSegment = FocusSegment(kind: "permissionCard")

  /// The size of the window.
  static let windowSize = CGSize(width: 480, height: 480)
}

/// The focus look of a focused permission card (EditorKit style.md,
/// "Selection and focus").
///
/// The card takes the keyboard focus itself (`@FocusState` and
/// `defaultFocus`), so the beacon of its scope does not hold that focus. The
/// card shows that focus as the focused fill of its surface, never as an
/// outline.
///
/// The tests read the layers of the window, never pixels, as EditorKit's
/// `SelectableItemHostedTests` does: a fill is the color of a layer, and a
/// ring is a `Canvas`, a layer with contents.
@Suite(.serialized, .hostedSerially) @MainActor struct PermissionCardFocusLookHostedTests {
  /// The view that holds the card.
  enum Host: CaseIterable, Sendable {
    /// A ``RequestDeck`` in the agent command scope of the session.
    case deck
    /// A ``PermissionView`` out of a deck, in a scope of its own.
    case card
  }

  /// The layers of a window, read while the card holds the keyboard focus
  /// and after the card loses it.
  struct FocusLayers {
    /// The number of layers with contents while the card holds the focus.
    let focusedContentCount: Int

    /// The colors of the fills while the card holds the focus, in the sRGB
    /// space.
    let focusedFills: [[CGFloat]]

    /// The number of layers with contents after the card loses the focus.
    let idleContentCount: Int
  }

  /// Shows the card of one permission request in `host`, reads the layers of
  /// the window while the card holds the keyboard focus itself, then takes
  /// the focus from the card and reads the layers again.
  ///
  /// The card takes the focus when it shows, by its `defaultFocus`.
  ///
  /// - Parameter host: The view that holds the card.
  /// - Returns: The layers with the focus on the card and with no focus.
  /// - Throws: An issue when the beacon never goes live, the card does not
  ///   hold the focus itself, or a layer cannot be read.
  static func focusLayers(in host: Host) async throws -> FocusLayers {
    let session = CancelFixtures.makeSession(state: nil, pendingPermissions: [CancelFixtures.permissionRequest])
    let request = try #require(session.pendingPermissions.first)
    let system = CommandSystem()
    let harness = HostedViewHarness(size: PermissionFocusBed.windowSize) {
      PermissionFocusBedView(host: host, session: session, request: request)
        .commandSystem(system)
        .transaction { $0.disablesAnimations = true }
    }
    defer { harness.close() }
    let path = Self.path(of: host, session: session, request: request)
    try #require(waitForLiveBeacons([path], in: system))
    await settle(harness)
    let responder = try #require(harness.window.firstResponder as? NSView)
    try #require(!(responder is GeometryProbeView), "the beacon of the scope holds the focus, not the card")
    let focusedContentCount = try contentLayerCount(in: harness)
    let focusedFills = try fillColors(in: harness)

    try #require(harness.window.makeFirstResponder(nil))
    await settle(harness)
    return FocusLayers(
      focusedContentCount: focusedContentCount, focusedFills: focusedFills,
      idleContentCount: try contentLayerCount(in: harness))
  }

  /// Lets SwiftUI land each update that is pending, then the focus of the
  /// card that the card gives to its host as a preference, and renders.
  ///
  /// - Parameter harness: The harness of the window.
  static func settle(_ harness: HostedViewHarness<some View>) async {
    for _ in 0..<settlePassCount {
      await RunLoopBlockFence.afterPendingBlocks()
      harness.render()
    }
  }

  /// The number of passes of ``settle(_:)``: one for the update of the
  /// focus, and one for the update that the preference of the focus starts.
  static let settlePassCount = 2

  /// The path of the scope of the card in `host`, whose beacon shows that
  /// the card is in the window.
  ///
  /// - Parameters:
  ///   - host: The view that holds the card.
  ///   - session: The session model of the request.
  ///   - request: The request of the card.
  /// - Returns: The path.
  static func path(of host: Host, session: SessionModel, request: PendingPermissionRequest) -> FocusPath {
    switch host {
    case .deck:
      .root(AgentCommandTarget.segment(for: session)).appending(AgentScopeKind.request(request.id))
    case .card:
      .root(PermissionFocusBed.cardSegment)
    }
  }

  /// A production change that fails this test: the card shows its focus as
  /// an outline (`.editorFocusRing`), and not as the focused fill of its
  /// surface.
  @Test(arguments: Host.allCases)
  func aFocusedPermissionCardShowsTheFocusedFill(host: Host) async throws {
    let layers = try await Self.focusLayers(in: host)
    let expected = try #require(layers.focusedFills.last)
    let matches = layers.focusedFills.filter { Self.isSame($0, expected) }
    #expect(matches.count == PermissionFocusBed.focusedFillCount, "fills: \(layers.focusedFills)")
  }

  /// A production change that fails this test: the card draws a focus ring,
  /// a `Canvas` layer, while it holds the focus.
  @Test(arguments: Host.allCases)
  func aFocusedPermissionCardShowsNoOutline(host: Host) async throws {
    let layers = try await Self.focusLayers(in: host)
    #expect(
      layers.focusedContentCount == layers.idleContentCount,
      "idle: \(layers.idleContentCount), focused: \(layers.focusedContentCount)")
  }

  /// The number of layers of the window that draw content of their own, such
  /// as a text or a `Canvas`.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: The number of layers with contents.
  /// - Throws: An issue when the hosting view has no layer.
  private static func contentLayerCount(in harness: HostedViewHarness<some View>) throws -> Int {
    try layers(in: harness).filter { $0.contents != nil }.count
  }

  /// The colors of the fills of the window, in the sRGB space, depth first.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: The red, green, blue and alpha components of each fill.
  /// - Throws: An issue when the hosting view has no layer, or when a fill
  ///   does not convert to the sRGB space.
  private static func fillColors(in harness: HostedViewHarness<some View>) throws -> [[CGFloat]] {
    let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    return try layers(in: harness).flatMap(fills(of:)).map { color in
      let converted = try #require(color.converted(to: space, intent: .defaultIntent, options: nil))
      return try #require(converted.components)
    }
  }

  /// Each layer of the hosting view of `harness`, depth first.
  ///
  /// - Parameter harness: The harness of the window.
  /// - Returns: The layers.
  /// - Throws: An issue when the hosting view has no layer.
  private static func layers(in harness: HostedViewHarness<some View>) throws -> [CALayer] {
    sublayers(of: try #require(harness.hostingView.layer))
  }

  /// `layer` and each layer below it, depth first.
  ///
  /// - Parameter layer: The root of the layers.
  /// - Returns: The layers.
  private static func sublayers(of layer: CALayer) -> [CALayer] {
    [layer] + (layer.sublayers ?? []).flatMap(sublayers(of:))
  }

  /// The fill colors of `layer` itself: a background color, and the fill of
  /// a shape layer.
  ///
  /// - Parameter layer: A layer of the window.
  /// - Returns: The colors.
  private static func fills(of layer: CALayer) -> [CGColor] {
    [layer.backgroundColor, (layer as? CAShapeLayer)?.fillColor].compactMap { $0 }
  }

  /// Whether two colors agree.
  ///
  /// - Parameters:
  ///   - first: The components of a color.
  ///   - second: The components of the other color.
  /// - Returns: Whether each pair differs by at most the tolerance of the bed.
  private static func isSame(_ first: [CGFloat], _ second: [CGFloat]) -> Bool {
    first.count == second.count
      && zip(first, second).allSatisfy { abs($0 - $1) <= PermissionFocusBed.componentTolerance }
  }
}

/// The card of a permission request in its host, above a reference fill of
/// the focused fill color, under the accent of the bed in a key window.
private struct PermissionFocusBedView: View {
  /// The view that holds the card.
  let host: PermissionCardFocusLookHostedTests.Host

  /// The session model that holds the request.
  let session: SessionModel

  /// The request of the card.
  let request: PendingPermissionRequest

  var body: some View {
    VStack {
      card
      Rectangle()
        .fill(PermissionFocusBed.focusedFill)
        .frame(width: PermissionFocusBed.referenceSide, height: PermissionFocusBed.referenceSide)
    }
    .environment(\.themeAccent, PermissionFocusBed.accent)
    .environment(\.appearsActive, true)
  }

  /// The card in its host.
  @ViewBuilder private var card: some View {
    switch host {
    case .deck:
      RequestDeck(session: session).agentCommandScope(session: session)
    case .card:
      PermissionView(request: request, session: session).commandScope(segment: PermissionFocusBed.cardSegment)
    }
  }
}
