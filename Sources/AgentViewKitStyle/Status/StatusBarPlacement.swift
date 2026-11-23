import SwiftUI

/// The place of a ``StatusBar``: in content, or floating over content that
/// scrolls under it (TestudoApp D213).
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
}
