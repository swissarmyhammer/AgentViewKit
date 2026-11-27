import FoundationModelsACPClient

/// The Markdown texts of the agent answers in the transcripts of the
/// thread tests (card ^7625j1b).
///
/// Each test gives the name of its test or suite, so each test shows texts
/// of its own: EditorKit and the static text keep the work of a text that a
/// test showed before.
enum AnswerText {
  /// The text of the answer at `index` of the transcript of `test`: one
  /// line of prose, and a code fence when `withCodeFence` is `true`.
  ///
  /// - Parameters:
  ///   - index: The index of the answer.
  ///   - test: The name of the test or suite, which makes the text its own.
  ///     With a code fence, the name is also a part of a Swift identifier,
  ///     so it has only letters and digits.
  ///   - withCodeFence: Whether the answer has a Swift code fence after the
  ///     prose.
  /// - Returns: The Markdown text.
  static func answer(_ index: Int, in test: String, withCodeFence: Bool = false) -> String {
    let prose = "\(test) answer \(index): the parser reads each line of the file."
    let fence = withCodeFence ? "\n\n```swift\nlet \(test)\(index) = \(index)\n```\n" : ""
    return prose + fence
  }

  /// The transcript of `count` agent answers of `test`: the answer at each
  /// index is ``answer(_:in:withCodeFence:)``.
  ///
  /// - Parameters:
  ///   - count: The number of answers.
  ///   - test: The name of the test or suite, which makes the texts its own.
  ///   - withCodeFence: Whether each answer has a Swift code fence after
  ///     the prose.
  /// - Returns: The items of the transcript, in the order of their indices.
  static func transcript(count: Int, in test: String, withCodeFence: Bool = false) -> [PreviewTranscriptItem] {
    (0..<count).map { .agent(answer($0, in: test, withCodeFence: withCodeFence)) }
  }
}
