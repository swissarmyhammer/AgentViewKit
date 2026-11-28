import FoundationModelsACP
import FoundationModelsACPClient

/// The synthetic turns of the flick trace harness of card ^9ync5h3: in each
/// turn, a user message, a thought and an agent answer with Markdown
/// (a heading, paragraphs with inline code, a list and a Python code fence
/// of varied length).
///
/// The harness adds these turns after a recorded session of the demo app.
/// The recorded sessions change over time, so the tests use the synthetic
/// turns alone. Each test gives a name of its own, which each text holds,
/// so a test counts only the work of its own texts.
enum FlickTranscript {
  /// The number of paragraphs of an answer is this base, plus the turn
  /// modulo ``paragraphSpread``.
  static let paragraphBase = 2

  /// The spread of the number of paragraphs of an answer.
  static let paragraphSpread = 5

  /// The number of code lines of an answer is this base, plus a value
  /// below ``codeLineSpread``.
  static let codeLineBase = 6

  /// The step of the code lines of an answer from one turn to the next.
  static let codeLineStep = 7

  /// The spread of the number of code lines of an answer.
  static let codeLineSpread = 30

  /// The number of the repeats of the thought sentences is this base, plus
  /// the turn modulo ``thoughtSpread``.
  static let thoughtBase = 2

  /// The spread of the repeats of the thought sentences.
  static let thoughtSpread = 4

  /// The items of `turns` turns.
  ///
  /// Each message has a message id with the name of the test, so the row
  /// keys of one test are not the row keys of another test. The flick tests
  /// count the work of each row key, and the main run loop of one test can
  /// run the jobs of another test (``PendingRunLoopBlocks``).
  ///
  /// - Parameters:
  ///   - turns: The number of turns.
  ///   - name: The name of the test, which each text and each message id
  ///     holds.
  /// - Returns: A user message, a thought and an answer for each turn.
  static func items(turns: Int, in name: String) -> [PreviewTranscriptItem] {
    (0..<turns).flatMap { turn -> [PreviewTranscriptItem] in
      let id = { (role: String) in MessageId(rawValue: "\(name)-\(role)-\(turn)") }
      return [
        .update(.userMessageChunk(chunk(userText(turn, in: name), id: id("user")))),
        .update(.agentThoughtChunk(chunk(thoughtText(turn, in: name), id: id("thought")))),
        .update(.agentMessageChunk(chunk(answerText(turn, in: name), id: id("answer")))),
      ]
    }
  }

  /// A content chunk of one text block.
  ///
  /// - Parameters:
  ///   - text: The text of the block.
  ///   - id: The message id.
  /// - Returns: The chunk.
  static func chunk(_ text: String, id: MessageId) -> ContentChunk {
    ContentChunk(content: .text(TextContent(text: text)), messageId: id)
  }

  /// The user message of a turn.
  ///
  /// - Parameters:
  ///   - turn: The turn.
  ///   - name: The name of the test.
  /// - Returns: The text.
  static func userText(_ turn: Int, in name: String) -> String {
    "Turn \(turn) of \(name): please look at `resolvers.py` and tell me why `ResolverMatch.__repr__` "
      + "does not show the partial function. Then fix it and run the tests."
  }

  /// The thought of a turn.
  ///
  /// - Parameters:
  ///   - turn: The turn.
  ///   - name: The name of the test.
  /// - Returns: The text.
  static func thoughtText(_ turn: Int, in name: String) -> String {
    String(
      repeating: "I need to read the resolver of \(name) first, then find where the repr is built. "
        + "The partial wraps the view, so the func path comes from the wrong object. ",
      count: thoughtBase + turn % thoughtSpread)
  }

  /// The agent answer of a turn.
  ///
  /// - Parameters:
  ///   - turn: The turn.
  ///   - name: The name of the test.
  /// - Returns: The Markdown text.
  static func answerText(_ turn: Int, in name: String) -> String {
    let paragraphs = paragraphBase + turn % paragraphSpread
    let codeLines = codeLineBase + (turn * codeLineStep) % codeLineSpread
    var text = "## Step \(turn): the resolver\n\n"
    for index in 0..<paragraphs {
      text += "The **resolver** of \(name) builds a `ResolverMatch` for each request (part \(index)). "
        + "When the view is a `functools.partial`, the old code read `func.__module__` of the "
        + "partial object, and not of the wrapped function. Thus the repr showed "
        + "`functools.partial` and not the real view. This change keeps the old path for "
        + "each other caller, and it adds a test for the partial case.\n\n"
    }
    text += "- `test_repr_partial` passes.\n- `test_resolver_match_on_request` passes.\n"
      + "- No other test changes.\n\n```python\n"
    for line in 0..<codeLines {
      text += "        self._\(name)_\(line) = getattr(func, 'func', func).__module__  # line \(line)\n"
    }
    text += "```\n\nThe suite of `urlpatterns_reverse` has 312 tests, and each one passes.\n"
    return text
  }
}
