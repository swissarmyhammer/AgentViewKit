import EditorComplete
import EditorCore
import EditorExtensions
import EditorSwiftUI

/// A real EditorKit completion engine over a document, for the completion
/// source tests.
///
/// The document registers the completion session field, and the caret is at
/// the end of the text.
@MainActor public struct CompletionFixture {
  /// The engine of the document.
  public let document: EditorEngine

  /// The completion engine over the sources.
  public let completion: CompletionEngine

  /// Makes a fixture.
  ///
  /// - Parameters:
  ///   - text: The text of the document.
  ///   - sources: The completion sources.
  public init(_ text: String, sources: [any EditorExtensions.CompletionSource]) {
    self.init(text, engine: CompletionEngine(sources: sources))
  }

  /// Makes a fixture over a completion engine that the caller made, for
  /// example the engine that `EditorKitPromptEditor` composes.
  ///
  /// - Parameters:
  ///   - text: The text of the document.
  ///   - engine: The completion engine.
  public init(_ text: String, engine: CompletionEngine) {
    document = EditorEngine(text, fields: [.field(CompletionSessionField.self)])
    completion = engine
    let context = EditorContext(document.state)
    context.dispatch(
      EditorTransaction(
        changes: .identity(length: text.utf8.count), selection: .cursor(context.documentEnd)))
  }

  /// The text of the document.
  public var text: String {
    document.state.document.string
  }

  /// Runs the query at the caret now.
  ///
  /// - Returns: The labels of the listed rows, in order.
  public func query() async -> [String] {
    await completion.ensureQueried(trigger: .typed, in: EditorContext(document.state)).items.map(\.label)
  }

  /// Accepts the row with `label`.
  ///
  /// - Parameter label: The label of the row.
  /// - Returns: `true` when the engine accepted the row.
  @discardableResult
  public func accept(_ label: String) -> Bool {
    let context = EditorContext(document.state)
    let item = context.value(CompletionSessionField.self).items.first { $0.label == label }
    guard let item else { return false }
    return CompletionCommands.accept(item, in: context)
  }
}
