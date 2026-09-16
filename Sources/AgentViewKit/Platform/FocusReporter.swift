import SwiftUI

/// The object that the pending-request host tells when it moves the focus.
///
/// A permission card or an elicitation form takes the focus when it appears
/// (plan.md §6). The host calls ``focusMoved(to:)`` with the accessibility
/// identifier of the view that gets the focus, so that a test can record each
/// move.
public protocol FocusReporter: AnyObject {
  /// Records that the focus moved to the view with `identifier`.
  ///
  /// - Parameter identifier: The accessibility identifier of the view that
  ///   has the focus now, such as `elicitation-form`.
  func focusMoved(to identifier: String)
}

extension EnvironmentValues {
  /// The reporter that a view of the kit tells when it takes the focus.
  ///
  /// The value is `nil` until a host or a test sets a reporter. A view with
  /// no reporter moves the focus and tells nobody.
  @Entry public var focusReporter: (any FocusReporter)? = nil
}
