import EditorSwiftUI
import SwiftUI

/// The identity of one block of a message that keeps an EditorKit model
/// (plan.md §8): a fenced code block, or the whole text of a
/// ``ResponseView``.
///
/// The message id and the paragraph id together identify the block. The
/// whole text of a response has the paragraph id
/// ``ResponseView/textBlockKey``.
nonisolated public struct CodeBlockID: Hashable, Sendable {
  /// The id of the message that holds the block.
  public var messageID: String
  /// The id of the paragraph that holds the block.
  public var paragraphID: String

  /// Makes the identity of a code block.
  ///
  /// - Parameters:
  ///   - messageID: The id of the message that holds the block.
  ///   - paragraphID: The id of the paragraph that holds the block.
  public init(messageID: String, paragraphID: String) {
    self.messageID = messageID
    self.paragraphID = paragraphID
  }
}

/// Keeps one EditorKit model for each block of a message (plan.md §8): each
/// fenced code block, and the text of each ``ResponseView``.
///
/// When a view of a block is made again, such as a row that a lazy list
/// shows again, the block gets the same model. Thus EditorKit does not parse
/// and lay out the text of the block again. The owner of the messages calls
/// ``evict(messageID:)`` when it removes a message.
///
/// A cache can have a limit: the largest number of models that it keeps.
/// When a new model goes past the limit, the cache removes the model that a
/// view used least recently. Each read of a model with
/// ``model(for:code:)`` is a use. A ``ConversationView`` with no cache of
/// the host keeps the models of its rows in a cache of its own with a limit
/// (``threadLimit``).
///
/// The cache is not observable. A view can read it in its body.
public final class CodeBlockModelCache {
  /// A model and the time of its last use.
  private struct Entry {
    /// The model.
    let model: EditorModel

    /// The value of ``CodeBlockModelCache/clock`` at the last use of the
    /// model. A smaller value is an older use.
    var lastUse: UInt64
  }

  /// The limit of the cache that a ``ConversationView`` makes when the host
  /// gives no cache.
  ///
  /// The transcript does not bound the models: a thread can have thousands
  /// of answers, and one answer can keep many models. The live rows of a
  /// thread (``LiveRowRange``) are the rows in view and
  /// ``LiveRowRange/margin`` rows on each side of them, so they keep much
  /// fewer models than this limit. Thus a model of a live row stays in the
  /// cache, and the cache keeps also the models of the rows that scrolled
  /// out of the live rows most recently. The limit caps the memory of those
  /// rows: the cache keeps their models, not their editors. When the live
  /// rows keep more models than the limit, such as rows with very many code
  /// blocks, some rows make new models when they come back, and each row
  /// still shows its whole text.
  static let threadLimit = 256

  /// The models, keyed by the identity of their code block.
  private var entries: [CodeBlockID: Entry] = [:]

  /// The largest number of models that the cache keeps.
  private let limit: Int

  /// The number of uses of the models since the cache was made. Each use
  /// adds one, so a larger value is a more recent use.
  private var clock: UInt64 = 0

  /// Makes an empty cache.
  ///
  /// - Parameter limit: The largest number of models that the cache keeps.
  ///   A value less than one keeps one model. The default keeps each model
  ///   until ``evict(messageID:)`` or ``removeAll()`` removes it.
  public init(limit: Int = .max) {
    self.limit = max(limit, 1)
  }

  /// The number of models in the cache.
  public var count: Int { entries.count }

  /// Whether the cache has a model for `id`.
  ///
  /// The call is not a use of the model.
  ///
  /// - Parameter id: The identity of the code block.
  /// - Returns: `true` when the cache has a model for `id`.
  public func contains(_ id: CodeBlockID) -> Bool {
    entries[id] != nil
  }

  /// The model of the code block `id`.
  ///
  /// When the cache has no model for `id`, it makes a read-only model that
  /// holds `code`. When the cache has a model, it returns that model and
  /// does not change its text. ``CodeBlockView`` changes the text when the
  /// code changes.
  ///
  /// - Parameters:
  ///   - id: The identity of the code block.
  ///   - code: The text of a new model.
  /// - Returns: The model of the code block.
  public func model(for id: CodeBlockID, code: String) -> EditorModel {
    model(for: id, text: code, make: CodeBlockView.makeModel)
  }

  /// The model of the block `id`.
  ///
  /// When the cache has no model for `id`, it makes a model with `make`.
  /// When the cache has a model, it returns that model and does not change
  /// its text.
  ///
  /// - Parameters:
  ///   - id: The identity of the block.
  ///   - text: The text of a new model.
  ///   - make: Makes a model that holds a text, such as a read-only model in
  ///     the rendered presentation (``RenderedMarkdownView``).
  /// - Returns: The model of the block.
  func model(for id: CodeBlockID, text: String, make: (String) -> EditorModel) -> EditorModel {
    clock += 1
    if let entry = entries[id] {
      entries[id]?.lastUse = clock
      return entry.model
    }
    if entries.count >= limit {
      removeLeastRecentlyUsed()
    }
    let model = make(text)
    entries[id] = Entry(model: model, lastUse: clock)
    return model
  }

  /// Removes the model that a view used least recently.
  ///
  /// The function reads each entry. The cache calls it only when a new
  /// model goes past the limit, and making a model costs much more than
  /// the read.
  private func removeLeastRecentlyUsed() {
    guard let oldest = entries.min(by: { $0.value.lastUse < $1.value.lastUse })?.key else {
      return
    }
    entries[oldest] = nil
  }

  /// Removes the model of each code block in the message `messageID`.
  ///
  /// - Parameter messageID: The id of the removed message.
  public func evict(messageID: String) {
    entries = entries.filter { $0.key.messageID != messageID }
  }

  /// Removes each model.
  public func removeAll() {
    entries.removeAll()
  }
}

extension EditorModel {
  /// Makes a read-only model that holds `code`.
  ///
  /// - Parameter code: The text of the model.
  /// - Returns: The model.
  static func makeReadOnly(_ code: String) -> EditorModel {
    let model = EditorModel(code)
    model.isReadOnly = true
    return model
  }

  /// Makes a read-only model that holds `text`, as ``makeReadOnly(_:)``
  /// does.
  ///
  /// In a debug build, each call adds one count to the
  /// ``BodyEvaluationCounter`` key ``readOnlyCounterKey(for:keyPrefix:)`` of
  /// `text`. Thus a test can count the models that a view makes.
  ///
  /// - Parameters:
  ///   - text: The text of the model.
  ///   - keyPrefix: The start of the counter key, one for each kind of view.
  /// - Returns: The model.
  static func makeCountedReadOnly(_ text: String, keyPrefix: String) -> EditorModel {
    #if DEBUG
      BodyEvaluationCounter.note(readOnlyCounterKey(for: text, keyPrefix: keyPrefix))
    #endif
    return makeReadOnly(text)
  }

  /// The ``BodyEvaluationCounter`` key of the models that
  /// ``makeCountedReadOnly(_:keyPrefix:)`` makes for `text`.
  ///
  /// The key holds the whole text, so a test that uses texts of its own does
  /// not see the models of other tests.
  ///
  /// - Parameters:
  ///   - text: The text of the model.
  ///   - keyPrefix: The start of the key.
  /// - Returns: `<keyPrefix><text>`.
  static func readOnlyCounterKey(for text: String, keyPrefix: String) -> String {
    keyPrefix + text
  }

  /// Makes the model read-only and changes its text to `text`.
  ///
  /// A write to an observed property notifies each observer, also when the
  /// value does not change. Thus the function writes only a new value.
  ///
  /// - Parameter text: The full text that the document must have.
  func syncReadOnly(to text: String) {
    if !isReadOnly {
      isReadOnly = true
    }
    syncStreaming(to: text)
  }
}

extension EnvironmentValues {
  /// The cache that ``ResponseView`` gets its model from, or `nil` when each
  /// view keeps its own model.
  @Entry public var codeBlockModelCache: CodeBlockModelCache? = nil
}
