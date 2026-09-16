/// The priority of a VoiceOver announcement.
///
/// The cases have the same order as `NSAccessibilityPriorityLevel`.
public enum AnnouncementPriority: Sendable, Equatable, CaseIterable {
  /// The announcement can wait for other speech.
  case low
  /// The announcement is spoken after the current speech.
  case medium
  /// The announcement interrupts the current speech.
  case high
}

/// The object that speaks a VoiceOver announcement (plan.md §6).
///
/// The kit streams text silently and announces only at boundaries: turn
/// complete, tool result, and action required. The accessibility views call
/// an `Announcer` at those boundaries, so that a test can record the
/// announcements.
public protocol Announcer: AnyObject {
  /// Speaks `message` at `priority`.
  ///
  /// - Parameters:
  ///   - message: The text to speak.
  ///   - priority: How urgent the announcement is.
  func announce(_ message: String, priority: AnnouncementPriority)
}
