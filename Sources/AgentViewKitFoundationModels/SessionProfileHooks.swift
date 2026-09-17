import Foundation
import FoundationModels

/// The host times of one transcript entry or one tool call.
public struct SessionActivityTimes: Equatable, Sendable {
  /// The time when the entry or the call started.
  public var startedAt: Date

  /// The time when the entry or the call ended, or `nil` while it runs.
  public var endedAt: Date?

  /// Makes host times.
  ///
  /// - Parameters:
  ///   - startedAt: The time when the entry or the call started.
  ///   - endedAt: The time when the entry or the call ended.
  public init(startedAt: Date, endedAt: Date? = nil) {
    self.startedAt = startedAt
    self.endedAt = endedAt
  }
}

/// Stamps host times from the `DynamicProfile` hooks of a session
/// (plan.md §3.3).
///
/// The SDK gives no times. Make one hooks object before the session, add the
/// hooks to the profile with ``install(on:)``, make the session with that
/// profile, and then give the hooks to
/// ``SessionThreadSource/init(session:thread:catalog:contextWindow:clock:hooks:)``.
/// Without hooks, the source stamps the time when it observes each entry.
///
/// The session calls each hook after the matching entry is complete, and it
/// waits for the hook:
///
/// - `.onPrompt` stamps the prompt. The next entry starts at this time.
/// - `.onReasoning` and `.onResponse` stamp an entry that started at the end
///   of the entry before it, and ends now.
/// - `.onToolCall` stamps the start of a call. The tool runs after the hook.
/// - `.onToolOutput` stamps the end of the call. The next model call starts
///   at this time.
///
/// The source copies the times to the reasoning and tool call records. The
/// activity timeline (plan.md §9 C) reads the same records, and can read the
/// times of the other entries with ``times(for:)``.
public final class SessionProfileHooks {
  /// The host clock.
  private let clock: () -> Date

  /// The times of each entry and each tool call, keyed by id.
  private var activityTimes: [String: SessionActivityTimes] = [:]

  /// The end time of the last complete entry, or `nil` before the first
  /// hook.
  private var lastEndedAt: Date?

  /// The source that shows the times, or `nil` when no source uses the
  /// hooks.
  weak var source: SessionThreadSource?

  /// Makes hooks.
  ///
  /// - Parameter clock: The host clock for the times.
  public init(clock: @escaping () -> Date = Date.init) {
    self.clock = clock
  }

  /// The host times of an entry or a tool call.
  ///
  /// - Parameter id: The id of the transcript entry, or of the tool call.
  /// - Returns: The times, or `nil` when no hook stamped the id.
  public func times(for id: String) -> SessionActivityTimes? {
    activityTimes[id]
  }

  /// Adds the timestamp hooks to a profile.
  ///
  /// Build the profile outside the main actor, because the session takes it
  /// as a `sending` value.
  ///
  /// - Parameter profile: The profile of the host.
  /// - Returns: The profile with the `.onPrompt`, `.onReasoning`,
  ///   `.onResponse`, `.onToolCall`, and `.onToolOutput` hooks.
  nonisolated public func install(
    on profile: some LanguageModelSession.DynamicProfile
  ) -> some LanguageModelSession.DynamicProfile {
    profile
      .onPrompt { prompt in
        await self.recordInstant(id: prompt.id)
      }
      .onReasoning { reasoning in
        await self.recordEntry(id: reasoning.id)
      }
      .onResponse { response in
        await self.recordEntry(id: response.id)
      }
      .onToolCall { call in
        await self.recordCallStart(id: call.id)
      }
      .onToolOutput { call, _ in
        await self.recordCallEnd(id: call.id)
      }
  }

  // MARK: - Records

  /// Stamps an entry that starts and ends now, such as a prompt.
  ///
  /// - Parameter id: The id of the entry.
  private func recordInstant(id: String) {
    let now = clock()
    record(SessionActivityTimes(startedAt: now, endedAt: now), for: id)
  }

  /// Stamps an entry that started at the end of the entry before it, and
  /// ends now.
  ///
  /// - Parameter id: The id of the entry.
  private func recordEntry(id: String) {
    let now = clock()
    record(SessionActivityTimes(startedAt: lastEndedAt ?? now, endedAt: now), for: id)
  }

  /// Stamps the start of a tool call.
  ///
  /// - Parameter id: The id of the call.
  private func recordCallStart(id: String) {
    activityTimes[id] = SessionActivityTimes(startedAt: clock())
    source?.showHookTimes(id: id)
  }

  /// Stamps the end of a tool call.
  ///
  /// - Parameter id: The id of the call.
  private func recordCallEnd(id: String) {
    let now = clock()
    let startedAt = activityTimes[id]?.startedAt ?? now
    record(SessionActivityTimes(startedAt: startedAt, endedAt: now), for: id)
  }

  /// Keeps complete times, moves the end of the last entry, and tells the
  /// source.
  ///
  /// - Parameters:
  ///   - times: The times.
  ///   - id: The id of the entry or the call.
  private func record(_ times: SessionActivityTimes, for id: String) {
    activityTimes[id] = times
    lastEndedAt = times.endedAt
    source?.showHookTimes(id: id)
  }
}
