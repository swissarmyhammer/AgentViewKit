import Foundation

/// The text that VoiceOver reads for a status text: the title and the
/// explanation that a ``StatusTitleLayout`` shows.
///
/// A ``StatusBar`` reads its message with it, and so does each view of the kit
/// that shows a title and an explanation in a ``StatusTitleLayout``. The
/// catalog holds the order and the separator of the two parts, so the code
/// joins no text.
public enum StatusTitleText {
  /// The accessibility label of a status text.
  ///
  /// - Parameters:
  ///   - title: The title.
  ///   - explanation: The explanation, or an empty text for none.
  /// - Returns: The title and the explanation in one localized string, such
  ///   as "Offline, The agent stopped.", or the title alone when the
  ///   explanation is empty.
  public static func label(title: String, explanation: String) -> String {
    guard !explanation.isEmpty else { return title }
    return String(
      localized: "status-title.label", defaultValue: "\(title), \(explanation)", bundle: .module,
      comment: "The VoiceOver label of a status text: its title, then its explanation.")
  }
}
