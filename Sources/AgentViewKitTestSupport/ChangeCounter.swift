import Observation

/// Counts the changes of the observed values that a closure reads.
///
/// After each change, the counter reads the values again and observes them
/// again, in a new main actor task. As in SwiftUI, the changes before that
/// read count as one change. ``ChangeFlag`` tells only whether one change
/// came.
///
/// The benchmark package compiles this file through a symbolic link
/// (`Benchmarks/README.md`). Thus the file imports only Observation, and
/// the type states its actor.
@MainActor
public final class ChangeCounter {
  /// The changes since the start.
  public private(set) var count = 0

  /// The closure that reads the observed values.
  private let read: @MainActor () -> Void

  /// Whether the counter observes.
  private var isActive = true

  /// Starts to count the changes of the values that `read` reads.
  ///
  /// - Parameter read: The closure that reads the observed values.
  public init(read: @escaping @MainActor () -> Void) {
    self.read = read
    track()
  }

  /// Stops the count. A later change does not count.
  public func stop() {
    isActive = false
  }

  /// Reads the values and observes them.
  private func track() {
    guard isActive else { return }
    withObservationTracking(read) { [weak self] in
      Task { @MainActor [weak self] in
        self?.didChange()
      }
    }
  }

  /// Counts one change and observes again.
  private func didChange() {
    guard isActive else { return }
    count += 1
    track()
  }
}
