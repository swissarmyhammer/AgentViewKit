@testable import AgentViewKit
import AgentViewKitStyle
import SwiftUI
import Testing

/// Tests for the corners of the focus ring of a bar control
/// (``AgentControlCorners``).
///
/// The scope of a control asks for the ring of these surface corners, or
/// asks for none, so the ring takes the shape that the control tells the
/// scope.
@Suite struct AgentControlCornersTests {
  /// A production change that fails this test: the scope of a button asks
  /// for corners of its own, which hide the shape of the bezel that the
  /// button tells the scope.
  @Test func theScopeOfAControlAsksForNoCorners() {
    #expect(AgentControlCorners.control.surfaceCorners == nil)
  }

  @Test func theRingOfASurfaceControlHasTheCornersOfTheSurface() {
    let corners = AgentControlCorners.surface(.rounded(.medium))

    #expect(corners.surfaceCorners == .rounded(.medium))
  }
}
