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

  /// The pixels of the bar with the backdrop, in light mode, with only
  /// Reduce Transparency changed.
  ///
  /// - Parameters:
  ///   - placement: Where the backdrop is.
  ///   - reducesTransparency: Whether Reduce Transparency is on.
  /// - Returns: The pixels.
  /// - Throws: An error when AppKit gives no pixels.
  static func pixels(backdrop placement: BackdropPlacement, reducesTransparency: Bool) throws
    -> RenderedPixels
  {
    try ContentSurfaceHostedProbe.pixels(
      of: bar, backdrop: placement, reducesTransparency: reducesTransparency, size: size)
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheBar(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .inFront, reducesTransparency: reducesTransparency)
    #expect(pixels.contains(GlassRenderProbeTests.backdrop))
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheBar(reducesTransparency: Bool) throws {
    let pixels = try Self.pixels(backdrop: .behind, reducesTransparency: reducesTransparency)
    #expect(!pixels.contains(GlassRenderProbeTests.backdrop))
  }
}
