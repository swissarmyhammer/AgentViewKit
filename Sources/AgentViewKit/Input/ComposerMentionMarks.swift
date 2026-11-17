import EditorCore
import EditorDecorations
import Foundation
import SwiftUI

/// What a host knows about an `@` token of the composer (D199 (h)).
public nonisolated enum ComposerMentionState: Sendable, Hashable {
  /// The token names one target. The token becomes a mention chip with the
  /// link, so ``ComposerSubmission`` gives the link.
  case resolved(link: URL)

  /// The token names no target. The token gets the "not found" mark of
  /// EditorKit, with the reason as its help text.
  case unresolved(reason: String)

  /// The token names more than one target. The token gets the same mark,
  /// with the reason as its help text.
  case ambiguous(reason: String)
}

/// The resolver of the `@` tokens of the composer, and the revision of its
/// answers (``SwiftUI/View/composerMentionResolver(revision:_:)``).
struct ComposerMentionResolver {
  /// The revision of the answers. A new revision clears the answers that
  /// the composer keeps.
  let revision: AnyHashable

  /// Gives the state of a token, or `nil` for no opinion.
  let resolve: @Sendable (String) async -> ComposerMentionState?
}

extension EnvironmentValues {
  /// The resolver of the `@` tokens of the composer, or `nil` for none.
  @Entry var composerMentionResolver: ComposerMentionResolver? = nil
}

extension View {
  /// Gives the composers below this view a resolver of their `@` tokens
  /// (D199 (h)).
  ///
  /// The composer calls `resolve` one time for each `@` token that the user
  /// typed: a token that is not a file chip, not a mention chip, and not a
  /// file under the file root. It does not call it for the token at the
  /// caret while the user types it. The composer keeps each answer by its
  /// token, and finds the range of each token itself.
  ///
  /// - A ``ComposerMentionState/resolved(link:)`` token becomes a mention
  ///   chip with the link.
  /// - An ``ComposerMentionState/unresolved(reason:)`` or
  ///   ``ComposerMentionState/ambiguous(reason:)`` token gets the "not found"
  ///   mark of EditorKit: a dotted red underline, with the reason as its help
  ///   text. VoiceOver reads the reasons as the hint of the field, so give a
  ///   reason that names the token, for example "No session named foo".
  /// - `nil` gives no mark.
  ///
  /// A marked token changes nothing in the prompt that goes out.
  ///
  /// - Parameters:
  ///   - revision: The revision of the answers. When it changes, the composer
  ///     forgets its answers and asks again for each token of the field. A
  ///     chip stays a chip.
  ///   - resolve: Gives the state of a token (the text after `@`).
  /// - Returns: A view with the resolver in its environment.
  public func composerMentionResolver(
    revision: some Hashable & Sendable,
    _ resolve: @escaping @Sendable (_ token: String) async -> ComposerMentionState?
  ) -> some View {
    environment(\.composerMentionResolver, ComposerMentionResolver(revision: AnyHashable(revision), resolve: resolve))
  }
}

/// The pure rules of the marks of `@` tokens (D199 (h)).
nonisolated enum ComposerMentionMarks {
  /// One mark: the UTF-8 range of the token, its text with the `@`, and the
  /// reason.
  struct Mark: Hashable {
    /// The UTF-8 range of the token, with the `@`.
    let range: Range<Int>
    /// The text of the token, with the `@`.
    let text: String
    /// The help text of the mark.
    let reason: String
  }

  /// The tokens of `text` that the composer asks the resolver about.
  ///
  /// - Parameters:
  ///   - text: The text of the editor.
  ///   - caret: The UTF-8 offset of the caret.
  ///   - fileRoot: The file root, or `nil`.
  ///   - chips: The tokens of the file chips and the mention chips.
  ///   - known: The tokens that have an answer, or that wait for one.
  /// - Returns: Each token that is not at the caret, not a chip, not a file
  ///   under the root, and not known, one time, in text order.
  static func tokensToResolve(
    in text: String, caret: Int, fileRoot: URL?, chips: Set<String>, known: Set<String>
  ) -> [String] {
    var seen = known.union(chips)
    return FileReferenceDetector.references(in: text).compactMap { reference in
      guard reference.range.upperBound != caret, !reference.path.isEmpty,
        isFile(reference.path, under: fileRoot) == false, seen.insert(reference.path).inserted
      else { return nil }
      return reference.path
    }
  }

  /// The marks of `text`: one for each token whose state is unresolved or
  /// ambiguous.
  ///
  /// - Parameters:
  ///   - text: The text to scan.
  ///   - states: The answers of the resolver, by token.
  /// - Returns: The marks, in text order.
  static func marks(in text: String, states: [String: ComposerMentionState?]) -> [Mark] {
    FileReferenceDetector.references(in: text).compactMap { reference in
      switch states[reference.path] {
      case .some(.some(.unresolved(let reason))), .some(.some(.ambiguous(let reason))):
        Mark(range: reference.range, text: reference.text, reason: reason)
      default:
        nil
      }
    }
  }

  /// The resolved tokens and their links.
  ///
  /// - Parameter states: The answers of the resolver, by token.
  /// - Returns: The link of each resolved token.
  static func resolvedMentions(in states: [String: ComposerMentionState?]) -> [String: URL] {
    states.reduce(into: [:]) { result, entry in
      if case .some(.resolved(let link)) = entry.value { result[entry.key] = link }
    }
  }

  /// Whether `path` names a file under `root`.
  private static func isFile(_ path: String, under root: URL?) -> Bool {
    guard let root, FileReferenceSource.isSafe(path) else { return false }
    var isDirectory: ObjCBool = false
    let url = root.appending(path: path)
    return FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
      && !isDirectory.boolValue
  }
}

/// Finds the marks of the `@` tokens that name no target, so that EditorKit
/// draws its "not found" mark on them (D199 (h)).
nonisolated struct MentionMarkDetector: EditorDecorations.TagDetector {
  /// The answers of the resolver, by token.
  let states: [String: ComposerMentionState?]

  /// The marks in `range`.
  ///
  /// - Parameters:
  ///   - range: The range to scan.
  ///   - context: The editor context.
  /// - Returns: One unresolved match for each mark.
  func detect(in range: EditorRange, context: EditorContext) -> [EditorDecorations.TagMatch] {
    guard !states.isEmpty else { return [] }
    let document = context.state.document
    return ComposerMentionMarks.marks(in: context.text(in: range), states: states).map { mark in
      EditorDecorations.TagMatch.unresolved(
        range: EditorRange(
          document.position(utf8Offset: range.lowerBound.utf8Offset + mark.range.lowerBound),
          document.position(utf8Offset: range.lowerBound.utf8Offset + mark.range.upperBound)),
        text: mark.text, reason: mark.reason)
    }
  }
}
