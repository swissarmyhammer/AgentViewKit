import SwiftUI

/// The keyboard focus of a request card: a ``PermissionView``, an
/// ``ElicitationView`` or an ``ElicitationURLConsentView``.
///
/// The card is a focusable view, so a jump, a move or the Tab key lands the
/// focus on the card, and Esc reaches its `onExitCommand`. The card shows
/// that focus as the focus fill of its selectable surface, never as an
/// outline (EditorKit style.md, "Selection and focus"), and the system focus
/// effect stays off (Docs/decisions/focus-audit.md). In a ``RequestDeck``
/// (`\.requestFrameIsExternal`), the deck draws the fill at the frame of the
/// card, and the card gives its focus to the deck with
/// ``RequestCardFocusKey``.
struct RequestCardFocus: ViewModifier {
  /// Whether the card takes the focus when its window first gives the focus.
  let takesDefaultFocus: Bool

  /// Whether the card holds the keyboard focus.
  @FocusState private var isFocused: Bool

  @Environment(\.requestFrameIsExternal) private var frameIsExternal

  @ViewBuilder func body(content: Content) -> some View {
    let card = content
      .modifier(RequestCardFocusFill(isDrawn: !frameIsExternal, isFocused: isFocused))
      .focusable()
      .focusEffectDisabled()
      .preference(key: RequestCardFocusKey.self, value: isFocused)
      .focused($isFocused)
    // The value is the same for each body of one card, so the card keeps its
    // identity.
    if takesDefaultFocus {
      card.defaultFocus($isFocused, true)
    } else {
      card
    }
  }
}

/// The focus fill of a request card that draws its own surface: a selectable
/// surface in the corners of a card that is never selected.
private struct RequestCardFocusFill: ViewModifier {
  /// Whether the card draws its fill.
  let isDrawn: Bool

  /// Whether the card holds the keyboard focus.
  let isFocused: Bool

  @ViewBuilder func body(content: Content) -> some View {
    if isDrawn {
      content.selectableSurface(false, isFocused: isFocused, corners: .card)
    } else {
      content
    }
  }
}

/// Whether a request card holds the keyboard focus, for a host that draws the
/// focus fill at a frame that can be taller than the card (``RequestDeck``).
struct RequestCardFocusKey: PreferenceKey {
  /// No card holds the focus.
  static let defaultValue = false

  /// One card with the focus is enough.
  static func reduce(value: inout Bool, nextValue: () -> Bool) {
    value = value || nextValue()
  }
}

extension View {
  /// Makes this request card focusable, with the focus fill of its surface
  /// and no system focus effect (``RequestCardFocus``).
  ///
  /// - Parameter takesDefaultFocus: `true` when the card takes the focus
  ///   when its window first gives the focus, as a permission card does.
  /// - Returns: The focusable card.
  func requestCardFocus(takesDefaultFocus: Bool = false) -> some View {
    modifier(RequestCardFocus(takesDefaultFocus: takesDefaultFocus))
  }
}

extension EnvironmentValues {
  /// Whether the host of a request card draws its edge and its focus fill,
  /// so the card draws neither. A ``RequestDeck`` draws both at the frame of
  /// each card: a card can be shorter than the frame of the deck, and a second
  /// edge and a second fill would show inside the first.
  @Entry var requestFrameIsExternal: Bool = false
}
