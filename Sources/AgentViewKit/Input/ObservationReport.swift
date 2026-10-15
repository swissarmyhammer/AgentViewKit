/// The function that gets each value that a view reports.
///
/// The value is an internal observation point for the tests. A view calls the
/// function in the same step as the change that it reports, so a test that
/// records the values in an observable model can wait for the event with no
/// clock.
///
/// The function is in a struct, not in the environment value itself: an
/// environment value that holds a closure can invalidate its dependents on
/// each update.
struct ObservationReport<Value> {
  /// The function that gets each value.
  let report: @MainActor (Value) -> Void

  /// Gives one value to the function.
  ///
  /// - Parameter value: The value that the view reports.
  func callAsFunction(_ value: Value) {
    report(value)
  }
}
