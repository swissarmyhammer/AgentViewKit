import EditorTestSupport
import Testing

/// The error of ``_Concurrency/Task/boundedValue(within:sourceLocation:)``
/// when the task does not end within the bound.
public enum BoundedTaskError: Error, Equatable {
  /// The task did not end within the bound, which the case holds.
  case noEnd(Duration)
}

extension Task where Failure == any Error {
  /// Waits until the task ends, with a bound, and gives its value.
  ///
  /// `await task.value` has no bound, so a task that never ends stops the
  /// test, and with it each other hosted test of the process. This wait
  /// ends at the end of the task, or at the bound. At the bound, it records
  /// an issue, cancels the task and throws, so the test fails and the run
  /// goes on. The bound is a guard against a defect, not a delay.
  ///
  /// - Parameters:
  ///   - bound: The longest time that the wait suspends. The default is
  ///     `BoundedWait.defaultBound`.
  ///   - sourceLocation: The place of the wait in the test, for the issue.
  /// - Returns: The value of the task.
  /// - Throws: The error of the task, or ``BoundedTaskError/noEnd(_:)`` when
  ///   the task did not end within `bound`.
  public func boundedValue(
    within bound: Duration = BoundedWait.defaultBound,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws -> Success {
    try await BoundedTaskEnd.require(of: self, within: bound, at: sourceLocation) {
      _ = await $0.result
    }
    return try await value
  }
}

extension Task where Failure == Never {
  /// Waits until the task ends, with a bound, and gives its value.
  ///
  /// The wait of the throwing form, for a task that cannot fail.
  ///
  /// - Parameters:
  ///   - bound: The longest time that the wait suspends. The default is
  ///     `BoundedWait.defaultBound`.
  ///   - sourceLocation: The place of the wait in the test, for the issue.
  /// - Returns: The value of the task.
  /// - Throws: ``BoundedTaskError/noEnd(_:)`` when the task did not end
  ///   within `bound`.
  public func boundedValue(
    within bound: Duration = BoundedWait.defaultBound,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async throws -> Success {
    try await BoundedTaskEnd.require(of: self, within: bound, at: sourceLocation) {
      _ = await $0.value
    }
    return await value
  }
}

/// The shared wait of the two forms of `boundedValue`.
private enum BoundedTaskEnd {
  /// Suspends until `task` ends or `bound` passes.
  ///
  /// - Parameters:
  ///   - task: The task to wait for.
  ///   - bound: The longest time that the wait suspends.
  ///   - sourceLocation: The place of the wait in the test, for the issue.
  ///   - end: Suspends until `task` ends.
  /// - Throws: ``BoundedTaskError/noEnd(_:)`` when `task` did not end within
  ///   `bound`. Then the call has recorded an issue and cancelled `task`.
  static func require<Success, Failure>(
    of task: Task<Success, Failure>, within bound: Duration, at sourceLocation: SourceLocation,
    end: @escaping @Sendable (Task<Success, Failure>) async -> Void
  ) async throws {
    let ended = await BoundedWait.next(before: .now.advanced(by: bound)) { gate in
      Task {
        await end(task)
        gate.open()
      }
    }
    guard ended else {
      BoundedWait.recordNoEvent(within: bound, at: sourceLocation)
      task.cancel()
      throw BoundedTaskError.noEnd(bound)
    }
  }
}
