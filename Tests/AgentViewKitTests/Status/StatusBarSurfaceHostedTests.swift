@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Checks that a ``StatusBar`` is on the content surface of the kit, and not
/// on glass (D110 (b)). ``StateBanner``, ``SessionStreamBanner`` and
/// ``AgentConnectionBanner`` show their messages in this bar.
///
/// The tests use the method of ``ContentSurfaceHostedProbe``. The bar has a
/// button with a glass button style, so the render also shows the one
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
  func theBackdropShowsWhenItIsInFrontOfTheBar(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.bar, backdrop: .inFront, reducesTransparency: reducesTransparency, size: Self.size)
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheBar(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.bar, backdrop: .behind, reducesTransparency: reducesTransparency, size: Self.size)
  }
}
