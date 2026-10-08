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
/// (`Docs/decisions/acp-client-kit.md`). Some lists also hold the tests, the
/// examples and the README free of their symbols.
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

  /// The kit session model, its records, its stream copy, its turn logic and
  /// its thread actions, with the test helpers on them. The views bind to the
  /// client models directly, so the kit keeps no parallel session state.
  static let removedSessionModelSymbols = [
    // The kit model and its changes.
    "AgentThread", "ThreadItem", "ThreadChange", "ItemPatch", "ThreadInfo", "ThreadInfoPatch",
    "TerminalPatch",
    // The records.
    "ThreadRecord", "ToolCallRecord", "TerminalRecord", "UnknownRecord",
    // The kit stream copy and its second coalescer.
    "StreamingMessage", "StreamingCoalescer", "isLastWhileRunning",
    // The kit turn logic of the composer.
    "ComposerTurn", "EnvironmentComposerTurn",
    // The thread actions, and the thread path of the views.
    "AgentThreadActions", "LoggingThreadActions", "threadActions", "ConversationSource",
    "ToolCallSource", "TerminalSource",
    // The test helpers on the kit model.
    "NoopThreadActions", "ThreadFixtures", "threadViewHarness",
  ]

  /// The kit copies of the ACP value types, and the kit types that only served
  /// these copies. The views read the ACP values that the client models hold,
  /// so no kit code converts an ACP value into a kit copy.
  static let removedValueCopySymbols = [
    // The thread state, the commands, the config options and the usage.
    "ThreadState", "SlashCommand", "ConfigOption", "ConfigOptionID", "ConfigValue",
    "SelectChoices", "SelectOption", "SelectGroup", "ContextUsage",
    // The patch field, the wire value protocol and the session summary.
    "PatchField", "WireValueEnum", "SessionSummary",
    // The kit content block parts, and the view input of the two block kinds.
    "ResourceIcon", "BlockSource",
  ]

  /// The names of the ACP value types that the kit copied. No source of the
  /// kit library declares a type with one of these names, so each name in a
  /// kit source is the ACP type.
  static let acpValueTypeNames = [
    "JSONValue", "StopReason", "ToolKind", "ToolCallStatus", "ContentBlock",
    "Annotations", "ImageContent", "AudioContent", "ResourceLink", "EmbeddedResource",
    "PlanEntry", "AuthMethod", "SessionInfo", "AvailableCommand", "SessionConfigOption",
    "PatchField",
  ]

  /// The pattern that finds the declaration of a type with a name: a
  /// `struct`, an `enum`, a `class`, an `actor`, a `protocol` or a
  /// `typealias`.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Parameter name: The type name.
  /// - Returns: The pattern.
  static func typeDeclaration(named name: String) -> Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      ChoiceOf {
        "struct"
        "enum"
        "class"
        "actor"
        "protocol"
        "typealias"
      }
      OneOrMore(.whitespace)
      name
      Anchor.wordBoundary
    }
  }

  /// Finds each declaration of a type with one of some names on one line of a
  /// Swift file.
  ///
  /// - Parameters:
  ///   - names: The type names.
  ///   - line: The line.
  /// - Returns: The declarations, in name order.
  static func declarations(of names: [String], on line: SourceLine) -> [RemovedSymbolUse] {
    uses(of: names, on: line, matching: typeDeclaration(named:))
  }

  @Test func declarationsFindEachKindOfTypeDeclaration() {
    let source = """
      public nonisolated enum JSONValue: Sendable {
      struct ContentBlock {
      typealias StopReason = Int
      extension FoundationModelsACP.JSONValue {
      struct ContentBlockView: View {
      let block: ContentBlock
      """

    let found = SourceLineScanner.matches(inSource: source, file: "A.swift") { line in
      Self.declarations(of: ["JSONValue", "ContentBlock", "StopReason"], on: line)
    }

    #expect(
      found == [
        RemovedSymbolUse(file: "A.swift", line: 1, symbol: "JSONValue"),
        RemovedSymbolUse(file: "A.swift", line: 2, symbol: "ContentBlock"),
        RemovedSymbolUse(file: "A.swift", line: 3, symbol: "StopReason"),
      ])
  }

  @Test func theKitDeclaresNoTypeWithTheNameOfAnACPValueType() throws {
    let found = try SourceLineScanner.matches(
      inSwiftFilesBelow: PackageFiles.file(Self.kitSourcesPath),
      relativeTo: PackageFiles.root
    ) { line in
      Self.declarations(of: Self.acpValueTypeNames, on: line)
    }

    #expect(found.isEmpty, "\(found)")
  }

  @Test func noFileUsesTheRemovedValueCopies() throws {
    let found =
      try Self.uses(of: Self.removedValueCopySymbols, below: Self.swiftPaths)
      + Self.uses(of: Self.removedValueCopySymbols, inFile: Self.readmePath)

    #expect(found.isEmpty, "\(found)")
  }

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

  /// The pattern that finds a use of the removed `actions:` input of
  /// `AgentThreadView`: a call of
  /// `AgentThreadView(session:connection:actions:)`, also a call over more
  /// lines, or a DocC link to the initializer.
  ///
  /// The views call the methods of the client models, so the host gives no
  /// actions. A `Regex` is not `Sendable`, so each call makes the value again.
  /// The pattern uses simple word boundaries, because the default boundaries
  /// do not break at the `:` in `connection:actions:`.
  ///
  /// - Returns: The pattern.
  static func threadActionsInputUse() -> Regex<Substring> {
    #/\bAgentThreadView(?:/init)?\([^)]*\bactions:/#
      .wordBoundaryKind(.simple)
  }

  /// The directory of the Swift files of the kit library.
  static let kitSourcesPath = "Sources/AgentViewKit"

  /// The `@Observable` classes that the kit can declare. Each one holds view
  /// state only, and the comment names that state. No class holds a value
  /// that `ConnectionModel`, `SessionModel` or a `TranscriptEntry` object
  /// holds.
  static let allowedObservableClasses: Set<String> = [
    // The focus of VoiceOver.
    "AccessibilityFocusMover",
    // The selected citation.
    "CitationSelection",
    // The selected lines of a diff.
    "DiffLineSelection",
    // The open state of the rows, and of one row (`ExpandedBlocksStore.Entry`).
    "ExpandedBlocksStore", "Entry",
    // The selected attachment of the inspector.
    "InspectorSelection",
    // The scroll position of the conversation.
    "ScrollAnchorManager",
  ]

  /// The pattern that finds the declaration of an `@Observable` class and
  /// captures its name. Other attributes and the modifiers can stand between
  /// the attribute and `class`. An attribute can have an argument list, such
  /// as `@available(macOS 14, *)`.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Returns: The pattern.
  static func observableClassDeclaration() -> Regex<(Substring, Substring)> {
    #/@Observable\s+(?:@\w+(?:\([^)]*\))?\s+)*(?:(?:public|package|internal|fileprivate|private|final|nonisolated)\s+)*class\s+(\w+)/#
  }

  /// The names of the `@Observable` classes that a Swift source declares.
  ///
  /// - Parameter source: The text of a Swift file.
  /// - Returns: The class names, in source order.
  static func observableClassNames(inSource source: String) -> [String] {
    source.matches(of: observableClassDeclaration()).map { String($0.output.1) }
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
  ///   - makePattern: Makes the pattern of one symbol. The default finds the
  ///     symbol as a whole word.
  /// - Returns: The uses, in symbol order.
  static func uses(
    of symbols: [String],
    on line: SourceLine,
    matching makePattern: (String) -> Regex<Substring> = wholeWord
  ) -> [RemovedSymbolUse] {
    symbols
      .filter { line.text.contains(makePattern($0)) }
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

  @Test func noFileUsesTheRemovedSessionModel() throws {
    let found =
      try Self.uses(of: Self.removedSessionModelSymbols, below: Self.swiftPaths)
      + Self.uses(of: Self.removedSessionModelSymbols, inFile: Self.readmePath)

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

  @Test func theThreadActionsPatternFindsACallOverTwoLinesAndADocLink() {
    let pattern = Self.threadActionsInputUse()

    #expect("AgentThreadView(\n  session: s, connection: c,\n  actions: a)".contains(pattern))
    #expect("``AgentThreadView/init(session:connection:actions:)``".contains(pattern))
    #expect(!"AgentThreadView(session: s, connection: c)".contains(pattern))
    #expect(!"PromptInputView(actions: a)".contains(pattern))
  }

  @Test func noFileGivesThreadActionsToTheThreadView() throws {
    let users = try Self.fileNames(matching: Self.threadActionsInputUse)

    #expect(users.isEmpty, "\(users)")
  }

  @Test func observableClassNamesFindsTheNameAfterTheAttributesAndModifiers() {
    let source = """
      @MainActor
      @Observable
      public final class Store {}
      @Observable fileprivate final class Row {}
      /// An `@Observable` class.
      final class Plain {}
      """

    #expect(Self.observableClassNames(inSource: source) == ["Store", "Row"])
    let withArguments = """
      @Observable
      @available(macOS 14, *)
      final class Gated {}
      """
    #expect(Self.observableClassNames(inSource: withArguments) == ["Gated"])
  }

  @Test func eachObservableClassOfTheKitHoldsViewStateOnly() throws {
    let files = try PackageFiles.swiftFiles(in: PackageFiles.file(Self.kitSourcesPath))

    let names = try files.flatMap { file in
      Self.observableClassNames(inSource: try String(contentsOf: file, encoding: .utf8))
    }

    #expect(!names.isEmpty)
    let notAllowed = names.filter { !Self.allowedObservableClasses.contains($0) }.sorted()
    #expect(notAllowed.isEmpty, "\(notAllowed)")
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
