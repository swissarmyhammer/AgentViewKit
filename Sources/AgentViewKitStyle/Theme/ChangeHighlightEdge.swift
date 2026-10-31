import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

extension View {
  /// Marks this view as just changed, with an edge in the change color of the
  /// theme (`diffChangedBackground`), such as a card that an agent changed or a
  /// new checkpoint.
  ///
  /// The highlight is an edge, not a fill and not the accent: the accent marks
  /// only the selection and the focus (EditorKit `style.md`, "Accent and
  /// fills"). It fades in and out, with no animation under Reduce Motion, and it
  /// takes no clicks and no accessibility element. It adds no space around the
  /// view.
  ///
  /// - Parameters:
  ///   - radius: The radius step of the shape of the view.
  ///   - isShowing: Whether the view shows the highlight.
  /// - Returns: The view, with the edge.
  public func changeHighlightEdge(radius: EditorStyle.Radius, isShowing: Bool) -> some View {
    changeHighlightEdge(corners: .rounded(radius), isShowing: isShowing)
  }

  /// Marks this view as just changed, with an edge in the change color of the
  /// theme, on the corners of its surface, such as ``SurfaceCorners/card``.
  ///
  /// The edge is the edge of ``changeHighlightEdge(radius:isShowing:)``.
  ///
  /// - Parameters:
  ///   - corners: The corners of the surface of the view.
  ///   - isShowing: Whether the view shows the highlight.
  /// - Returns: The view, with the edge.
  public func changeHighlightEdge(corners: SurfaceCorners, isShowing: Bool) -> some View {
    modifier(ChangeHighlightEdge(corners: corners, isShowing: isShowing))
  }
}

/// The edge of ``SwiftUI/View/changeHighlightEdge(corners:isShowing:)``.
struct ChangeHighlightEdge: ViewModifier {
  /// The width of the edge, in points: twice the hairline `.separator` edge of a
  /// card or a tile, so the highlight reads on that edge.
  static let width: CGFloat = 2

  /// The corners of the surface of the view.
  let corners: SurfaceCorners

  /// Whether the view shows the highlight.
  let isShowing: Bool

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// The corner radius of the edge in `style`.
  ///
  /// - Parameter style: The shared style that gives the radius scale.
  /// - Returns: The radius of ``corners``.
  func radius(in style: EditorStyle) -> CGFloat {
    corners.radius(in: style)
  }

  /// The animation that fades the edge in and out.
  ///
  /// - Parameter reduceMotion: Whether Reduce Motion is on.
  /// - Returns: `nil` under Reduce Motion, else the default animation.
  static func animation(reduceMotion: Bool) -> Animation? {
    reduceMotion ? nil : .default
  }

  func body(content: Content) -> some View {
    content.overlay {
      EditorSurface.shape(radius: radius(in: editorStyle))
        .stroke(editorTheme.diffChangedBackground, lineWidth: Self.width)
        .opacity(isShowing ? 1 : 0)
        .animation(Self.animation(reduceMotion: reduceMotion), value: isShowing)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
  }
}

#Preview("A view with the edge and one with none") {
  VStack {
    ForEach([true, false], id: \.self) { isShowing in
      Text(verbatim: StylePreviewFixtures.fileName)
        .contentTile()
        .changeHighlightEdge(corners: .card, isShowing: isShowing)
    }
  }
  .padding()
}
