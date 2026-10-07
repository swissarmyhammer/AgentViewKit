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
/// (update.md §3, §6). Some lists also hold the tests, the examples and the
/// README free of their symbols.
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
    // The kit connection store. The MCP server views show the `mcpServers`
    // of the client model. The client also has a `ConnectionState`, so that
    // name is not in the list.
    "ConnectionStore", "ConnectionActions", "ConnectionID",
  ]

  /// The symbols of the session controller that the demo app removed. The
  /// demo app binds its views to the client models directly, and it writes
  /// no agent connection into a `ConnectionStore`.
  static let removedDemoSymbols = ["ACPDemoSession", "agentConnectionID"]

  /// The directories of the Swift files of the kit, of the demo app, of
  /// their support targets, and of their tests.
  static let swiftPaths = [sourcesPath, "Tests/AgentViewKitTests", "Examples"]

  /// The README of the package.
  static let readmePath = "README.md"

  /// The ACP adapter that folded the session updates into a kit thread, and
  /// the fixtures of its tests. The views bind to the client models
  /// directly, so no kit code converts a model value into a kit copy.
  static let removedAdapterSymbols = [
    "ACPThreadSource", "SessionUpdateMapping", "ACPSessionList", "TranscriptSeed",
    "ACPThreadActions", "ACPThreadActionsError", "ACPAgentProgram", "SessionUpdateFixtures",
  ]

  /// The pattern that finds a call of the removed thread initializer
  /// `AgentThreadView(thread:actions:)`, also a call over two lines.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Returns: The pattern.
  static func threadInitializerCall() -> Regex<Substring> {
    #/AgentThreadView\(\s*thread:/#
  }

  /// The pattern that finds a use of the removed `workingDirectory:` input
  /// of a view: a call of `AgentThreadView(session:connection:workingDirectory:actions:)`
  /// or of `SessionStreamBanner(session:connection:workingDirectory:)`, also
  /// a call over more lines, or a DocC link to one of the two initializers.
  ///
  /// The views read the working directory and the additional directories
  /// from the session model, so the host does not give them.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again. The
  /// pattern uses simple word boundaries, because the default boundaries do
  /// not break at the `:` in `connection:workingDirectory:`.
  ///
  /// - Returns: The pattern.
  static func workingDirectoryInputUse() -> Regex<Substring> {
    #/\b(?:AgentThreadView|SessionStreamBanner)(?:/init)?\([^)]*\bworkingDirectory:/#
      .wordBoundaryKind(.simple)
  }

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

  /// Finds each use of a removed symbol in the Swift files below some
  /// directories.
  ///
  /// - Parameters:
  ///   - symbols: The removed symbols.
  ///   - paths: The directories, relative to the package root.
  /// - Returns: The uses, in directory order.
  /// - Throws: The error of the scan when a directory cannot be read.
  static func uses(of symbols: [String], below paths: [String]) throws -> [RemovedSymbolUse] {
    try paths.flatMap { path in
      try SourceLineScanner.matches(
        inSwiftFilesBelow: PackageFiles.file(path),
        relativeTo: PackageFiles.root
      ) { line in
        Self.uses(of: symbols, on: line)
      }
    }
  }

  @Test func sourcesUseNoRemovedSymbol() throws {
    let found = try Self.uses(of: Self.removedSymbols, below: [Self.sourcesPath])

    #expect(found.isEmpty, "\(found)")
  }

  /// Finds each use of a removed symbol in one file.
  ///
  /// - Parameters:
  ///   - symbols: The removed symbols.
  ///   - path: The file, relative to the package root.
  /// - Returns: The uses, in line order.
  /// - Throws: The error of the read when the file cannot be read.
  static func uses(of symbols: [String], inFile path: String) throws -> [RemovedSymbolUse] {
    SourceLineScanner.matches(inSource: try PackageFiles.text(of: path), file: path) { line in
      Self.uses(of: symbols, on: line)
    }
  }

  @Test func theDemoAppAndItsTestsUseNoRemovedDemoSymbol() throws {
    let found = try Self.uses(of: Self.removedDemoSymbols, below: Self.swiftPaths)

    #expect(found.isEmpty, "\(found)")
  }

  @Test func noFileUsesTheRemovedACPAdapter() throws {
    let found =
      try Self.uses(of: Self.removedAdapterSymbols, below: Self.swiftPaths)
      + Self.uses(of: Self.removedAdapterSymbols, inFile: Self.readmePath)

    #expect(found.isEmpty, "\(found)")
  }

  @Test func theThreadInitializerPatternFindsACallOverTwoLines() {
    #expect("AgentThreadView(\n  thread: thread, actions: actions)".contains(Self.threadInitializerCall()))
    #expect(!"AgentThreadView(session: session, actions: actions)".contains(Self.threadInitializerCall()))
  }

  /// Finds each Swift file below ``swiftPaths``, and the README, whose text
  /// matches a pattern. The pattern reads the whole text, so it finds a
  /// call over more lines.
  ///
  /// - Parameter makePattern: Makes the pattern. A `Regex` is not
  ///   `Sendable`, so the scan makes the value for each file.
  /// - Returns: The names of the files that match.
  /// - Throws: The error of the scan when a file cannot be read.
  static func fileNames(matching makePattern: () -> Regex<Substring>) throws -> [String] {
    let swiftFiles = try swiftPaths.flatMap { try PackageFiles.swiftFiles(in: PackageFiles.file($0)) }
    let files = swiftFiles + [try PackageFiles.file(readmePath)]
    return try files.filter { file in
      try String(contentsOf: file, encoding: .utf8).contains(makePattern())
    }
    .map(\.lastPathComponent)
  }

  @Test func noFileCallsTheRemovedThreadInitializer() throws {
    let callers = try Self.fileNames(matching: Self.threadInitializerCall)

    #expect(callers.isEmpty, "\(callers)")
  }

  @Test func theWorkingDirectoryPatternFindsACallOverTwoLinesAndADocLink() {
    let pattern = Self.workingDirectoryInputUse()

    #expect("AgentThreadView(\n  session: s, connection: c,\n  workingDirectory: w, actions: a)".contains(pattern))
    #expect("SessionStreamBanner(session: s, connection: c, workingDirectory: w)".contains(pattern))
    #expect("``AgentThreadView/init(session:connection:workingDirectory:actions:)``".contains(pattern))
    #expect(!"AgentThreadView(session: s, connection: c, actions: a)".contains(pattern))
    #expect(!"DemoAgent.makeConnected(workingDirectory: w)".contains(pattern))
  }

  @Test func noFileGivesTheWorkingDirectoryToAView() throws {
    let users = try Self.fileNames(matching: Self.workingDirectoryInputUse)

    #expect(users.isEmpty, "\(users)")
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
