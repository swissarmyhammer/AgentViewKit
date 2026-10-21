@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that a ``StatusBar`` has no fill and no glass, and that the
/// separator stroke of the content edge marks its edge (D113).
/// ``StateBanner``, ``SessionStreamBanner`` and ``AgentConnectionBanner`` show
/// their messages in this bar.
///
/// The tests use the edge check of ``ContentSurfaceHostedProbe``. The bar has
/// a button with a glass button style, so the render also shows the one
/// control that can use glass.
@Suite(.serialized, .hostedSerially) @MainActor struct StatusBarSurfaceHostedTests {
  /// The size of the window. The bar fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 360, height: 160)

  /// A bar with the message of missed updates and a Reload button.
  static var bar: StatusBar {
    StatusBar(
      message: SessionStreamBanner.missedUpdatesMessage,
      action: StatusBar.Action(
        title: "Reload", systemImage: SessionStreamBanner.reloadSymbol,
        identifier: SessionStreamBanner.reloadIdentifier, isEnabled: true, perform: {}))
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsInsideTheEdgeOfTheBar(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsInsideTheEdge(
      of: Self.bar, reducesTransparency: reducesTransparency, size: Self.size)
  }
}
