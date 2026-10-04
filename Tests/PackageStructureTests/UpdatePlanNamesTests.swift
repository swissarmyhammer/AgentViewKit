import Foundation
import PackageFileSupport
import Testing

/// Holds the API names of update.md §4.2 and §4.3 equal to the client models
/// that FoundationModelsACPClient `a65af8a` builds.
///
/// update.md first gave the design names of `ConnectionModel`,
/// `SessionModel` and `TranscriptEntry`. The built models use some other
/// names. This suite reads each code span of the two sections, and fails for
/// a name that the built models and their ACP types do not have.
///
/// Delete this suite with update.md in the documents task.
@Suite struct UpdatePlanNamesTests {
  /// The plan file.
  static let planPath = "update.md"

  /// The heading prefix of the session model section.
  static let sessionSectionPrefix = "### 4.2 "

  /// The heading prefix of the connection model section.
  static let connectionSectionPrefix = "### 4.3 "

  /// The prefix of a line that ends a section: each Markdown heading.
  static let headingPrefix = "#"

  /// The mark of a heading that still gives the design names.
  static let designMark = "(design)"

  /// The stale status that the decisions table gave before the models were
  /// built.
  static let staleBuildStatus = "not built yet"

  /// The prefix of a Markdown bullet line.
  static let bulletPrefix = "- "

  /// The words of a block that names the set of open session models.
  static let openSetWords = "open set"

  /// The code span of the set of open session models.
  static let openSetSpan = "`openSessions`"

  /// The public API of the client models at `a65af8a`, in
  /// `Sources/FoundationModelsACPClient/Model/` and
  /// `Sources/FoundationModelsACPClient/PendingElicitation.swift`.
  static let clientModelNames: Set<String> = [
    // Types.
    "ConnectionModel", "SessionModel", "TranscriptEntry", "TranscriptEntry.ID",
    "UserMessageEntry", "AgentMessageEntry", "ThoughtEntry", "ToolCallEntry", "TerminalEntry",
    "PlanTranscriptEntry", "UnknownEntry", "CompactionEntry", "ErrorEntry", "SessionNotice",
    "SessionHistory", "SendState", "ConnectionState", "AuthState", "ConnectionModelError",
    "PendingElicitation", "PendingPermissionRequest",
    // Enumeration cases.
    ".userMessage", ".agentMessage", ".thought", ".toolCall", ".terminal", ".plan", ".unknown",
    ".compaction", ".error", ".wire", ".local", ".pending", ".sent", ".failed", ".disconnected",
    ".connecting", ".connected", ".notRequired", ".required", ".authenticated", ".live",
    ".retained(replayFrom:)", "ConnectionModelError.unsupported(method:)",
    // SessionModel.
    "sessionId", "transcript", "availableCommands", "configOptions", "usage", "agentState",
    "sessionInfo", "notices", "dismissNotice(_:)", "hasMissedUpdates", "isReplaying", "history",
    "isClosed", "updateTap()", "flushPendingChunks()", "defaultCoalescingCadence",
    "prompt(_:meta:)", "cancel(meta:)", "setConfigOption(_:)", "appendError(code:message:data:)",
    "pendingPermissions", "pendingElicitations", "selectPermission(_:option:)",
    "cancelPermission(_:)", "acceptElicitation(_:content:)", "declineElicitation(_:)",
    "cancelElicitation(_:)", "cancelAllPending()",
    // Entry objects.
    "TranscriptEntry.id", "content", "messageId", "sendState", "name", "title",
    "ToolCallEntry.linkedElicitationIDs", "bytes", "text", "planId", "entries", "code",
    "message", "data", "meta",
    // PendingElicitation.
    "requestId", "requestMethod", "toolCallId",
    // ConnectionModel.
    "init(coalescingCadence:clock:logger:)", "connect(over:logger:bufferLimits:client:)", "state",
    "openSessions", "session(for:)", "sessions", "refreshSessions(cwd:)", "loadMoreSessions()",
    "hasMoreSessions", "close(_:)", "deleteSession(_:)", "newSession(_:)", "resumeSession(_:)",
    "initialize(_:)", "initializeResponse", "agentCapabilities", "authMethods", "authState",
    "login(_:)", "logout(_:)", "canListSessions", "canResumeSessions", "canCloseSessions",
    "canDeleteSessions", "canLogout",
    // Parameter labels of connect(over:logger:bufferLimits:client:).
    "bufferLimits", "client",
  ]

  /// The ACP types of FoundationModelsACP `27419fa` that the two sections
  /// name.
  static let acpNames: Set<String> = [
    "SessionMergeEngine", "SessionEntry.ID", "MessageId", "SessionId", "StateUpdate",
    "IdleStateUpdate", "StopReason", "stopReason", ".running", ".idle", ".requiresAction",
    "AvailableCommand", "SessionConfigOption", "UsageUpdate", "SessionInfoUpdate", "SessionInfo",
    "SessionUpdate", "NewSessionRequest", "ResumeSessionRequest", "PromptResponse",
    "ClientSideConnection", "ClientSideConnection.closeSession", "SessionUpdateBufferLimits",
    "PendingPromptCorrelator", "Client", "RequestError", "JSONValue", "UUID", "additionalDirectories",
    "mcpServers", "updatedAt",
  ]

  /// The wire names of ACP methods, updates and fields that the two sections
  /// name.
  static let wireNames: Set<String> = [
    "initialize", "session/new", "session/resume", "session/prompt", "session/cancel",
    "session/set_config_option", "session/close", "session/delete", "session/list", "auth/login",
    "auth/logout", "agent_message_chunk", "agent_thought_chunk", "user_message",
    "session_info_update", "_meta", "cwd", "session", "delete", "terminal",
  ]

  /// The Swift attributes and literals that the two sections name.
  static let swiftNames: Set<String> = ["@MainActor", "@Observable", "true", "false", "nil"]

  /// The names that the task gave as differences from the design. Each one
  /// must be in the two sections.
  static let knownDifferences = [
    "openSessions", "connect(over:logger:bufferLimits:client:)", "CompactionEntry", "ErrorEntry",
    "SessionNotice", "dismissNotice(_:)", "updateTap()", "appendError(code:message:data:)",
    "ToolCallEntry.linkedElicitationIDs", "canListSessions", "canResumeSessions",
    "canCloseSessions", "canDeleteSessions", "canLogout",
  ]

  /// One code span: the text between two backticks on one line.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var codeSpan: Regex<(Substring, span: Substring)> {
    /`(?<span>[^`\n]+)`/
  }

  /// A git commit hash, such as `a65af8a`. A code span with a hash names a
  /// commit, not an API name.
  ///
  /// A `Regex` is not `Sendable`, so each read makes the value again.
  static var commitHash: Regex<Substring> {
    /^[0-9a-f]{7,40}$/
  }

  /// Tells whether a code span names an API: each span that is not a commit
  /// hash.
  ///
  /// - Parameter span: The text of one code span.
  /// - Returns: `false` when the span is a commit hash.
  static func namesAnAPI(_ span: String) -> Bool {
    span.wholeMatch(of: commitHash) == nil
  }

  /// The error when update.md has no heading with a prefix.
  struct MissingHeading: Error {
    /// The heading prefix that no line has.
    let prefix: String
  }

  /// The first line of a Markdown text that starts with a heading prefix.
  ///
  /// - Parameters:
  ///   - prefix: The heading prefix, such as `### 4.2 `.
  ///   - markdown: The Markdown text.
  /// - Returns: The heading line.
  /// - Throws: ``MissingHeading`` when no line starts with `prefix`.
  static func heading(_ prefix: String, in markdown: String) throws -> String {
    guard let heading = markdown.components(separatedBy: "\n").first(where: { $0.hasPrefix(prefix) }) else {
      throw MissingHeading(prefix: prefix)
    }
    return heading
  }

  /// The heading line of the update.md section whose heading starts with
  /// `prefix`.
  ///
  /// - Parameter prefix: The heading prefix, such as `### 4.2 `.
  /// - Returns: The heading line.
  /// - Throws: ``MissingHeading`` when no line starts with `prefix`.
  static func planHeading(_ prefix: String) throws -> String {
    try heading(prefix, in: PackageFiles.text(of: planPath))
  }

  /// The lines of the update.md section whose heading starts with `prefix`.
  ///
  /// - Parameter prefix: The heading prefix, such as `### 4.2 `.
  /// - Returns: The lines after the heading, before the next heading.
  /// - Throws: ``MissingHeading`` when no line starts with `prefix`.
  static func planSection(_ prefix: String) throws -> [String] {
    let plan = try PackageFiles.text(of: planPath)
    return try ReadmeCoverageTests.section(heading(prefix, in: plan), of: plan, endingAt: headingPrefix)
  }

  /// The text of update.md §4.2 and §4.3.
  static func modelSectionsText() throws -> String {
    let lines = try planSection(sessionSectionPrefix) + planSection(connectionSectionPrefix)
    return lines.joined(separator: "\n")
  }

  /// The code spans of a text, in text order.
  ///
  /// - Parameter text: A Markdown text.
  /// - Returns: The text between each pair of backticks on one line.
  static func codeSpans(in text: String) -> [String] {
    text.matches(of: codeSpan).map { String($0.output.span) }
  }

  /// Tells whether a Markdown line starts a new block: a blank line or a
  /// bullet.
  ///
  /// - Parameter line: One line of a section.
  /// - Returns: `true` when the line is blank or starts with ``bulletPrefix``.
  static func startsBlock(_ line: String) -> Bool {
    line.isEmpty || line.hasPrefix(bulletPrefix)
  }

  /// The blocks of some Markdown lines: each bullet and each paragraph.
  ///
  /// - Parameter lines: The lines of a section.
  /// - Returns: The text of each block that is not empty, with its lines
  ///   joined by a newline.
  static func blocks(of lines: [String]) -> [String] {
    let starts = [lines.startIndex] + lines.indices.filter { startsBlock(lines[$0]) }
    let ends = starts.dropFirst() + [lines.endIndex]
    return zip(starts, ends)
      .map { lines[$0..<$1].filter { !$0.isEmpty }.joined(separator: "\n") }
      .filter { !$0.isEmpty }
  }

  @Test func codeSpansReadsTheTextBetweenBackticks() {
    #expect(Self.codeSpans(in: "The `state` and `close(_:)`, not `x`.") == ["state", "close(_:)", "x"])
  }

  @Test(arguments: [("a65af8a", false), ("27419fa", false), ("openSessions", true), ("close(_:)", true)])
  func namesAnAPIDropsACommitHash(span: String, isName: Bool) {
    #expect(Self.namesAnAPI(span) == isName)
  }

  @Test func blocksSplitsAtBulletsAndBlankLines() {
    let lines = ["One", "two", "", "- A", "  b", "- C"]

    #expect(Self.blocks(of: lines) == ["One\ntwo", "- A\n  b", "- C"])
  }

  @Test func eachCodeNameOfTheModelSectionsIsInTheClientModels() throws {
    let known = Self.clientModelNames.union(Self.acpNames).union(Self.wireNames).union(Self.swiftNames)

    let names = Self.codeSpans(in: try Self.modelSectionsText()).filter(Self.namesAnAPI)

    let unknown = Set(names).subtracting(known)

    #expect(unknown.isEmpty, "update.md §4.2 and §4.3 name \(unknown.sorted()), which a65af8a does not have")
  }

  @Test(arguments: knownDifferences)
  func theModelSectionsNameTheBuiltName(name: String) throws {
    #expect(try Self.modelSectionsText().contains("`\(name)`"), "update.md §4.2 and §4.3 do not name `\(name)`")
  }

  @Test func eachOpenSetBlockOfTheConnectionSectionNamesOpenSessions() throws {
    let blocks = Self.blocks(of: try Self.planSection(Self.connectionSectionPrefix))

    let openSetBlocks = blocks.filter { $0.contains(Self.openSetWords) }

    #expect(!openSetBlocks.isEmpty, "update.md §4.3 does not tell the open set")
    #expect(openSetBlocks.allSatisfy { $0.contains(Self.openSetSpan) }, "\(openSetBlocks)")
  }

  @Test(arguments: [sessionSectionPrefix, connectionSectionPrefix])
  func theModelSectionHeadingIsNotTheDesign(prefix: String) throws {
    #expect(!(try Self.planHeading(prefix)).contains(Self.designMark))
  }

  @Test func thePlanGivesNoStaleBuildStatus() throws {
    #expect(!(try PackageFiles.text(of: Self.planPath)).contains(Self.staleBuildStatus))
  }
}
