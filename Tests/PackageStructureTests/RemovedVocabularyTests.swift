import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// One use of a removed symbol in a Swift source file.
struct RemovedSymbolUse: Equatable, CustomStringConvertible {
  /// The file that holds the use, relative to the package root.
  let file: String
  /// The line number of the use. The first line is line 1.
  let line: Int
  /// The removed symbol.
  let symbol: String

  var description: String {
    "\(file):\(line) uses \(symbol)"
  }
}

/// Holds `Sources/` free of the symbols that the ACP client kit removed
/// (update.md §3, §6).
///
/// Each removal task adds its symbols to ``removedSymbols``. The scan reads
/// each Swift file as text, and finds a symbol only as a whole word. Thus
/// `addBranch` does not match `addBranches`.
@Suite struct RemovedVocabularyTests {
  /// The directory that the scan reads.
  static let sourcesPath = "Sources"

  /// The symbols that no file in `Sources/` can use.
  static let removedSymbols = [
    // Branches.
    "BranchNavigator", "addBranch", "selectBranch",
    // Checkpoints.
    "CheckpointCapabilities", "CheckpointView", "setCheckpoints",
    // Subagents.
    "SubagentRun", "SubagentSource", "SubagentTreeView", "upsertSubagent",
    // Compaction markers.
    "CompactionMarker", "CompactionMarkerView", "compactionView", "compactionViewOverride",
    // The system prompt item.
    "SystemPrompt", "SystemPromptView", "systemPromptView", "systemPromptViewOverride",
    // The structured item and the schemaName catalog.
    "StructuredRecord", "StructuredCatalog", "StructuredPayload", "StructuredItemView",
    "StructuredItemContent", "StructuredItemRegistry", "RegisteredStructuredView",
    "structuredItem", "structuredItemRegistry", "structuredItemView", "structuredItemViewOverride",
    "ApprovalPayload", "PlanPayload", "UsagePayload",
    // The authorization request of the thread, and the plan removal.
    "AuthorizationPayload", "AuthorizationRequest", "AuthorizationRequestID", "AuthorizationView",
    "addAuthorization", "pendingAuthorizations", "resolveAuthorization", "removePlan",
    // The error kinds that only FoundationModels made.
    "contextSizeExceeded", "guardrailViolation",
    // The prompt queue of the composer.
    "PromptQueue", "PromptQueueView",
    // The kit stream copy of the text of a transcript entry.
    "EntryTextStream", "canStream",
    // The kit reply copies of the pending requests, and the answered flag of
    // the permission card.
    "PermissionReplying", "ElicitationReplying", "permissionReplies", "elicitationReplies",
    "isAnswered",
    // The kit turn grouping and the durations from the host times. The model
    // has no turn and no time.
    "TurnSummary", "TurnSummaryRow", "ThreadTurnSummary", "DiffStat",
  ]

  /// The directories of the pending request cards.
  static let pendingRequestCardPaths = [
    "Sources/AgentViewKit/HumanInTheLoop", "Sources/AgentViewKit/Elicitation",
  ]

  /// The tool call view, which shows the linked elicitation cards.
  static let toolCallViewPath = "Sources/AgentViewKit/Items/ToolCallView.swift"

  /// The mapping that converts a model value to a kit copy. No pending
  /// request card calls it.
  static let mappingSymbol = "SessionUpdateMapping"

  /// The usage initializer from the fill of the context window.
  static let usageFromFill = RemovedInitializer(name: "init(used:fill:)", labels: ["used", "fill"])

  /// The initializers that no file in `Sources/` can call.
  static let removedInitializers = [usageFromFill]

  /// Finds a call of a removed initializer on one line of a Swift file.
  ///
  /// - Parameters:
  ///   - initializer: The removed initializer.
  ///   - pattern: The pattern of `initializer`, from
  ///     ``RemovedInitializer/pattern()``.
  ///   - line: The line.
  /// - Returns: The use, or `nil` when the line does not call `initializer`.
  static func use(
    of initializer: RemovedInitializer,
    matching pattern: Regex<AnyRegexOutput>,
    on line: SourceLine
  ) -> RemovedSymbolUse? {
    guard line.text.contains(pattern) else { return nil }
    return RemovedSymbolUse(file: line.file, line: line.number, symbol: initializer.name)
  }

  /// Finds each use of a removed symbol on one line of a Swift file.
  ///
  /// - Parameters:
  ///   - symbols: The removed symbols.
  ///   - line: The line.
  /// - Returns: The uses, in symbol order.
  static func uses(of symbols: [String], on line: SourceLine) -> [RemovedSymbolUse] {
    symbols
      .filter { line.text.contains(wholeWord($0)) }
      .map { RemovedSymbolUse(file: line.file, line: line.number, symbol: $0) }
  }

  /// The pattern that matches a symbol only as a whole word.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// The pattern uses simple word boundaries. The default boundaries follow
  /// Unicode word segmentation, which does not break at a `.` between two
  /// letters. Thus `thread.pendingAuthorizations` would not match.
  ///
  /// - Parameter symbol: The symbol.
  /// - Returns: The pattern.
  static func wholeWord(_ symbol: String) -> Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      symbol
      Anchor.wordBoundary
    }
    .wordBoundaryKind(.simple)
  }

  @Test func usesFindsAWholeWordOnItsLine() {
    let source = "let a = 1\nthread.apply(.addBranch(afterUserMessage: id, items: []))"

    let found = SourceLineScanner.matches(inSource: source, file: "A.swift") { line in
      Self.uses(of: ["addBranch"], on: line)
    }

    #expect(found == [RemovedSymbolUse(file: "A.swift", line: 2, symbol: "addBranch")])
  }

  @Test func usesFindsAWordAfterAMemberDot() {
    let line = SourceLine(file: "A.swift", number: 1, text: "thread.pendingAuthorizations.map(\\.id)")

    let found = Self.uses(of: ["pendingAuthorizations"], on: line)

    #expect(found == [RemovedSymbolUse(file: "A.swift", line: 1, symbol: "pendingAuthorizations")])
  }

  @Test func usesSkipsALongerWord() {
    let line = SourceLine(file: "A.swift", number: 1, text: "addBranches(); preaddBranch()")

    let found = Self.uses(of: ["addBranch"], on: line)

    #expect(found.isEmpty)
  }

  @Test func sourcesUseNoRemovedSymbol() throws {
    let found = try SourceLineScanner.matches(
      inSwiftFilesBelow: PackageFiles.file(Self.sourcesPath),
      relativeTo: PackageFiles.root
    ) { line in
      Self.uses(of: Self.removedSymbols, on: line)
    }

    #expect(found.isEmpty, "\(found)")
  }

  @Test func thePendingRequestCardsUseNoSessionUpdateMapping() throws {
    let cardFiles = try Self.pendingRequestCardPaths.flatMap { path in
      try SourceLineScanner.matches(
        inSwiftFilesBelow: PackageFiles.file(path),
        relativeTo: PackageFiles.root
      ) { line in
        Self.uses(of: [Self.mappingSymbol], on: line)
      }
    }
    let toolCallView = SourceLineScanner.matches(
      inSource: try PackageFiles.text(of: Self.toolCallViewPath), file: Self.toolCallViewPath
    ) { line in
      Self.uses(of: [Self.mappingSymbol], on: line)
    }

    let found = cardFiles + toolCallView
    #expect(found.isEmpty, "\(found)")
  }

  @Test func useFindsTheLabelsOfACall() throws {
    let line = SourceLine(file: "A.swift", number: 3, text: "let usage = ContextUsage(used: count(), fill: 0.5)")

    let found = Self.use(of: Self.usageFromFill, matching: try Self.usageFromFill.pattern(), on: line)

    #expect(found == RemovedSymbolUse(file: "A.swift", line: 3, symbol: "init(used:fill:)"))
  }

  @Test func useSkipsACallWithOtherLabels() throws {
    let line = SourceLine(file: "A.swift", number: 1, text: "ContextUsage(used: 1, size: 2); context.fill(path)")

    let found = Self.use(of: Self.usageFromFill, matching: try Self.usageFromFill.pattern(), on: line)

    #expect(found == nil)
  }

  @Test func sourcesCallNoRemovedInitializer() throws {
    let patterns = try Self.removedInitializers.map { ($0, try $0.pattern()) }

    let found = try SourceLineScanner.matches(
      inSwiftFilesBelow: PackageFiles.file(Self.sourcesPath),
      relativeTo: PackageFiles.root
    ) { line in
      patterns.compactMap { initializer, pattern in
        Self.use(of: initializer, matching: pattern, on: line)
      }
    }

    #expect(found.isEmpty, "\(found)")
  }
}

/// An initializer that the ACP client kit removed.
///
/// The name of an initializer, such as `init(used:fill:)`, is not a word. Thus
/// the whole-word scan of ``RemovedVocabularyTests/removedSymbols`` cannot
/// find a call. This scan finds the argument labels of the initializer, in
/// order, after an open parenthesis on one line.
struct RemovedInitializer: Sendable {
  /// The name of the initializer, such as `init(used:fill:)`.
  let name: String
  /// The argument labels of the initializer, in order.
  let labels: [String]

  /// The pattern that finds the labels of a call.
  ///
  /// For the labels `used` and `fill`, the pattern is
  /// `\(\s*\bused:.*\bfill:`. A `Regex` is not `Sendable`, so each call makes
  /// the value again.
  ///
  /// - Returns: The pattern.
  /// - Throws: An error when the labels do not make a valid pattern.
  func pattern() throws -> Regex<AnyRegexOutput> {
    let labelPatterns = labels.map { "\\b\($0):" }
    return try Regex("\\(\\s*" + labelPatterns.joined(separator: ".*"))
  }
}
