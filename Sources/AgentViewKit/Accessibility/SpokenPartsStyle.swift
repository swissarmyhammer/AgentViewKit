import Foundation

extension FormatStyle where Self == ListFormatStyle<StringStyle, [String]> {
  /// The format of the parts of a label that names several facts or names in
  /// a row, such as "Reviewer, In progress, 1 open question": the narrow list
  /// of `locale`.
  ///
  /// The list format holds the separators of the parts, so the code joins no
  /// text. A label of a varying number of parts formats them with this style.
  ///
  /// - Parameter locale: The locale of the label.
  /// - Returns: The narrow list format of `locale`.
  static func spokenParts(locale: Locale) -> Self {
    .list(type: .and, width: .narrow).locale(locale)
  }
}
