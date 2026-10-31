import Foundation

/// The text of a failed request of a demo tab.
///
/// The failure label of each tab of the demo app shows this text. An error
/// with a localized description gives that description, so that the user
/// reads the message of the error and not the name of its case. Each other
/// error gives its description.
public enum DemoFailureText {
  /// The text of an error.
  ///
  /// - Parameter error: The error of the request.
  /// - Returns: The `errorDescription` of a `LocalizedError` that has one,
  ///   or the description of the error.
  public static func text(of error: any Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
  }
}
