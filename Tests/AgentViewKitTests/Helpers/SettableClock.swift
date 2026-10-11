import Foundation
import Synchronization

/// A wall clock that a test sets, for the `now` parameter of a
/// `ConnectionModel`.
///
/// The client model reads the clock each time that it writes the start time
/// or the end time of a transcript entry. A test moves the clock between two
/// updates, so that each entry gets a known time.
///
/// The model reads the clock through a `@Sendable` closure, so the time is
/// behind a lock.
nonisolated final class SettableClock: Sendable {
  /// The current time of the clock, behind a lock.
  private let storage: Mutex<Date>

  /// Makes a clock that shows `start`.
  ///
  /// - Parameter start: The first time of the clock.
  init(start: Date) {
    storage = Mutex(start)
  }

  /// The current time of the clock.
  var date: Date {
    storage.withLock { $0 }
  }

  /// The closure that the connection model calls to read the clock.
  var now: @Sendable () -> Date {
    { self.date }
  }

  /// Moves the clock forward.
  ///
  /// - Parameter seconds: The time to add, in seconds.
  func advance(by seconds: TimeInterval) {
    storage.withLock { $0 = $0.addingTimeInterval(seconds) }
  }
}
