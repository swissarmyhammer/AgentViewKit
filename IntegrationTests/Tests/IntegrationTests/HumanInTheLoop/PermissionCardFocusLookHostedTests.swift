@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import EditorCommandsUI

/// The values of the bed of the focus look of a permission card.
private enum PermissionFocusBed {
  /// The segment of the scope of a card out of a deck.
  static let cardSegment = FocusSegment(kind: "permissionCard")

  /// The side of the square window.
  static let windowSide: CGFloat = 480

  /// The size of the window.
  static let windowSize = CGSize(width: windowSide, height: windowSide)
}

/// The focus look of a focused permission card (EditorKit style.md,
/// "Selection and focus").
///
/// The card takes the keyboard focus itself (`@FocusState` and
/// `defaultFocus`), so the beacon of its scope does not hold that focus. The
/// card shows that focus as the focused fill of its surface, never as an
/// outline.
///
/// The tests read the layers of the window, never pixels, through
/// ``FocusLookBed``: a fill is the color of a layer, and a ring is a
/// `Canvas`, a layer with contents.
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

    /// The number of fills of the color of the reference fill while the card
    /// holds the focus.
    let focusedFillCount: Int

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
    try FocusLookBed.requireItemHoldsFocus(in: harness)
    let focusedContentCount = try FocusLookBed.contentLayerCount(in: harness)
    let focusedFillCount = try FocusLookBed.referenceFillCount(in: harness)

    try #require(harness.window.makeFirstResponder(nil))
    await settle(harness)
    return FocusLayers(
      focusedContentCount: focusedContentCount, focusedFillCount: focusedFillCount,
      idleContentCount: try FocusLookBed.contentLayerCount(in: harness))
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
      AgentCommandTarget.requestPath(in: session, request: request)
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
    #expect(layers.focusedFillCount == FocusLookBed.focusedFillCount)
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
}

/// The card of a permission request in its host, in the bed of
/// ``FocusLookBed``.
private struct PermissionFocusBedView: View {
  /// The view that holds the card.
  let host: PermissionCardFocusLookHostedTests.Host

  /// The session model that holds the request.
  let session: SessionModel

  /// The request of the card.
  let request: PendingPermissionRequest

  var body: some View {
    card.focusLookBed()
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
