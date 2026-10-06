import Observation
import Synchronization

/// A flag that an observation change handler sets.
///
/// The change handler is `@Sendable`, so the flag uses a lock.
public nonisolated final class ChangeFlag: Sendable {
  /// The value of the flag, behind a lock.
  private let storage = Mutex(false)

  /// Makes a flag that is not set.
  public init() {}

  /// `true` after ``set()``.
  public var value: Bool { storage.withLock { $0 } }

  /// Sets the flag.
  public func set() {
    storage.withLock { $0 = true }
  }

  /// Makes a flag that is set when a value that `read` reads changes and
  /// `condition` is `true` at that change.
  ///
  /// The change handler runs `condition` one time, before the change is done.
  /// When `condition` gives `false`, the flag stays clear. With no
  /// `condition`, the change sets the flag.
  ///
  /// - Parameters:
  ///   - read: The closure that reads the observed values one time.
  ///   - condition: The closure that tells, at the change, if the flag is set.
  /// - Returns: A flag that is not set yet.
  public static func observing(
    _ read: () -> Void,
    when condition: @escaping @Sendable () -> Bool = { true }
  ) -> ChangeFlag {
    let flag = ChangeFlag()
    withObservationTracking(read) {
      if condition() { flag.set() }
    }
    return flag
  }
}
