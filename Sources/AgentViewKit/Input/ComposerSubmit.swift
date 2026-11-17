import Foundation
import FoundationModelsACP
import SwiftUI

/// The prompt that the user submits, as the submit hook of the host gets it
/// (``SwiftUI/View/onComposerSubmit(_:)``, D199).
public nonisolated struct ComposerSubmission: Sendable {
  /// One `@` token of the text.
  public struct Mention: Sendable, Hashable {
    /// The text after the `@`.
    public let token: String

    /// The link of the token: a file URL for a file chip, or for a typed
    /// token that names a file under the file root; the link of the row for
    /// a mention chip; else `nil`.
    public let link: URL?

    /// The range of the token in ``ComposerSubmission/text``, with the `@`.
    public let range: Range<String.Index>
  }

  /// The plain text of the prompt.
  public let text: String

  /// The text of the prompt, with the `link` attribute of each chip.
  public let attributedText: AttributedString

  /// Each `@` token of the text, in text order.
  ///
  /// A token starts at an `@` at the start of the text or after white
  /// space, and ends before the next white space.
  public let mentions: [Mention]

  /// Makes the submission of a prompt text.
  ///
  /// - Parameters:
  ///   - attributedText: The text of the prompt.
  ///   - fileRoot: The file root of the composer, or `nil`.
  init(_ attributedText: AttributedString, fileRoot: URL?) {
    let text = String(attributedText.characters)
    let links = Dictionary(
      attributedText.runs[\.link].compactMap { link, range in link.map { (String(attributedText[range].characters), $0) } }
    ) { first, _ in first }
    self.text = text
    self.attributedText = attributedText
    mentions = FileReferenceDetector.references(in: text).map { reference in
      let utf8 = text.utf8
      let lower = utf8.index(utf8.startIndex, offsetBy: reference.range.lowerBound)
      let upper = utf8.index(utf8.startIndex, offsetBy: reference.range.upperBound)
      let link = links[reference.text] ?? Self.file(reference.path, under: fileRoot)
      return Mention(token: reference.path, link: link, range: lower..<upper)
    }
  }

  /// The URL of a file under the file root.
  ///
  /// - Parameters:
  ///   - path: A path relative to the root.
  ///   - root: The file root, or `nil`.
  /// - Returns: The URL, when the path stays under the root and names a
  ///   file that is not a directory. `nil` otherwise.
  private static func file(_ path: String, under root: URL?) -> URL? {
    guard let root, FileReferenceSource.isSafe(path) else { return nil }
    let url = root.appending(path: path)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory),
      !isDirectory.boolValue
    else { return nil }
    return url
  }
}

/// What the submit hook of the host tells the composer to do (D199).
public nonisolated struct ComposerSubmitResult: Sendable, Hashable {
  /// Whether the composer sends nothing and keeps the text.
  public let isCancelled: Bool

  /// The texts to add to the prompt. Each one is one text block after the
  /// text block of the prompt and before the blocks of the files.
  public let addedText: [String]

  /// The `_meta` of the prompt request, or `nil`.
  public let meta: [String: JSONValue]?

  /// Sends the prompt as the user wrote it.
  public static let send = ComposerSubmitResult(isCancelled: false, addedText: [], meta: nil)

  /// Sends nothing. The text and the files stay in the composer.
  public static let cancel = ComposerSubmitResult(isCancelled: true, addedText: [], meta: nil)

  /// Sends the prompt with added text blocks and a `_meta`.
  ///
  /// - Parameters:
  ///   - addedText: The texts to add, each as one text block after the text
  ///     of the prompt.
  ///   - meta: The `_meta` of the prompt request, or `nil`.
  /// - Returns: The result.
  public static func send(addingText addedText: [String] = [], meta: [String: JSONValue]? = nil)
    -> ComposerSubmitResult
  {
    ComposerSubmitResult(isCancelled: false, addedText: addedText, meta: meta)
  }

  /// The `_meta` value of the prompt request, or `nil`.
  var requestMeta: JSONValue? {
    meta.map(JSONValue.object)
  }
}

/// The submit hook of the host (``SwiftUI/View/onComposerSubmit(_:)``).
public typealias ComposerSubmitHook = @MainActor (ComposerSubmission) async -> ComposerSubmitResult

extension EnvironmentValues {
  /// The submit hook of the composer, or `nil` for none.
  @Entry var composerSubmitHook: ComposerSubmitHook? = nil

  /// Whether the composer waits for the submit hook of the host. While it
  /// waits, the composer takes no submit, the field is disabled, and the
  /// accessory shows that a send is in progress.
  @Entry public var promptSubmitInProgress = false
}

extension View {
  /// Runs `hook` on each submit of a composer below this view, before the
  /// composer clears the text and sends the prompt (D199).
  ///
  /// The hook gets the text and each `@` token with its link
  /// (``ComposerSubmission``). It returns what to send
  /// (``ComposerSubmitResult``): the prompt as the user wrote it, the prompt
  /// with added text blocks and a `_meta`, or nothing.
  ///
  /// The hook can take time. For example, Testudo sends a message to each
  /// mentioned session, and then adds one receipt line for each one. While
  /// the hook runs, the text stays in the composer, the composer takes no
  /// second submit, the field is disabled, and the accessory shows that a
  /// send is in progress (``SwiftUI/EnvironmentValues/promptSubmitInProgress``).
  /// With no hook, a submit sends the prompt at once.
  ///
  /// - Parameter hook: The hook.
  /// - Returns: A view with the hook in its environment.
  public func onComposerSubmit(
    _ hook: @escaping @MainActor (ComposerSubmission) async -> ComposerSubmitResult
  ) -> some View {
    environment(\.composerSubmitHook, hook)
  }
}
