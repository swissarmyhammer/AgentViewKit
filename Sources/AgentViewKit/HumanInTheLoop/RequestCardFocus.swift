import SwiftUI

/// The keyboard focus of a request card: a ``PermissionView``, an
/// ``ElicitationView`` or an ``ElicitationURLConsentView``.
///
/// The card is a focusable view, so a jump, a move or the Tab key lands the
/// focus on the card, and Esc reaches its `onExitCommand`. The card shows
/// that focus as the one focus background of EditorKit
/// (`EditorFocusIndicatorKind.background`), which its selectable surface
/// draws through EditorKit's `.selectableItem`, never as an outline
/// (EditorKit style.md, "Selection and focus"), and the system focus
/// effect stays off (Docs/decisions/focus-audit.md). In a ``RequestDeck``
/// (`\.requestFrameIsExternal`), the deck draws the fill at the frame of the
/// card, and the card gives its focus to the deck with
/// ``RequestCardFocusKey``.
struct RequestCardFocus: ViewModifier {
  /// Whether the card takes the focus when its window first gives the focus.
  let takesDefaultFocus: Bool

  /// Whether the card holds the keyboard focus.
  @FocusState private var isFocused: Bool

  @ViewBuilder func body(content: Content) -> some View {
    let showsFocus = isFocused
    let card = content
      .requestCardOwnSurface { $0.selectableSurface(false, isFocused: showsFocus, corners: .card) }
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

/// A part of the surface of a request card, such as its edge or its focus
/// fill, that the card draws only when its host does not draw it
/// (`\.requestFrameIsExternal`).
///
/// Each part of the surface that a ``RequestDeck`` draws at the frame of the
/// card goes through this one gate, so the parts cannot disagree about who
/// draws them.
private struct RequestCardOwnSurface<Card: View, Drawn: View>: View {
  /// The card.
  let card: Card

  /// Draws the part of the surface on the card.
  let draw: (Card) -> Drawn

  @Environment(\.requestFrameIsExternal) private var frameIsExternal

  var body: some View {
    // The value is the same for each body of one card, so the card keeps its
    // identity.
    if frameIsExternal {
      card
    } else {
      draw(card)
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

  /// Draws a part of the surface of this request card, such as its edge or
  /// its focus fill, when the host of the card does not draw that part
  /// (``RequestCardOwnSurface``).
  ///
  /// - Parameter draw: Draws the part of the surface on the card.
  /// - Returns: The card, with the part when the card draws its own surface.
  func requestCardOwnSurface(_ draw: @escaping (Self) -> some View) -> some View {
    RequestCardOwnSurface(card: self, draw: draw)
  }
}

extension EnvironmentValues {
  /// Whether the host of a request card draws its edge and its focus fill,
  /// so the card draws neither. A ``RequestDeck`` draws both at the frame of
  /// each card: a card can be shorter than the frame of the deck, and a second
  /// edge and a second fill would show inside the first.
  @Entry var requestFrameIsExternal: Bool = false
}
