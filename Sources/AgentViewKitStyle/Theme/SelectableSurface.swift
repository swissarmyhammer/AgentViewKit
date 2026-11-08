import EditorCommandsUI
import EditorStyle
import SwiftUI

/// The corners of a surface of a view kit, which its selection and focus
/// fill, its hit shape and, for a surface that draws no fill, the focus ring
/// of its scope follow.
///
/// The corners name a step of the radius scale of `\.editorStyle`, or square
/// corners for a surface that is not rounded, such as an image. A view that
/// draws its surface from the same value keeps the surface and the ring in
/// step.
public nonisolated enum SurfaceCorners: Equatable, Sendable {
  /// Corners of a step of the radius scale, for example `.medium` for
  /// `EditorStyle.Radii.m`.
  case rounded(EditorStyle.Radius)

  /// Square corners: the surface, its fill and its ring are rectangles.
  case square

  /// The corners of a card: the large radius of the scale, the least corner
  /// of `.inlineEdge(radius:)` on a card.
  public static let card = SurfaceCorners.rounded(.large)

  /// The corners of an EditorKit `PathChip`: the medium step of the scale,
  /// the corners of the fill of the chip. A kit that selects a path chip,
  /// or gives it a scope, puts the fill of its selection and its focus in
  /// these corners.
  public static let pathChip = SurfaceCorners.rounded(.medium)

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
  /// Gives this item the look of its selection and its focus, in the surface
  /// shape of a step of the radius scale (EditorKit style.md, "Selection and
  /// focus").
  ///
  /// It is ``selectableSurface(_:corners:)`` with rounded corners. Put it
  /// inside the `.commandScope` of the item.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - radius: The radius step of the surface, from the radius scale of
  ///     `\.editorStyle`.
  /// - Returns: The item with the fill of its state and its hit shape.
  public func selectableSurface(_ isSelected: Bool, radius: EditorStyle.Radius) -> some View {
    selectableSurface(isSelected, corners: .rounded(radius))
  }

  /// Gives this item the look of its selection and its focus, in the surface
  /// shape of its corners (EditorKit style.md, "Selection and focus").
  ///
  /// This is the one way that a view kit gives an item that it draws itself
  /// (a card, a chip, a row, a tile) its selection and its focus. Put it
  /// inside the `.commandScope` of the item:
  ///
  /// ```swift
  /// CardContent(card)
  ///   .selectableSurface(isSelected, corners: .card)
  ///   .commandScope(segment: FocusSegment(kind: "card", id: card.id))
  /// ```
  ///
  /// The item shows a fill in its own shape, never an outline: the soft
  /// accent while it is selected, a stronger accent while its scope holds the
  /// focus, and the inactive grey while the window is not key. The scope then
  /// draws no focus ring. A base fill of the item, such as the fill of a
  /// chip, stands inside this modifier and draws nothing while
  /// `\.isItemStateFillShown` is `true`, so no two fills stack. Outside each
  /// scope, for example in a gallery sample, the item shows its selection
  /// only.
  ///
  /// A part that has no scope of its own inside another item, such as a tab
  /// chip, uses ``selectionSurface(_:corners:)``: this modifier would show the
  /// focus of the scope around it.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - corners: The corners of the surface of the item.
  /// - Returns: The item with the fill of its state and its hit shape.
  public func selectableSurface(_ isSelected: Bool, corners: SurfaceCorners) -> some View {
    modifier(SelectableSurface(isSelected: isSelected, corners: corners))
  }

  /// Gives a focusable item the look of its selection and of the focus that
  /// its host gives, in the surface shape of its corners (EditorKit
  /// style.md, "Selection and focus").
  ///
  /// Use it on an item that takes the keyboard focus itself, for example a
  /// card with `.focusable()` and `.focusEffectDisabled()`. A jump or a move
  /// then gives the focus to the item and not to the beacon of its scope, so
  /// ``selectableSurface(_:corners:)`` would show no focus. Give the focus of
  /// the item from `@FocusState`:
  ///
  /// ```swift
  /// CardContent(card)
  ///   .focusable()
  ///   .focusEffectDisabled()
  ///   .focused($isFocused)
  ///   .selectableSurface(false, isFocused: isFocused, corners: .card)
  /// ```
  ///
  /// The item shows the stronger accent fill while `isFocused` is `true` or
  /// while its scope holds the focus. It shows no focus ring. Each other part
  /// of the look is the look of ``selectableSurface(_:corners:)``.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - isFocused: Whether the item holds the keyboard focus, as its host
  ///     knows it.
  ///   - corners: The corners of the surface of the item.
  /// - Returns: The item with the fill of its state and its hit shape.
  public func selectableSurface(_ isSelected: Bool, isFocused: Bool, corners: SurfaceCorners) -> some View {
    modifier(SelectableSurface(isSelected: isSelected, isFocused: isFocused, corners: corners))
  }

  /// Puts this part on the shared selection surface of EditorKit when it is
  /// selected, and gives it a hit and focus shape with the same corners.
  ///
  /// Use it for a part that has no command scope of its own inside another
  /// item, such as a tab chip of a form or a file chip of a diff. The part
  /// shows its selection only. It does not show the focus of the scope around
  /// it, and it does not take the focus ring from that scope. An item in its
  /// own scope uses ``selectableSurface(_:corners:)``.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the part is selected.
  ///   - corners: The corners of the surface of the part.
  /// - Returns: The part on its selection surface.
  public func selectionSurface(_ isSelected: Bool, corners: SurfaceCorners) -> some View {
    modifier(SelectionPartSurface(isSelected: isSelected, corners: corners))
  }
}

/// The look of the selection and the focus of an item that a view kit draws
/// itself: EditorKit's `.selectableItem(isSelected:isFocused:cornerRadius:)`
/// at the radius of the corners of the item (EditorKit style.md, "Selection
/// and focus").
///
/// The modifier gives the item the fill of its state, its hit and focus
/// shape in the same corners, and tells the enclosing `.commandScope` to draw
/// no focus ring. Thus the fill, the shape and the focus look always agree,
/// and no view of a kit pairs them itself.
///
/// The modifier reads the corners as a radius. When the corners of an item
/// change, only the value of the radius changes, so the item keeps its
/// identity and its state.
public struct SelectableSurface: ViewModifier {
  /// Whether the item is selected.
  let isSelected: Bool

  /// Whether the item holds the keyboard focus, as its host knows it.
  let isFocused: Bool

  /// The corners of the surface.
  let corners: SurfaceCorners

  @Environment(\.editorStyle) private var editorStyle

  /// Makes the look of the selection and the focus of an item.
  ///
  /// - Parameters:
  ///   - isSelected: Whether the item is selected.
  ///   - isFocused: Whether the item holds the keyboard focus itself, as its
  ///     host knows it. The item shows the focused fill while this is `true`
  ///     or while its scope holds the focus.
  ///   - corners: The corners of the surface.
  public init(isSelected: Bool, isFocused: Bool = false, corners: SurfaceCorners) {
    self.isSelected = isSelected
    self.isFocused = isFocused
    self.corners = corners
  }

  /// Gives `content` the fill of its state and its hit and focus shape.
  ///
  /// - Parameter content: The item.
  /// - Returns: The item with the look of its selection and its focus.
  public func body(content: Content) -> some View {
    content.selectableItem(
      isSelected: isSelected, isFocused: isFocused, cornerRadius: corners.radius(in: editorStyle))
  }
}

/// The selection surface of a part with no command scope of its own: the
/// shared selection surface of EditorKit (`.selectionSurface(_:cornerRadius:)`)
/// and the hit and focus shape of the part, in the surface shape of the same
/// corner radius.
///
/// The surface shows no focus and tells no scope about the part, so the scope
/// around the part keeps its own focus look.
private struct SelectionPartSurface: ViewModifier {
  /// Whether the part is selected.
  let isSelected: Bool

  /// The corners of the surface.
  let corners: SurfaceCorners

  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
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
