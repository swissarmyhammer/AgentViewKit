import EditorSwiftUI
import SwiftUI
import Textual

/// The Textual code block style that shows each fenced code block in a
/// ``CodeBlockView`` (plan.md §4.1, §4.2).
///
/// Apply the style to a Textual document:
///
/// ```swift
/// StructuredText(markdown: text)
///   .textual.codeBlockStyle(EditorKitCodeBlockStyle())
/// ```
///
/// When the environment has a ``CodeBlockModelCache`` and a ``CodeBlockID``,
/// the style shows the cached model of that block. Apply
/// `codeBlockModelCache(_:blockID:)` to the paragraph for this.
public struct EditorKitCodeBlockStyle: StructuredText.CodeBlockStyle {
  @Environment(\.codeBlockModelCache) private var cache
  @Environment(\.codeBlockID) private var blockID

  /// Makes the style.
  public init() {}

  /// Makes a ``CodeBlockView`` for the code block of `configuration`.
  ///
  /// - Parameter configuration: The properties of the code block.
  /// - Returns: The code block view.
  public func makeBody(configuration: Configuration) -> some View {
    let code = Self.code(of: configuration.codeBlock)
    CodeBlockView(
      code: code,
      language: configuration.languageHint,
      model: cachedModel(code: code)
    )
  }

  /// The cached model of the block in the environment, or `nil` when the
  /// environment has no cache or no block identity.
  ///
  /// - Parameter code: The text of a new model.
  /// - Returns: The cached model, or `nil`.
  private func cachedModel(code: String) -> EditorModel? {
    guard let cache, let blockID else { return nil }
    return cache.model(for: blockID, code: code)
  }

  /// The label of the stored property of `CodeBlockProxy` that holds the
  /// code.
  static let proxyContentLabel = "content"

  /// The raw code of a Textual code block.
  ///
  /// Textual 0.5.0 gives no public read of the code. `CodeBlockProxy` keeps
  /// the code in its private stored property `content`, as an
  /// `AttributedSubstring`. The style reads that property with `Mirror`.
  /// The package pins Textual to the exact version 0.5.0, and the hosted
  /// tests of ``CodeBlockView`` read the code through this path. See
  /// `Docs/decisions/code-block-source.md`.
  ///
  /// - Parameter proxy: The proxy of the code block.
  /// - Returns: The code, or an empty string when the read fails.
  static func code(of proxy: StructuredText.CodeBlockProxy) -> String {
    let content = Mirror(reflecting: proxy).children
      .first { $0.label == proxyContentLabel }?
      .value as? AttributedSubstring
    return content.map { String($0.characters) } ?? ""
  }
}
