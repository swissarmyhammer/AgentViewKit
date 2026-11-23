/// The output of the last parse of a row body, kept with its input
/// (task ^0g7ftka, #scroll-perf).
///
/// SwiftUI can evaluate the body of a row many times with the same text,
/// for example when the row enters or leaves the ``LiveRowRange``. A view
/// keeps one memo for each parse in its state, as ``LaidOutHeight`` is kept.
/// The memo parses an input only when it is not equal to the last input.
/// Thus a row parses its text one time for each change of the text, and not
/// one time for each evaluation of its body.
///
/// The memo keeps one entry. A row has one text at a time, so an older
/// output has no use. The memo is not observable, so a new output does not
/// make the view evaluate its body again.
///
/// In a debug build, each parse adds one count to the
/// ``BodyEvaluationCounter`` key that the view gives. Thus a test can count
/// the parses of a view.
@MainActor final class ParseMemo<Input: Equatable, Output> {
  /// The last input and its output, or `nil` before the first parse.
  private var last: (input: Input, output: Output)?

  /// The output of `parse` for `input`.
  ///
  /// - Parameters:
  ///   - input: The input of the parse, such as the text of the row.
  ///   - counterKey: The ``BodyEvaluationCounter`` key of the parse. The
  ///     memo reads it only in a debug build, and only when it parses.
  ///   - parse: The parse. The memo calls it only when `input` is not equal
  ///     to the last input.
  /// - Returns: The output of the last parse when its input is equal to
  ///   `input`. Otherwise the output of a new parse of `input`.
  func value(for input: Input, counterKey: @autoclosure () -> String, parse: (Input) -> Output)
    -> Output
  {
    if let last, last.input == input {
      return last.output
    }
    #if DEBUG
      BodyEvaluationCounter.note(counterKey())
    #endif
    let output = parse(input)
    last = (input, output)
    return output
  }
}
