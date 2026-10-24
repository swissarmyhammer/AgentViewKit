import EditorStyle
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
  /// `features/style.md`, rule 4 and "Buttons on glass").
  ///
  /// - In the bar, the button is on the glass of the request deck, and a
  ///   glass button there is glass on glass. Thus the primary action uses the
  ///   `.borderedProminent` style, and each other action uses the `.bordered`
  ///   style. Only a button on a glass surface uses a bordered style.
  /// - In a bar with no glass surface, for example the state banner and the
  ///   login prompt in the bottom bar of a thread, the content scrolls under
  ///   the buttons. Thus the primary action uses the `.glassProminent` style,
  ///   and each other action, the standard action too, uses the `.glass`
  ///   style.
  /// - In content, the primary action uses the `.glassProminent` style, a
  ///   secondary action uses the `.glass` style, and a standard action keeps
  ///   the style of its environment.
  ///
  /// - Parameter action: The kind of the action.
  /// - Returns: The button style of the action.
  func style(of action: RequestAction) -> RequestActionStyle {
    switch (self, action) {
    case (.bar, .primary): .borderedProminent
    case (.bar, .secondary), (.bar, .standard): .bordered
    case (.barWithoutGlass, .primary), (.content, .primary): .glassProminent
    case (.barWithoutGlass, .secondary), (.barWithoutGlass, .standard), (.content, .secondary): .glass
    case (.content, .standard): .inherited
    }
  }
}

/// Gives a button the style of its ``RequestAction`` in its place. The place
/// is the ``SwiftUI/EnvironmentValues/requestActionPlace`` that a view above
/// the button declares, or else the place from the glass namespace of the
/// `FloatingGlassContainer` above the button (`\.floatingGlassNamespace`,
/// ``RequestDeckPlace/init(declared:isInFloatingGlassContainer:)``).
private struct RequestActionStyleModifier: ViewModifier {
  /// The kind of the action.
  let action: RequestAction

  @Environment(\.requestActionPlace) private var declaredPlace
  /// The glass namespace of the `FloatingGlassContainer` above the button,
  /// or `nil` out of a container.
  @Environment(\.floatingGlassNamespace) private var glassNamespace

  func body(content: Content) -> some View {
    let place = RequestDeckPlace(declared: declaredPlace, isInFloatingGlassContainer: glassNamespace != nil)
    switch place.style(of: action) {
    case .glass: content.buttonStyle(.glass)
    case .glassProminent: content.buttonStyle(.glassProminent)
    case .bordered: content.buttonStyle(.bordered)
    case .borderedProminent: content.buttonStyle(.borderedProminent)
    case .inherited: content
    }
  }
}

extension EnvironmentValues {
  /// The place of the action buttons below this view, which a view declares
  /// with ``SwiftUI/View/requestActionPlace(_:)``, or `nil` when no view above
  /// declares a place. With `nil`, the place of the buttons comes from
  /// ``floatingGlassNamespace``: whether a `FloatingGlassContainer` is above
  /// them.
  @Entry var requestActionPlace: RequestDeckPlace? = nil
}

extension View {
  /// Gives the button in this view the style of `action` in its place
  /// (``RequestDeckPlace/style(of:)``).
  ///
  /// - Parameter action: The kind of the action.
  /// - Returns: The view with the button style.
  func requestActionStyle(_ action: RequestAction) -> some View {
    modifier(RequestActionStyleModifier(action: action))
  }

  /// Declares the place of the action buttons in this view
  /// (``SwiftUI/EnvironmentValues/requestActionPlace``).
  ///
  /// A view in a bar with no glass surface declares
  /// ``RequestDeckPlace/barWithoutGlass``. It can be in the glass container
  /// of the bar, but its buttons are not on glass, so they keep the glass
  /// styles (TestudoApp `features/style.md`, rule 4).
  ///
  /// - Parameter place: The place of the buttons.
  /// - Returns: The view with the place in its environment.
  func requestActionPlace(_ place: RequestDeckPlace) -> some View {
    environment(\.requestActionPlace, place)
  }
}
