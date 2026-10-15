import Observation

/// Waits for an event of an observable model, with no clock.
///
/// ``until(_:)`` reads a predicate. While the predicate is `false`, the wait
/// observes the values that the predicate reads, and suspends until one of
/// them changes. Then it reads the predicate again. The wait does not poll,
/// does not sleep, and has no time limit. ``ChangeFlag`` tells only whether
/// one change came; this wait suspends the test until the predicate is true.
@MainActor
public enum ObservationWait {
  /// Suspends until `predicate` is `true`.
  ///
  /// The call returns at once when `predicate` is `true` at the start. Each
  /// change of a value that `predicate` reads resumes the wait one time, and
  /// the wait then reads `predicate` again. Give a predicate that reads only
  /// observable values, such as the `pendingPermissions` of a `SessionModel`.
  ///
  /// - Parameter predicate: The condition to wait for.
  public static func until(_ predicate: @MainActor () -> Bool) async {
    while !predicate() {
      await nextChange(of: predicate)
    }
  }

  /// Suspends until a value that `read` reads changes.
  ///
  /// The observation starts before the call suspends, and no other main
  /// actor work runs between the last read of the predicate and the start.
  /// Thus no change goes by unseen.
  ///
  /// - Parameter read: The closure that reads the observed values.
  private static func nextChange(of read: @MainActor () -> Bool) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      withObservationTracking {
        _ = read()
      } onChange: {
        continuation.resume()
      }
    }
  }
}
