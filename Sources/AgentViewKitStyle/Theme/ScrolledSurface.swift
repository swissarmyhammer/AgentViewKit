import EditorStyle
import SwiftUI

/// The shape of a rounded surface in the rows of a scrolled list, such as a
/// code block, a terminal or an error card of a thread (card ^9ync5h3).
///
/// The surface shape of EditorKit (`EditorSurface.shape(radius:)`) is a
/// concentric shape on macOS 26: its corners follow the corners of its
/// container, the window. A concentric shape thus has another shape at each
/// position in the window. When a list scrolls, SwiftUI draws each view in
/// the layer of a concentric shape again at each frame, also the text of
/// the row. A surface in a scrolled row has a continuous rounded rectangle
/// of its radius in place of it (`EditorSurface.fallbackShape(radius:)`),
/// whose shape does not change when the row moves. Far from the corners of
/// the window, the two shapes have the same corners.
public enum ScrolledSurface {
  /// The shape of a surface in a scrolled row.
  ///
  /// - Parameter radius: The corner radius, a radius of the scale.
  /// - Returns: A continuous rounded rectangle of `radius`.
  public static func shape(radius: CGFloat) -> RoundedRectangle {
    EditorSurface.fallbackShape(radius: radius)
  }
}

extension View {
  /// Marks the edge of this component of a scrolled row with the thin
  /// `.separator` stroke of ``ScrolledSurface/shape(radius:)``.
  ///
  /// It is the `.inlineEdge(in:)` of EditorKit with the shape of a
  /// scrolled surface, so a scroll of the row does not draw the row again.
  ///
  /// - Parameter radius: The corner radius, a radius of the scale.
  /// - Returns: The component with its edge.
  public func scrolledInlineEdge(radius: CGFloat) -> some View {
    inlineEdge(in: ScrolledSurface.shape(radius: radius))
  }
}
