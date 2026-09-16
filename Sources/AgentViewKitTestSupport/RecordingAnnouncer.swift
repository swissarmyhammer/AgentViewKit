import AgentViewKit

/// An ``Announcer`` that records each announcement and speaks nothing.
public final class RecordingAnnouncer: Announcer {
  /// One recorded announcement.
  public struct Announcement: Equatable, Sendable {
    /// The text to speak.
    public let message: String
    /// The priority of the announcement.
    public let priority: AnnouncementPriority

    /// Makes an announcement record.
    ///
    /// - Parameters:
    ///   - message: The text to speak.
    ///   - priority: The priority of the announcement.
    public init(message: String, priority: AnnouncementPriority) {
      self.message = message
      self.priority = priority
    }
  }

  /// Each announcement, in call order.
  public private(set) var announcements: [Announcement] = []

  /// Makes an announcer with no announcements.
  public init() {}

  /// Records `message` at `priority`.
  ///
  /// - Parameters:
  ///   - message: The text to speak.
  ///   - priority: The priority of the announcement.
  public func announce(_ message: String, priority: AnnouncementPriority) {
    announcements.append(Announcement(message: message, priority: priority))
  }

  /// Removes each recorded announcement.
  public func reset() {
    announcements.removeAll()
  }
}
