import EditorComplete
import EditorCore
import EditorDecorations
import EditorExtensions
import Foundation
import SwiftUI
import Synchronization

/// One row that a host gives under `@` in the composer (D199).
///
/// The kit knows no kind of mention. For example, Testudo gives one row for
/// each session, with the link `testudo-session://<id>`.
public nonisolated struct ComposerMention: Sendable, Hashable {
  /// The text of the row in the popup.
  public var label: String

  /// The text after `@` that an accept inserts, for example `claude-code`.
  /// An accept inserts `@`, the token, and a space.
  public var token: String

  /// The secondary text of the row, or `nil`.
  public var detail: String?

  /// The link of the mention, or `nil`.
  ///
  /// An accepted row with a link becomes a chip, and the prompt text has the
  /// link on the run of `@` and the token.
  public var link: URL?

  /// The name of the SF Symbol of the row, or `nil` for no icon. The popup
  /// shows it at the leading edge of the row, as the `@file` rows show the
  /// symbol of a file or a folder.
  public var symbol: String?

  /// Makes a mention row.
  ///
  /// - Parameters:
  ///   - label: The text of the row in the popup.
  ///   - token: The text after `@` that an accept inserts.
  ///   - detail: The secondary text of the row, or `nil`.
  ///   - link: The link of the mention, or `nil`.
  ///   - symbol: The name of the SF Symbol of the row, or `nil`.
  public init(label: String, token: String, detail: String? = nil, link: URL? = nil, symbol: String? = nil) {
    self.label = label
    self.token = token
    self.detail = detail
    self.link = link
    self.symbol = symbol
  }
}

/// A host provider of the mention rows under `@` (D199).
///
/// The source gets the body of the token at the caret: the text after `@`,
/// which is empty right after the `@`. It gives its rows filtered and in
/// their final order. The kit does not rank them again.
public nonisolated struct ComposerMentionSource: Sendable {
  /// Gives the rows for a body.
  let mentions: @Sendable (String) async -> [ComposerMention]

  /// Makes a mention source.
  ///
  /// - Parameter mentions: Gives the rows for the body of the token, in
  ///   their final order.
  public init(_ mentions: @escaping @Sendable (_ body: String) async -> [ComposerMention]) {
    self.mentions = mentions
  }
}

extension EnvironmentValues {
  /// The mention sources of the composer (``SwiftUI/View/composerMentions(_:)``).
  @Entry var composerMentionSources: [ComposerMentionSource] = []
}

extension View {
  /// Adds the rows of host mention sources to the `@` popup of each
  /// composer below this view (D199).
  ///
  /// The popup shows the `@file` rows of the kit first, then the rows of
  /// each source, in source order. A mention source does not turn the
  /// `@file` rows off. A source works also with no file root
  /// (``SwiftUI/View/promptFileRoot(_:)``).
  ///
  /// An `@` route of ``SwiftUI/View/composerCompletions(_:)`` takes the `@`
  /// from the kit. Then the kit shows no `@file` row and no mention row.
  ///
  /// ```swift
  /// AgentThreadView(session: session, connection: connection)
  ///   .composerMentions([
  ///     ComposerMentionSource { body in await sessions.mentions(matching: body) }
  ///   ])
  /// ```
  ///
  /// - Parameter sources: The sources, in display order.
  /// - Returns: A view with the sources in its environment.
  public func composerMentions(_ sources: [ComposerMentionSource]) -> some View {
    environment(\.composerMentionSources, sources)
  }
}

/// The mention sources that an engine reads at each query.
///
/// The composer keeps one value and gives it the newest sources before each
/// request, so new sources need no new engine. The engine reads the list from
/// concurrent query tasks, so the list is in a `Mutex`.
nonisolated final class ComposerMentionSources: Sendable {
  /// The sources.
  private let state: Mutex<[ComposerMentionSource]>

  /// The link of each row of the last query, by its token. A row with no
  /// link has the value `nil`.
  private let offeredRows = Mutex<[String: URL?]>([:])

  /// Makes a list of sources.
  ///
  /// - Parameter sources: The sources, in display order.
  init(_ sources: [ComposerMentionSource]) {
    state = Mutex(sources)
  }

  /// Keeps the rows of a query, in place of the rows of the last query.
  /// The first row of a token wins.
  ///
  /// - Parameter mentions: The rows of the query.
  func offer(_ mentions: [ComposerMention]) {
    var rows: [String: URL?] = [:]
    for mention in mentions where rows[mention.token] == nil {
      rows.updateValue(mention.link, forKey: mention.token)
    }
    offeredRows.withLock { $0 = rows }
  }

  /// The link of the row of the last query with `token`.
  ///
  /// - Parameter token: The text after `@`.
  /// - Returns: `nil` when the last query had no row with the token;
  ///   `.some(nil)` for a row with no link.
  func offered(_ token: String) -> URL?? {
    offeredRows.withLock { $0[token] }
  }

  /// The sources, in display order.
  var sources: [ComposerMentionSource] {
    get { state.withLock { $0 } }
    set { state.withLock { $0 = newValue } }
  }
}

/// The `@` completion source of the kit when a host gives mention sources:
/// the rows of the ``FileReferenceSource``, then the rows of each
/// ``ComposerMentionSource`` (D199).
///
/// The result is ranked, so the engine keeps this order. The file source
/// already filters its rows by the typed name and sorts them, directories
/// first. Each mention source gives its rows in their final order.
nonisolated struct AtReferenceSource: EditorExtensions.CompletionSource {
  /// The file source, or `nil` when there is no file root.
  let files: FileReferenceSource?

  /// The mention sources.
  let mentions: ComposerMentionSources

  /// The `@` opening, so that an accept replaces the whole token. The body
  /// holds all characters that are not white space, as ``body(at:)`` does, so
  /// a token with a `-` such as `@default-2` is one token.
  var tokenOpenings: [CompletionTokenOpening] {
    [CompletionTokenOpening(text: FileReferenceSource.trigger, body: .nonWhitespace)]
  }

  /// The file rows, then the mention rows, for the token at the caret.
  ///
  /// - Parameter context: The completion context of the engine.
  /// - Returns: The rows, or `nil` when the caret is not in an `@` token, no
  ///   source has a row, or the query is cancelled.
  func completions(for context: CompletionContext) async -> CompletionResult? {
    guard !Task.isCancelled, let body = Self.body(at: context) else { return nil }
    var items = await files?.completions(for: context)?.items ?? []
    var offered: [ComposerMention] = []
    for source in mentions.sources {
      guard !Task.isCancelled else { return nil }
      offered += await source.mentions(body)
    }
    guard !Task.isCancelled else { return nil }
    mentions.offer(offered)
    items += offered.map(Self.completion(for:))
    guard !items.isEmpty else { return nil }
    return CompletionResult(items: items, isRanked: true)
  }

  /// The row of a mention: it inserts `@`, the token, and a space, and it
  /// shows the symbol of the mention.
  ///
  /// - Parameter mention: The mention.
  /// - Returns: The row.
  static func completion(for mention: ComposerMention) -> Completion {
    Completion(
      label: mention.label, insert: .text(FileReferenceSource.trigger + mention.token + " "), kind: .tag,
      detail: mention.detail, symbol: mention.symbol)
  }

  /// The body of the `@` token at the caret: the text after the `@`.
  ///
  /// The token is the run of characters that are not white space before the
  /// caret. It must start with `@`.
  ///
  /// - Parameter context: The completion context of the engine.
  /// - Returns: The body, or `nil` when the caret is not in an `@` token.
  static func body(at context: CompletionContext) -> String? {
    let line = context.editor.line(containing: context.position)
    guard let caret = CompletionTokenizer.caretIndex(in: line, caret: context.position) else { return nil }
    let text = line.text
    var start = caret
    while start > text.startIndex, !text[text.index(before: start)].isWhitespace {
      start = text.index(before: start)
    }
    let run = text[start..<caret]
    guard run.hasPrefix(FileReferenceSource.trigger) else { return nil }
    return String(run.dropFirst(FileReferenceSource.trigger.count))
  }
}

/// Finds the accepted mentions of the prompt, so that each one shows as a
/// chip (D199).
///
/// A typed `@` token that the user did not accept from the popup is not a
/// chip.
nonisolated struct MentionDetector: EditorDecorations.TagDetector {
  /// The kind of each match.
  static let kind = "mention"

  /// The tokens of the accepted mentions, without the `@`.
  let tokens: Set<String>

  /// The accepted mentions in `range`.
  ///
  /// - Parameters:
  ///   - range: The range to scan.
  ///   - context: The editor context.
  /// - Returns: One match for each accepted mention.
  func detect(in range: EditorRange, context: EditorContext) -> [EditorDecorations.TagMatch] {
    guard !tokens.isEmpty else { return [] }
    let document = context.state.document
    return Self.mentions(in: context.text(in: range), tokens: tokens).map { mention in
      let lower = range.lowerBound.utf8Offset + mention.range.lowerBound
      let upper = range.lowerBound.utf8Offset + mention.range.upperBound
      return EditorDecorations.TagMatch(
        range: EditorRange(document.position(utf8Offset: lower), document.position(utf8Offset: upper)),
        kind: Self.kind, text: mention.text)
    }
  }

  /// Each `@` token of `text` whose token is in `tokens`.
  ///
  /// - Parameters:
  ///   - text: The text to scan.
  ///   - tokens: The accepted tokens, without the `@`.
  /// - Returns: The UTF-8 range, the full text and the token of each match.
  static func mentions(in text: String, tokens: Set<String>) -> [(range: Range<Int>, text: String, token: String)] {
    FileReferenceDetector.references(in: text).compactMap { reference in
      tokens.contains(reference.path) ? (reference.range, reference.text, reference.path) : nil
    }
  }
}
