import Accessibility
import SwiftUI

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

/// The default ``Announcer``: it posts an
/// `AccessibilityNotification.Announcement`.
///
/// The announcer keeps no state. The priority goes into the
/// `accessibilitySpeechAnnouncementPriority` attribute of the text.
public final class VoiceOverAnnouncer: Announcer {
  /// Makes the announcer.
  public init() {}

  /// The speech priority of `priority`.
  ///
  /// - Parameter priority: The priority of the announcement.
  /// - Returns: The matching speech announcement priority.
  static func speechPriority(
    of priority: AnnouncementPriority
  ) -> AttributeScopes.AccessibilityAttributes.AnnouncementPriorityAttribute.Value {
    switch priority {
    case .low: .low
    case .medium: .default
    case .high: .high
    }
  }

  /// Posts `message` as a VoiceOver announcement at `priority`.
  ///
  /// - Parameters:
  ///   - message: The text to speak.
  ///   - priority: How urgent the announcement is.
  public func announce(_ message: String, priority: AnnouncementPriority) {
    var text = AttributedString(message)
    text.accessibilitySpeechAnnouncementPriority = Self.speechPriority(of: priority)
    AccessibilityNotification.Announcement(text).post()
  }
}

extension EnvironmentValues {
  /// The announcer that the kit tells at each announcement boundary.
  ///
  /// The value is a ``VoiceOverAnnouncer`` until a host or a test sets a
  /// different announcer.
  @Entry public var announcer: any Announcer = VoiceOverAnnouncer()
}
