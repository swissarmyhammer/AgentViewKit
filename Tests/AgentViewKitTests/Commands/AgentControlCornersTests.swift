@testable import AgentViewKit
import EditorStyle
import SwiftUI
import Testing

/// Tests for the corners of the focus ring of a bar control
/// (``AgentControlCorners``).
///
/// EditorKit draws the ring of a scope as the `RoundedRectangle` of the
/// radius that the scope asks for. The tests draw that shape over the frame
/// of a control.
@Suite struct AgentControlCornersTests {
  /// The frame of a wide control, such as a glass button with a text.
  static let wideControl = CGRect(x: 0, y: 0, width: 120, height: 28)

  /// A point inside the frame of ``wideControl``, at its top left corner,
  /// that a capsule leaves out.
  static let cornerPoint = CGPoint(x: 1, y: 1)

  /// The ring of a scope over `frame` with the corners of `corners`.
  ///
  /// - Parameters:
  ///   - corners: The corners of the control.
  ///   - frame: The frame of the control.
  /// - Returns: The path that EditorKit outlines.
  static func ring(_ corners: AgentControlCorners, in frame: CGRect) -> Path {
    RoundedRectangle(cornerRadius: corners.radius(in: EditorStyle.default)).path(in: frame)
  }

  @Test func theRingOfACapsuleControlIsTheCapsuleOfItsFrame() {
    let ring = Self.ring(.capsule, in: Self.wideControl)

    #expect(ring.boundingRect == Self.wideControl)
    #expect(!ring.contains(Self.cornerPoint))
    #expect(ring.contains(CGPoint(x: Self.wideControl.midX, y: Self.wideControl.minY + 1)))
  }

  @Test func theRingOfASurfaceControlHasTheRadiusOfTheSurface() {
    let style = EditorStyle.default
    let corners = AgentControlCorners.surface(.rounded(.medium))

    #expect(corners.radius(in: style) == SurfaceCorners.rounded(.medium).radius(in: style))
  }
}
