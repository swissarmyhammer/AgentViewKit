import EditorStyle
import SwiftUI

/// The place of a ``StatusBar``, or of another note or card: in content, or
/// floating over content that scrolls under it (TestudoApp D213).
///
/// The rule of D213 applies to each note that floats over content that
/// scrolls under it, for example the sign-in card of the bottom bar of a
/// thread, not only to a ``StatusBar``. A view that is not a bar gets the
/// surface of its place with
/// ``SwiftUI/View/statusBarPlacementSurface(radius:)``.
///
/// The place is a choice of the view that holds the bar, not of the bar. A
/// view sets it with ``SwiftUI/View/statusBarPlacement(_:)``. With no place
/// in the environment, a bar is ``content``.
public enum StatusBarPlacement: Equatable, Sendable {
  /// A bar in content, such as a status text in a list or an inspector, or
  /// a bar on the glass of a card. The bar has no fill and no glass, and a
  /// separator stroke marks its edge.
  case content

  /// A note that floats over content that scrolls under it, such as a
  /// banner of the top bar or of the bottom bar of a thread. The bar is on
  /// the floating glass of the kit, the glass of the status line, so the
  /// text under it does not show through.
  case floating
}

extension EnvironmentValues {
  /// The place of each ``StatusBar`` in this view. The default is
  /// ``StatusBarPlacement/content``.
  @Entry var statusBarPlacement = StatusBarPlacement.content
}

extension View {
  /// Sets the place of each ``StatusBar`` in this view.
  ///
  /// A host that shows its own notes over a transcript, such as the notices
  /// of an app above the composer, gives them ``StatusBarPlacement/floating``,
  /// so they have the look of the banners of the kit. Put the notes in the
  /// `FloatingGlassContainer` of the composer or of the status line where
  /// they touch, so their glass blends with that glass.
  ///
  /// - Parameter placement: The place of the bars.
  /// - Returns: A view whose bars show in `placement`.
  public func statusBarPlacement(_ placement: StatusBarPlacement) -> some View {
    environment(\.statusBarPlacement, placement)
  }

  /// Gives this view the surface of the ``StatusBarPlacement`` of the
  /// environment, the surface of a ``StatusBar`` in the same place.
  ///
  /// - In content, a separator stroke marks the edge of the view
  ///   (`.inlineEdge(radius:)`, D113), and the view has no fill and no glass.
  /// - A floating view is on the floating glass of the kit
  ///   (`.floatingGlass()` of EditorStyle), the glass of the status line, so
  ///   the text under it does not show through it. The glass has no
  ///   separator stroke. Under Reduce Transparency, the system gives the
  ///   glass an opaque background. The buttons of the view stand on that
  ///   glass (`.editorButtonSurface(.glass)`), so they take the bordered
  ///   style, and no glass stands on glass (EditorKit `style.md`, rule 4).
  ///
  /// Use it on a note or a card that is not a ``StatusBar``, such as a
  /// sign-in card, so that it has the look of a bar in the same place. Put a
  /// floating view in the `FloatingGlassContainer` of the composer or of the
  /// status line where they touch, so its glass blends with that glass.
  ///
  /// - Parameter radius: The least corner radius of the edge in content. The
  ///   floating glass takes the large radius of the style.
  /// - Returns: The view on the surface of its place.
  public func statusBarPlacementSurface(radius: CGFloat) -> some View {
    modifier(StatusBarPlacementSurface(radius: radius))
  }
}

/// The surface of a view in the ``StatusBarPlacement`` of the environment:
/// the separator edge in content, and the floating glass of the kit for a
/// floating note.
private struct StatusBarPlacementSurface: ViewModifier {
  /// The least corner radius of the edge in content.
  let radius: CGFloat

  /// The place of the view, which gives its surface.
  @Environment(\.statusBarPlacement) private var placement

  func body(content: Content) -> some View {
    switch placement {
    case .content:
      content.inlineEdge(radius: radius)
    case .floating:
      // The buttons stand on the glass of the note, so they take the
      // bordered style, and no glass stands on glass (EditorKit `style.md`,
      // rule 4). This surface is inside the surface that a view declares
      // around the note, so it wins.
      content
        .editorButtonSurface(.glass)
        .floatingGlass()
    }
  }
}
