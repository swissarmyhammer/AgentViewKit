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
/// The cache is not observable. A view can read it in its body.
public final class CodeBlockModelCache {
  /// The models, keyed by the identity of their code block.
  private var models: [CodeBlockID: EditorModel] = [:]

  /// Makes an empty cache.
  public init() {}

  /// The number of models in the cache.
  public var count: Int { models.count }

  /// Whether the cache has a model for `id`.
  ///
  /// - Parameter id: The identity of the code block.
  /// - Returns: `true` when the cache has a model for `id`.
  public func contains(_ id: CodeBlockID) -> Bool {
    models[id] != nil
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
    model(for: id, text: code, make: EditorModel.makeReadOnly)
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
    if let model = models[id] {
      return model
    }
    let model = make(text)
    models[id] = model
    return model
  }

  /// Removes the model of each code block in the message `messageID`.
  ///
  /// - Parameter messageID: The id of the removed message.
  public func evict(messageID: String) {
    models = models.filter { $0.key.messageID != messageID }
  }

  /// Removes each model.
  public func removeAll() {
    models.removeAll()
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
