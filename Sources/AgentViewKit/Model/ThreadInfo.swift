import Foundation

/// The descriptive data of a thread (plan.md §3.2).
///
/// The fields are the fields of an ACP `session_info_update`.
public nonisolated struct ThreadInfo: Sendable, Hashable {
  /// The title of the thread, or `nil` when the source gives no title.
  public var title: String?

  /// The time of the last change to the thread, or `nil` when the source
  /// gives no time.
  public var updatedAt: Date?

  /// Makes thread info.
  ///
  /// - Parameters:
  ///   - title: The title of the thread, or `nil`.
  ///   - updatedAt: The time of the last change to the thread, or `nil`.
  public init(title: String? = nil, updatedAt: Date? = nil) {
    self.title = title
    self.updatedAt = updatedAt
  }
}
