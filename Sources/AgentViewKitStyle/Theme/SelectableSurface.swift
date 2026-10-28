import EditorStyle
import SwiftUI

/// The corners of a surface of a view kit, which its selection surface, its
/// hit shape and the focus ring of its scope follow.
///
/// The corners name a step of the radius scale of `\.editorStyle`, or square
/// corners for a surface that is not rounded, such as an image. A view that
/// draws its surface from the same value keeps the surface and the ring in
/// step.
public nonisolated enum SurfaceCorners: Equatable, Sendable {
  /// Corners of a step of the radius scale, for example `.medium` for
  /// `EditorStyle.Radii.m`.
  case rounded(EditorStyle.Radius)

  /// Square corners: the surface and its ring are rectangles.
  case square

  /// The corners of a card: the large radius of the scale, the least corner
  /// of `.inlineEdge(radius:)` on a card.
  public static let card = SurfaceCorners.rounded(.large)

  /// The corner radius in `style`.
  ///
  /// - Parameter style: The shared style that gives the radius scale.
  /// - Returns: The radius of the step, or zero for square corners.
  public func radius(in style: EditorStyle) -> CGFloat {
    switch self {
    case .rounded(let step): style.radii[step]
    case .square: .zero
    }
  }
}

extension View {
  /// Puts this item on the shared selection surface of EditorKit when it is
  /// selected, and gives it a hit and focus shape with the same corners.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - radius: The radius step of the surface, from the radius scale of
  ///     `\.editorStyle`.
  /// - Returns: The item on its selectable surface.
  public func selectableSurface(_ isSelected: Bool, radius: EditorStyle.Radius) -> some View {
    selectableSurface(isSelected, corners: .rounded(radius))
  }

  /// Puts this item on the shared selection surface of EditorKit when it is
  /// selected, and gives it a hit and focus shape with the same corners.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - corners: The corners of the surface, the corners that the focus
  ///     ring of the item follows.
  /// - Returns: The item on its selectable surface.
  public func selectableSurface(_ isSelected: Bool, corners: SurfaceCorners) -> some View {
    modifier(SelectableSurface(isSelected: isSelected, corners: corners))
  }
}

/// The surface of an item that the user selects: the shared selection
/// surface of EditorKit (`.selectionSurface(_:cornerRadius:)`), and the
/// content shape of the item for a click and for the focus effect, in the
/// surface shape of the same corner radius (card ^dn1m56r).
///
/// The surface and the shape read one radius, so a click lands where the
/// selection shows, and a focus ring that the system draws on the item
/// follows the corners of the selection. Each selection of a view kit draws
/// through this modifier, so no view pairs the two itself.
///
/// The surface reads the corners as a radius, as the ring of an item scope
/// does (`.scopeFocusRing(cornerRadius:)`). When the corners of an item
/// change, only the value of the radius changes, so the item keeps its
/// identity and its state.
public struct SelectableSurface: ViewModifier {
  /// Whether the item is selected.
  let isSelected: Bool

  /// The corners of the surface.
  let corners: SurfaceCorners

  @Environment(\.editorStyle) private var editorStyle

  /// Makes the selectable surface of an item.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - corners: The corners of the surface.
  public init(isSelected: Bool, corners: SurfaceCorners) {
    self.isSelected = isSelected
    self.corners = corners
  }

  /// Puts `content` on the selection surface, with its hit and focus shape.
  ///
  /// - Parameter content: The item.
  /// - Returns: The item on its selectable surface.
  public func body(content: Content) -> some View {
    let radius = corners.radius(in: editorStyle)
    content
      .selectionSurface(isSelected, cornerRadius: radius)
      .contentShape([.interaction, .focusEffect], EditorSurface.shape(radius: radius))
  }
}

#Preview("A selected and an unselected surface") {
  HStack {
    ForEach([true, false], id: \.self) { isSelected in
      Text(StylePreviewFixtures.fileName)
        .padding(EditorStyle.default.spacing.s)
        .selectableSurface(isSelected, corners: .card)
    }
  }
  .padding()
}
