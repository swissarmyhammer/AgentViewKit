#if DEBUG
  /// Counts how many times SwiftUI evaluates the `body` of a view (plan.md §8).
  ///
  /// A view calls ``note(_:)`` in `body`, under `#if DEBUG`, with a key such
  /// as `row-<id>`. A test reads ``count(_:)`` to prove that a change to one
  /// record does not evaluate the rows of other records again.
  ///
  /// The counter is in the model and view target, because the views call it.
  /// It exists only in debug builds.
  @MainActor
  public enum BodyEvaluationCounter {
    /// The number of evaluations for each key.
    private static var counts: [String: Int] = [:]

    /// Adds one evaluation for `key`.
    ///
    /// - Parameter key: The key of the view, such as `row-<id>`.
    public static func note(_ key: String) {
      counts[key, default: 0] += 1
    }

    /// The number of evaluations for `key` since the last reset.
    ///
    /// - Parameter key: The key of the view.
    /// - Returns: The count, or zero when no view noted `key`.
    public static func count(_ key: String) -> Int {
      counts[key, default: 0]
    }

    /// Sets the count for `key` to zero.
    ///
    /// - Parameter key: The key to reset.
    public static func reset(_ key: String) {
      counts[key] = nil
    }

    /// Sets the count for each key that starts with `prefix` to zero.
    ///
    /// Tests run in parallel. A test uses a key prefix of its own and resets
    /// only that prefix, so that it does not change the counts of other tests.
    ///
    /// - Parameter prefix: The key prefix to reset.
    public static func reset(prefix: String) {
      counts = counts.filter { !$0.key.hasPrefix(prefix) }
    }
  }
#endif
