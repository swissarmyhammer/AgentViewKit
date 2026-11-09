/// A list of values that a style records as a view runs it.
@MainActor final class StyleRecord<Value> {
  /// The recorded values, in the order of the calls.
  var values: [Value] = []
}
