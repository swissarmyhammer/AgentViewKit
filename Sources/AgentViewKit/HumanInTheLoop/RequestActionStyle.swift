import SwiftUI

/// An action button of a request card, the Dismiss button of a notice in a
/// ``RequestDeck``, the button of a ``StatusBar``, or an action button of an
/// ``AgentAuthView``. The kind of the action and the ``RequestDeckPlace``
/// give its button style (``RequestDeckPlace/style(of:)``).
nonisolated enum RequestAction: Equatable, Sendable {
  /// The one primary action of the card, for example Allow once.
  case primary

  /// An action that is not primary. In content, it uses the `.glass` style.
  case secondary

  /// An action that is not primary and that has no button style of its own
  /// in content, for example Cancel and Decline of an elicitation card.
  case standard
}

/// The button style of a ``RequestAction``.
nonisolated enum RequestActionStyle: Equatable, Sendable {
  /// The `.glass` style.
  case glass

  /// The `.glassProminent` style.
  case glassProminent

  /// The `.bordered` style.
  case bordered

  /// The `.borderedProminent` style.
  case borderedProminent

  /// No style of its own: the button keeps the button style of its
  /// environment, by default the system style.
  case inherited
}

extension RequestDeckPlace {
  /// The button style of `action` in this place (TestudoApp
  /// `features/style.md`, "Buttons on glass").
  ///
  /// In the bar, the deck is on glass, and a glass button on it is glass on
  /// glass. Thus the primary action uses the `.borderedProminent` style, and
  /// each other action uses the `.bordered` style. A status bar and the login
  /// card in the bottom bar of a thread have no glass, but a bar has standard
  /// controls (TestudoApp `features/style.md`, "Bars of a view"). Thus their
  /// buttons use the same bordered styles there. In content, the primary
  /// action uses the `.glassProminent` style, a secondary action uses the
  /// `.glass` style, and a standard action keeps the style of its
  /// environment.
  ///
  /// - Parameter action: The kind of the action.
  /// - Returns: The button style of the action.
  func style(of action: RequestAction) -> RequestActionStyle {
    switch (self, action) {
    case (.bar, .primary): .borderedProminent
    case (.bar, .secondary), (.bar, .standard): .bordered
    case (.content, .primary): .glassProminent
    case (.content, .secondary): .glass
    case (.content, .standard): .inherited
    }
  }
}

/// Gives a button the style of its ``RequestAction`` in the place of the
/// deck, which the modifier reads from
/// ``SwiftUI/EnvironmentValues/floatingGlassContainerCount``.
private struct RequestActionStyleModifier: ViewModifier {
  /// The kind of the action.
  let action: RequestAction

  @Environment(\.floatingGlassContainerCount) private var containerCount

  func body(content: Content) -> some View {
    switch RequestDeckPlace(floatingGlassContainerCount: containerCount).style(of: action) {
    case .glass: content.buttonStyle(.glass)
    case .glassProminent: content.buttonStyle(.glassProminent)
    case .bordered: content.buttonStyle(.bordered)
    case .borderedProminent: content.buttonStyle(.borderedProminent)
    case .inherited: content
    }
  }
}

extension View {
  /// Gives the button in this view the style of `action` in the place of the
  /// request deck (``RequestDeckPlace/style(of:)``).
  ///
  /// - Parameter action: The kind of the action.
  /// - Returns: The view with the button style.
  func requestActionStyle(_ action: RequestAction) -> some View {
    modifier(RequestActionStyleModifier(action: action))
  }
}
