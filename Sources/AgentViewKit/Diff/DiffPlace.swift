import SwiftUI

/// The place of a ``DiffView``, which gives whether the diff is a content
/// tile of its own (card ^tgjr9xg).
///
/// On its own, a diff is a content tile: `.contentTile()` pads its chips and
/// its detail. In the expanded body of a ``ToolCallView``, the call is the
/// tile. A second tile there would indent the chips and the detail past the
/// other blocks of the body, so the diff pads nothing: its chips and its
/// detail start on the leading edge of the body, and the body puts the tile
/// gap of `\.editorStyle` between the diff and its other blocks.
nonisolated enum DiffPlace: Equatable, Sendable {
  /// On its own in content: the diff is a content tile.
  case standalone

  /// In the expanded body of a tool call: the call is the tile.
  case toolCall
}

extension EnvironmentValues {
  /// The place of each ``DiffView`` in this view. The value is
  /// ``DiffPlace/standalone`` until a view sets a place with
  /// ``SwiftUI/View/diffPlace(_:)``. ``ToolCallView`` sets
  /// ``DiffPlace/toolCall`` for its expanded body, so a diff of a registered
  /// tool view sits in the call as the default body's diff does.
  @Entry var diffPlace: DiffPlace = .standalone
}

extension View {
  /// Sets the place of each ``DiffView`` in this view.
  ///
  /// - Parameter place: The place of the diffs.
  /// - Returns: The view with the place in its environment.
  func diffPlace(_ place: DiffPlace) -> some View {
    environment(\.diffPlace, place)
  }
}

/// The tile of a ``DiffView`` in its place (``DiffPlace``): the tile padding
/// of `.contentTile()` on its own, and no padding in a tool call.
struct DiffPlaceTile: ViewModifier {
  @Environment(\.diffPlace) private var place

  func body(content: Content) -> some View {
    switch place {
    case .standalone: content.contentTile()
    case .toolCall: content
    }
  }
}
