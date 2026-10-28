import SwiftUI

/// The body function of a style protocol of the library, such as
/// ``StatusBarActionStyle``, behind one type, so that the environment holds
/// any style of that protocol.
///
/// A style protocol mirrors `ButtonStyle`: it makes a view from a
/// configuration. The environment cannot hold a value of a protocol with an
/// associated type, so it holds the body function of the style, with the
/// body behind `AnyView`, as the jump label style of EditorKit does.
struct ErasedStyle<Configuration> {
  /// The body function of the style, with the body behind `AnyView`.
  private let makeBodyClosure: @MainActor (Configuration) -> AnyView

  /// Wraps the body function of a style.
  ///
  /// - Parameter makeBody: The body function of the style, such as
  ///   `style.makeBody(configuration:)`.
  init(_ makeBody: @escaping @MainActor (Configuration) -> some View) {
    makeBodyClosure = { configuration in AnyView(makeBody(configuration)) }
  }

  /// Makes the view of the style for `configuration`.
  ///
  /// - Parameter configuration: The configuration of the view.
  /// - Returns: The view of the style.
  func makeBody(configuration: Configuration) -> AnyView {
    makeBodyClosure(configuration)
  }
}
