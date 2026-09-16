import Foundation

/// Reads ISO 8601 times, such as the RFC 3339 times of ACP and of
/// elicitation answers.
public nonisolated enum ISO8601Time {
  /// Reads an ISO 8601 time, with or without fractional seconds.
  ///
  /// - Parameter text: The time text, such as `2026-09-16T10:00:00Z` or
  ///   `2026-09-16T10:00:00.500Z`.
  /// - Returns: The time, or `nil` when the text is not an ISO 8601 time.
  public static func date(from text: String) -> Date? {
    (try? Date.ISO8601FormatStyle().parse(text))
      ?? (try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text))
  }
}
