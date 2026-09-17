/// The number of times that ``waitUntil(_:)`` checks its condition.
private let maximumPolls = 400

/// The time between two checks of ``waitUntil(_:)``, in milliseconds.
private let pollMilliseconds = 5

/// The time between two checks of ``waitUntil(_:)``.
private let pollInterval = Duration.milliseconds(pollMilliseconds)

/// Checks a condition until it is true or the time runs out.
///
/// The function sleeps between two checks, so other tasks on the main actor
/// can run. It does not fail at the time limit. The test then checks the
/// return value with an expectation, so that a time-out shows as a failure.
///
/// - Parameter condition: The condition to check.
/// - Returns: The last value of the condition.
public func waitUntil(_ condition: () -> Bool) async -> Bool {
  var polls = 0
  while !condition(), polls < maximumPolls {
    try? await Task.sleep(for: pollInterval)
    polls += 1
  }
  return condition()
}
