import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests that the kit shows one SF Symbol for each concept, and that two
/// different concepts do not share a symbol.
///
/// Each test reads the symbol names from the views of the kit: the banners,
/// the stop reasons, the plan, the diff, the command output, the message
/// actions, the send state, the tool rows and the error card.
@Suite @MainActor struct SymbolConceptTests {
  /// The meaning of a symbol. Each concept must have one symbol, and each
  /// symbol must have one concept.
  enum Concept: String {
    case pending, inProgress, completed, error, cancelled, unknown, warning, information
    case read, edit, delete, move, search, terminal, reasoning, web, switchMode, tool
    case copy, copyThread, share, reload
    case addedFile, deletedFile, modifiedFile, renamedFile, copiedFile
    case userAction, maxTokens, maxTurnRequests, refusal
    case truncated, repeated, reasoningLimit, noOutput, stalled
    case closed, replaying, partialHistory, disconnected, signal
  }

  /// One place of the kit that shows a symbol.
  struct Use: CustomStringConvertible {
    /// The meaning of the symbol at this place.
    let concept: Concept
    /// The name of the place, for the failure text.
    let place: String
    /// The SF Symbol name that the place shows.
    let name: String

    var description: String { "\(place) (\(concept.rawValue)): \(name)" }
  }

  /// A failure for the connection banner.
  struct ReadFailure: Error {}

  // MARK: - The uses

  /// The symbols of the tool rows: each kind and each status.
  static func toolUses() -> [Use] {
    let kinds: [(FoundationModelsACP.ToolKind, Concept)] = [
      (.read, .read), (.edit, .edit), (.delete, .delete), (.move, .move), (.search, .search),
      (.execute, .terminal), (.think, .reasoning), (.fetch, .web), (.switchMode, .switchMode),
      (.other, .tool), (.unknown("custom_kind"), .unknown),
    ]
    let statuses: [(FoundationModelsACP.ToolCallStatus, Concept)] = [
      (.pending, .pending), (.inProgress, .inProgress), (.completed, .completed), (.failed, .error),
      (.cancelled, .cancelled), (.unknown(ToolStatusSymbol.lostWireValue), .warning),
      (.unknown("custom_status"), .unknown),
    ]
    return kinds.map { Use(concept: $1, place: "tool kind \($0)", name: ToolKindSymbol.name(for: $0)) }
      + statuses.map { Use(concept: $1, place: "tool status \($0)", name: ToolStatusSymbol.name(for: $0)) }
  }

  /// The symbols of the agent state banner: each state and each ACP stop
  /// reason.
  static func stateBannerUses() throws -> [Use] {
    let states: [(String, Concept)] = [
      (#"{"state": "running"}"#, .inProgress),
      (#"{"state": "requires_action"}"#, .userAction),
      (#"{"state": "idle"}"#, .completed),
      (#"{"state": "idle", "stopReason": "end_turn"}"#, .completed),
      (#"{"state": "idle", "stopReason": "cancelled"}"#, .cancelled),
      (#"{"state": "idle", "stopReason": "max_tokens"}"#, .maxTokens),
      (#"{"state": "idle", "stopReason": "max_turn_requests"}"#, .maxTurnRequests),
      (#"{"state": "idle", "stopReason": "refusal"}"#, .refusal),
      (#"{"state": "idle", "stopReason": "error"}"#, .error),
      (#"{"state": "custom_state"}"#, .unknown),
    ]
    return try states.map { json, concept in
      let message = StateBanner.message(for: try StateBannerStopReasonTests.decodeState(json))
      return Use(concept: concept, place: "state banner \(message.identifier)", name: message.symbolName)
    }
  }

  /// The symbols of the extension stop reasons, and of a stop reason that
  /// the kit does not know.
  static func stopReasonUses() -> [Use] {
    let reasons: [(String, Concept)] = [
      ("_truncated", .truncated), ("_ended_in_reasoning", .reasoning), ("_repeated", .repeated),
      ("_reasoning_limit", .reasoningLimit), ("_error", .error), ("_no_output", .noOutput),
      ("_stalled", .stalled), ("_custom", .unknown),
    ]
    return reasons.map { wireValue, concept in
      let message = StateBanner.message(forUnknownStopReason: wireValue)
      return Use(concept: concept, place: "stop reason \(wireValue)", name: message.symbolName)
    }
  }

  /// The symbols of the other banners: the notices, the connection and the
  /// session stream.
  static func otherBannerUses() -> [Use] {
    let severities: [(NoticeSeverity, Concept)] = [
      (.info, .information), (.warning, .warning), (.error, .error), (.unknown("custom"), .unknown),
    ]
    let connection: [(ConnectionState, Concept)] = [(.disconnected, .disconnected), (.failed(ReadFailure()), .error)]
    let stream: [(StateBanner.Message, Concept)] = [
      (SessionStreamBanner.closedMessage, .closed), (SessionStreamBanner.replayingMessage, .replaying),
      (SessionStreamBanner.missedUpdatesMessage, .warning),
      (SessionStreamBanner.partialHistoryMessage, .partialHistory),
    ]
    return severities.map { Use(concept: $1, place: "notice \($0)", name: NoticeBanner.symbolName(for: $0)) }
      + connection.compactMap { state, concept in
        AgentConnectionBanner.makeMessage(for: state).map {
          Use(concept: concept, place: "connection \($0.identifier)", name: $0.symbolName)
        }
      }
      + stream.map { Use(concept: $1, place: "session stream \($0.identifier)", name: $0.symbolName) }
  }

  /// The symbols of the status of a plan entry.
  static func planUses() -> [Use] {
    let statuses: [(FoundationModelsACP.PlanEntryStatus, Concept)] = [
      (.pending, .pending), (.inProgress, .inProgress), (.completed, .completed), (.cancelled, .cancelled),
      (.unknown("custom_status"), .unknown),
    ]
    return statuses.map { Use(concept: $1, place: "plan \($0)", name: TaskListView.statusSymbol($0)) }
  }

  /// The symbols of the file operations of a diff.
  static func diffUses() -> [Use] {
    let operations: [(DiffSummary.Operation, Concept)] = [
      (.added, .addedFile), (.deleted, .deletedFile), (.modified, .modifiedFile),
      (.renamed(from: "old.swift"), .renamedFile), (.copied(from: "old.swift"), .copiedFile),
      (.unknown("custom"), .unknown),
    ]
    return operations.map { Use(concept: $1, place: "diff \($0)", name: DiffView.symbolName(for: $0)) }
  }

  /// The symbols of the footer of a command output and of a terminal.
  static func commandOutputUses() -> [Use] {
    let outcomes: [(CommandOutputView.ExitOutcome, Concept)] = [(.success, .completed), (.failure, .error)]
    let exits: [(TerminalView.ExitSummary, Concept)] = [(.signal("SIGINT"), .signal), (.unknown, .unknown)]
    return outcomes.map { Use(concept: $1, place: "command output \($0)", name: $0.symbolName) }
      + exits.map { Use(concept: $1, place: "terminal exit \($0)", name: $0.symbolName) }
  }

  /// The symbols of the buttons of a message.
  static func messageActionUses() -> [Use] {
    let actions: [(MessageActions.Action, Concept)] = [
      (.copy, .copy), (.copyThread, .copyThread), (.export, .share), (.retry, .reload), (.edit, .edit),
    ]
    return actions.map { Use(concept: $1, place: "message action \($0)", name: $0.systemImage) }
  }

  /// The symbols of the send state of a user message.
  static func sendStateUses() -> [Use] {
    let states: [(SendState, Concept)] = [(.pending, .pending), (.sent, .completed), (.failed, .error)]
    return states.map {
      Use(concept: $1, place: "send state \($0)", name: UserMessageView.SendStateLabel.symbol(of: $0))
    }
  }

  /// The symbols of the error card and of the requests to the user.
  static func cardUses() -> [Use] {
    [
      Use(concept: .error, place: "error card", name: ErrorView.content(code: 1, message: "failed").symbolName),
      Use(concept: .userAction, place: "permission title", name: PermissionView.symbol),
      Use(concept: .tool, place: "permission tool call", name: PermissionView.toolCallSymbol),
      Use(concept: .terminal, place: "permission command", name: PermissionView.commandSymbol),
      Use(concept: .tool, place: "tool menu", name: ToolToggles.menuSymbolName),
      Use(concept: .completed, place: "answered tab", name: ElicitationLayout.answeredSymbol),
      Use(concept: .warning, place: "URL consent warning", name: ElicitationURLConsentView.warningSymbol),
    ]
  }

  /// Each use that the tests read.
  static func allUses() throws -> [Use] {
    toolUses() + (try stateBannerUses()) + stopReasonUses() + otherBannerUses() + planUses() + diffUses()
      + commandOutputUses() + messageActionUses() + sendStateUses() + cardUses()
  }

  // MARK: - The tests

  @Test func eachConceptShowsOneSymbol() throws {
    let byConcept = Dictionary(grouping: try Self.allUses(), by: \.concept)

    let mixed = byConcept.values.filter { Set($0.map(\.name)).count > 1 }

    #expect(mixed.isEmpty, "\(mixed)")
  }

  @Test func twoConceptsDoNotShareASymbol() throws {
    let byName = Dictionary(grouping: try Self.allUses(), by: \.name)

    let shared = byName.values.filter { Set($0.map(\.concept)).count > 1 }

    #expect(shared.isEmpty, "\(shared)")
  }

  @Test func theSwitchModeKindAndTheMaxTurnRequestsBannerShowDifferentSymbols() throws {
    let banner = StateBanner.message(
      for: try StateBannerStopReasonTests.idleUpdate(stopReason: "max_turn_requests"))

    #expect(ToolKindSymbol.name(for: .switchMode) != banner.symbolName)
  }
}
