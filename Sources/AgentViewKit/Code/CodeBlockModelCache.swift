import EditorSwiftUI
import SwiftUI

/// The identity of one fenced code block in a message (plan.md §8).
///
/// The paragraph splitter gives each paragraph of a message a stable id. A
/// fenced code block is one paragraph, so the message id and the paragraph
/// id together identify the block.
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

/// Keeps one EditorKit model for each fenced code block (plan.md §8).
///
/// When the streaming tail of a message renders again, each settled code
/// block gets the same model. Thus EditorKit does not lay out a settled block
/// again. The owner of the messages calls ``evict(messageID:)`` when it
/// removes a message.
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
    if let model = models[id] {
      return model
    }
    let model = EditorModel.makeReadOnly(code)
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
}

extension EnvironmentValues {
  /// The cache that ``EditorKitCodeBlockStyle`` gets its models from, or
  /// `nil` when each code block keeps its own model.
  @Entry public var codeBlockModelCache: CodeBlockModelCache? = nil

  /// The identity of the code block in this subtree, or `nil` when the
  /// subtree has no identity.
  @Entry public var codeBlockID: CodeBlockID? = nil
}

extension View {
  /// Gives each code block in this subtree the cached model of `blockID`.
  ///
  /// Apply this modifier to the view of one paragraph that holds one fenced
  /// code block.
  ///
  /// - Parameters:
  ///   - cache: The cache of the models.
  ///   - blockID: The identity of the code block in this subtree.
  /// - Returns: A view that gives the cache and the identity to its subtree.
  public func codeBlockModelCache(_ cache: CodeBlockModelCache, blockID: CodeBlockID) -> some View {
    environment(\.codeBlockModelCache, cache)
      .environment(\.codeBlockID, blockID)
  }
}
