import SwiftUI

/// The host closures that the buttons of an ``ErrorView`` call (plan.md §9 A2).
///
/// Each closure is optional. When a closure is `nil`, the view does not show
/// its button. Set the actions with ``SwiftUI/View/errorActions(_:)``.
public struct ErrorActions {
  /// A closure that gets the error of the card on which the user tapped the
  /// button.
  public typealias Handler = @MainActor (ThreadError) -> Void

  /// The closure that lets the user change the request, or `nil` for no
  /// Rephrase button.
  public var rephrase: Handler?

  /// Makes a set of error actions.
  ///
  /// - Parameter rephrase: The closure that lets the user change the request.
  public init(rephrase: Handler? = nil) {
    self.rephrase = rephrase
  }

  /// The closure of `action`.
  ///
  /// - Parameter action: A button of the error card.
  /// - Returns: The closure, or `nil` when the host did not give it.
  public func handler(for action: ErrorView.Action) -> Handler? {
    switch action {
    case .rephrase: rephrase
    }
  }
}

extension EnvironmentValues {
  /// The error actions that the error cards of this subtree call.
  ///
  /// The default has no closures, so an error card shows no button.
  @Entry public var errorActions = ErrorActions()
}

extension View {
  /// Sets the error actions that the error cards of this subtree call.
  ///
  /// - Parameter actions: The host closures.
  /// - Returns: A view that gives the actions to its subtree.
  public func errorActions(_ actions: ErrorActions) -> some View {
    environment(\.errorActions, actions)
  }
}
