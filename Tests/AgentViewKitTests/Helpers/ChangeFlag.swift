import Observation
import Synchronization

/// A flag that an observation change handler sets.
///
/// The change handler is `@Sendable`, so the flag uses a lock.
nonisolated final class ChangeFlag: Sendable {
  private let storage = Mutex(false)

  /// `true` after ``set()``.
  var value: Bool { storage.withLock { $0 } }

  /// Sets the flag.
  func set() {
    storage.withLock { $0 = true }
  }

  /// Makes a flag that is set when a value that `read` reads changes.
  ///
  /// - Parameter read: The closure that reads the observed values one time.
  /// - Returns: A flag that is not set yet.
  static func observing(_ read: () -> Void) -> ChangeFlag {
    let flag = ChangeFlag()
    withObservationTracking(read) { flag.set() }
    return flag
  }
}
