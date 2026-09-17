//
// StreamingCorpus: the Markdown message and its chunks for the streaming
// benchmarks (research R1).
//
// The message has 2,000 lines. Each section has 20 lines: a heading, two
// prose paragraphs with inline Markdown, a list, and a fenced Swift block.
// The text is the same on each run.
//
// The chunks copy a model that streams at 50 tokens per second. The kit
// coalesces the chunks of one coalescer interval (about 33 ms) into one
// flush, so one benchmark chunk is the tokens of one interval.
//

import AgentViewKit

/// The streamed message and its chunks.
///
/// The type is on the main actor, because the interval of
/// ``AgentViewKit/StreamingCoalescer`` is, and the workbench that reads the
/// chunks is.
@MainActor
enum StreamingCorpus {
  /// The number of lines in the message.
  static let lineCount = 2_000

  /// The number of lines in one section of the message.
  static let linesPerSection = 20

  /// The number of sections in the message.
  static let sectionCount = lineCount / linesPerSection

  /// The rate of the streamed model, in tokens per second.
  static let tokensPerSecond = 50.0

  /// The mean number of characters in one token.
  static let charactersPerToken = 4

  /// The number of attoseconds in one second.
  private static let attosecondsPerSecond = 1e18

  /// The number of tokens that arrive in one coalescer interval, rounded up.
  static var tokensPerChunk: Int {
    let interval = StreamingCoalescer.defaultInterval.components
    let intervalSeconds =
      Double(interval.seconds) + Double(interval.attoseconds) / attosecondsPerSecond
    return Int((tokensPerSecond * intervalSeconds).rounded(.up))
  }

  /// The number of characters in one chunk.
  static var charactersPerChunk: Int { tokensPerChunk * charactersPerToken }

  /// The text of one section.
  ///
  /// - Parameter index: The position of the section.
  /// - Returns: The 20 lines of the section, each with its line break. The
  ///   last line is blank, so the section ends its last paragraph.
  nonisolated static func section(_ index: Int) -> String {
    """
    ## Section \(index)

    The agent read **file \(index)** and found `value\(index)` in the
    [report](https://example.com/report/\(index)). The next step checks the
    result against the *expected* output and writes a short summary.

    - Read the input of step \(index).
    - Compare the `result` with the plan.
    - Write the summary.

    ```swift
    let value\(index) = compute(\(index))
    print(value\(index))
    assert(value\(index) > 0)
    ```

    The check of section \(index) passed. The agent continues with the next
    section, and keeps the **same** settings for each _following_ step.
    The run has no errors so far.


    """
  }

  /// The full text of the message.
  static let message: String = (0..<sectionCount).map(section).joined()

  /// The message, cut into chunks of ``charactersPerChunk`` characters.
  static let chunks: [String] = {
    let characters = Array(message)
    return stride(from: 0, to: characters.count, by: charactersPerChunk).map { start in
      String(characters[start..<min(start + charactersPerChunk, characters.count)])
    }
  }()
}
