import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient

// The EditorKit symbol of each ACP value that the kit shows as a symbol
// (plan.md §5).
//
// EditorKit's `EditorSymbol` holds the symbol and the tone of each tool kind
// and each status, and `EditorSymbolImage` draws it in the token of the
// theme. EditorKit links no ACP package, so the kit maps each ACP value to its
// EditorKit case here, one time, and each view of the kit draws the case. A
// view that tints a status by its color reads the same case, so a status
// shows one symbol and one color in each view.

nonisolated extension EditorSymbol.ToolKind {
  /// The EditorKit kind of a tool of the ACP kind `kind`.
  ///
  /// - Parameter kind: The ACP type of the tool. Each unknown kind gives the
  ///   unknown kind, so all unknown kinds share one symbol.
  init(_ kind: FoundationModelsACP.ToolKind) {
    switch kind {
    case .read: self = .read
    case .edit: self = .edit
    case .delete: self = .delete
    case .move: self = .move
    case .search: self = .search
    case .execute: self = .execute
    case .think: self = .think
    case .fetch: self = .fetch
    case .switchMode: self = .switchMode
    case .other: self = .other
    case .unknown: self = .unknown
    }
  }
}

nonisolated extension EditorSymbol.Status {
  /// The EditorKit status of a tool call with the ACP status `status`.
  ///
  /// - Parameter status: The ACP progress of the call. The custom status
  ///   ``ToolStatusSymbol/lostWireValue`` gives the lost status, and each
  ///   other unknown status gives the unknown status.
  init(_ status: FoundationModelsACP.ToolCallStatus) {
    switch status {
    case .pending: self = .pending
    case .inProgress: self = .inProgress
    case .paused: self = .paused
    case .completed: self = .completed
    case .failed: self = .failed
    case .cancelled: self = .cancelled
    case .unknown(ToolStatusSymbol.lostWireValue): self = .lost
    case .unknown: self = .unknown
    }
  }

  /// The EditorKit status of a plan entry with the ACP status `status`.
  ///
  /// - Parameter status: The ACP status of the entry. A status that the kit
  ///   does not know gives the unknown status.
  init(_ status: FoundationModelsACP.PlanEntryStatus) {
    switch status {
    case .pending: self = .pending
    case .inProgress: self = .inProgress
    case .completed: self = .completed
    case .cancelled: self = .cancelled
    case .unknown: self = .unknown
    }
  }

  /// The EditorKit status of a context compaction with `status`.
  ///
  /// - Parameter status: The status of the compaction. A compaction with no
  ///   reported status, or with a status that the kit does not know, gives
  ///   the unknown status.
  init(_ status: CompactionStatus) {
    switch status {
    case .inProgress: self = .inProgress
    case .completed: self = .completed
    case .failed: self = .failed
    case .cancelled: self = .cancelled
    case .unknown: self = .unknown
    }
  }

  /// The EditorKit status of a user message with the send state `state`.
  ///
  /// - Parameter state: The send state of a `UserMessageEntry`: a message
  ///   that the agent did not link yet is pending, a sent message is
  ///   completed, and a message whose prompt failed is failed.
  init(_ state: SendState) {
    switch state {
    case .pending: self = .pending
    case .sent: self = .completed
    case .failed: self = .failed
    }
  }

  /// The EditorKit status of a command with `outcome`.
  ///
  /// - Parameter outcome: The outcome of the command: a command that
  ///   completed is completed, and a command that failed is failed.
  init(_ outcome: CommandOutputView.ExitOutcome) {
    switch outcome {
    case .success: self = .completed
    case .failure: self = .failed
    }
  }
}

nonisolated extension EditorSymbol.Tone {
  /// The tone of the symbol of a plan entry with `priority`.
  ///
  /// The theme has no priority tokens, so the tone takes the token that has
  /// the same strength: the error token shows high importance, the warning
  /// token shows medium importance, and the pending token shows low
  /// importance.
  ///
  /// - Parameter priority: The ACP priority of the entry. A priority that the
  ///   kit does not know reads as low.
  init(_ priority: FoundationModelsACP.PlanEntryPriority) {
    switch priority {
    case .high: self = .error
    case .medium: self = .warning
    case .low, .unknown: self = .pending
    }
  }
}
