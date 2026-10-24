import EditorStyle
import SwiftUI

extension View {
  /// Puts this item on the shared selection surface of EditorKit when it is
  /// selected, and gives it a hit and focus shape with the same corners.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - radius: The radius step of the surface, from the radius scale of
  ///     `\.editorStyle`.
  /// - Returns: The item on its selectable surface.
  func selectableSurface(_ isSelected: Bool, radius: EditorStyle.Radius) -> some View {
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
  func selectableSurface(_ isSelected: Bool, corners: AgentSurfaceCorners) -> some View {
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
/// follows the corners of the selection. Each selection of the kit draws
/// through this modifier, so no view pairs the two itself.
///
/// The surface reads the corners as a radius, as the ring of an item scope
/// does (`.scopeFocusRing(cornerRadius:)`). When the corners of an item
/// change, only the value of the radius changes, so the item keeps its
/// identity and its state.
struct SelectableSurface: ViewModifier {
  /// Whether the item is selected.
  let isSelected: Bool

  /// The corners of the surface.
  let corners: AgentSurfaceCorners

  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    let radius = corners.radius(in: editorStyle)
    content
      .selectionSurface(isSelected, cornerRadius: radius)
      .contentShape([.interaction, .focusEffect], EditorSurface.shape(radius: radius))
  }
}
