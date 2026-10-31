import EditorStyle
import SwiftUI

// PlacedSecondary — the secondary text of a view that shows on glass and in content.
//
// The secondary text of content is `\.themeSecondary`, and on glass and chrome the vibrant
// `.secondary` stays: never `\.themeSecondary` there (`style.md`, rule 6). A request card, a chip
// or a status text can show in the two places, so it reads its style from its place. A view that
// shows only in content reads `\.themeSecondary` itself.

extension EnvironmentValues {
  /// Whether the views below stand on chrome: a bar, a sidebar or a sheet, with no
  /// `FloatingGlassContainer` above them to say so. Set it with ``SwiftUI/View/onChrome()``.
  @Entry public var isOnChrome = false

  /// Whether text here stands on glass or chrome, and so keeps the vibrant styles.
  ///
  /// It does on chrome (``isOnChrome``) and in a `FloatingGlassContainer`, which holds the floating
  /// controls of a bar. Everywhere else the text is content.
  public var showsVibrantText: Bool {
    isOnChrome || floatingGlassNamespace != nil
  }

  /// The secondary text style of this place: `.secondary` on glass and chrome
  /// (``showsVibrantText``), and `\.themeSecondary` in content.
  public var placedSecondary: AnyShapeStyle {
    showsVibrantText ? AnyShapeStyle(HierarchicalShapeStyle.secondary) : AnyShapeStyle(themeSecondary)
  }
}

extension View {
  /// Says that the views below stand on chrome, so ``SwiftUI/EnvironmentValues/placedSecondary``
  /// gives them the vibrant `.secondary`.
  ///
  /// - Returns: The view with the place in its environment.
  public func onChrome() -> some View {
    environment(\.isOnChrome, true)
  }
}
