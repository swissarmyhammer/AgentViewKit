import EditorInspector
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

// The `Inspectable` conformances of the transcript entries of
// FoundationModelsACPClient, so a host shows any entry in an EditorKit
// `InspectorView` (`InspectorView(entry)`, or `InspectorView([any
// Inspectable])` for a selection of several kinds).
//
// Each row is read-only: the agent owns each entry. Each get block reads the
// entry when the row draws, so an update of the agent redraws the row. The
// rows use the kinds of EditorKit's inspector only; no AgentViewKit view
// goes inside an inspector. The fields that wait for an EditorKit kind of
// ^eghwsfh are not here yet: the tool call status (the status token), the
// locations and the working directory (the path kind), and the duration of
// an entry (the duration kind).

extension ObservableTranscriptEntry {
  /// The group of the start and end times of the entry, as the client saw
  /// them.
  static var timeGroup: FieldGroup<Self> {
    FieldGroup(InspectionLabel.time) {
      Field(InspectionLabel.started) { $0.timing.startedAt }
      Field(InspectionLabel.ended) { $0.timing.endedAt }
    }
  }
}

extension ToolCallEntry: @retroactive Inspectable {
  /// The title, the kind and the tool name of the call, and its times.
  public static var inspection: Inspection<ToolCallEntry> {
    Inspection(title: String(localized: "Tool Call", bundle: .module), name: { $0.shownTitle }) {
      FieldGroup(FieldLabel(localized: "Tool Call", bundle: .module)) {
        Field(InspectionLabel.title) { $0.shownTitle }
        Field(FieldLabel(localized: "Kind", bundle: .module)) { $0.shownKind.wireValue }
        Field(FieldLabel(localized: "Tool", bundle: .module)) { $0.name }
      }
      timeGroup
    }
  }
}

extension TerminalEntry: @retroactive Inspectable {
  /// The command, the exit and the output of the terminal, and its times.
  public static var inspection: Inspection<TerminalEntry> {
    let title = String(localized: "Terminal", bundle: .module)
    return Inspection(title: title, name: { $0.command ?? title }) {
      FieldGroup(FieldLabel(localized: "Terminal", bundle: .module)) {
        Field(FieldLabel(localized: "Command", bundle: .module)) { $0.command }
        Field(FieldLabel(localized: "Exit Status", bundle: .module)) { entry in
          entry.exitStatus.map { TerminalView.ExitSummary(code: $0.exitCode, signal: $0.signal).label }
        }
        Field(FieldLabel(localized: "Output", bundle: .module)) { $0.text }
          .multiline()
      }
      timeGroup
    }
  }
}

/// The shared inspection of the message entries: the user message, the
/// agent message, the thought and the message between two sessions.
enum MessageInspection {
  /// The inspection of a message entry: its text and its id, the fields
  /// `extra` gives after them, and its times.
  ///
  /// - Parameters:
  ///   - title: The title of a block of the entry type.
  ///   - content: The content blocks of an entry.
  ///   - messageID: The id of the message of an entry, or `nil` while no
  ///     agent gave one.
  ///   - extra: The fields that follow the text, before the id.
  /// - Returns: The inspection.
  static func inspection<Entry: ObservableTranscriptEntry>(
    title: String, content: @escaping @MainActor (Entry) -> [FoundationModelsACP.ContentBlock],
    messageID: @escaping @MainActor (Entry) -> String?,
    @FieldBuilder<Entry> extra: () -> [AnyField<Entry>] = { [] }
  ) -> Inspection<Entry> {
    let fields = textField(content) + extra() + idField(messageID)
    return Inspection(title: title) {
      // A closure with a `return` takes no builder: the fields are built.
      FieldGroup(InspectionLabel.message) { return fields }
      Entry.timeGroup
    }
  }

  /// The text row of a message entry.
  ///
  /// - Parameter content: The content blocks of an entry.
  /// - Returns: The row.
  @FieldBuilder<Entry>
  private static func textField<Entry: AnyObject>(
    _ content: @escaping @MainActor (Entry) -> [FoundationModelsACP.ContentBlock]
  ) -> [AnyField<Entry>] {
    Field(InspectionLabel.text) { InspectionText.text(of: content($0)) }
      .multiline()
  }

  /// The id row of a message entry.
  ///
  /// - Parameter messageID: The id of the message of an entry, or `nil`.
  /// - Returns: The row.
  @FieldBuilder<Entry>
  private static func idField<Entry: AnyObject>(_ messageID: @escaping @MainActor (Entry) -> String?) -> [AnyField<Entry>] {
    Field(InspectionLabel.messageID) { messageID($0) }
  }
}

extension UserMessageEntry: @retroactive Inspectable {
  /// The text, the send state and the id of the message, and its times.
  public static var inspection: Inspection<UserMessageEntry> {
    MessageInspection.inspection(
      title: String(localized: "User Message", bundle: .module), content: { $0.content },
      messageID: { $0.messageId?.rawValue }
    ) {
      Field(FieldLabel(localized: "Send State", bundle: .module)) { InspectionText.sendState($0.sendState) }
    }
  }
}

extension AgentMessageEntry: @retroactive Inspectable {
  /// The text and the id of the message, and its times.
  public static var inspection: Inspection<AgentMessageEntry> {
    MessageInspection.inspection(
      title: String(localized: "Agent Message", bundle: .module), content: { $0.content },
      messageID: { $0.messageId?.rawValue })
  }
}

extension ThoughtEntry: @retroactive Inspectable {
  /// The text and the id of the thought, and its times.
  public static var inspection: Inspection<ThoughtEntry> {
    MessageInspection.inspection(
      title: String(localized: "Thought", bundle: .module), content: { $0.content },
      messageID: { $0.messageId?.rawValue })
  }
}

extension SessionMessageEntry: @retroactive Inspectable {
  /// The text of the message between two sessions, its sender and its
  /// recipient, its id, and its times.
  public static var inspection: Inspection<SessionMessageEntry> {
    MessageInspection.inspection(
      title: String(localized: "Session Message", bundle: .module), content: { $0.content },
      messageID: { $0.messageId.rawValue }
    ) {
      Field(FieldLabel(localized: "From Session", bundle: .module)) { $0.senderSessionId?.rawValue }
      Field(FieldLabel(localized: "To Session", bundle: .module)) { $0.recipientSessionId?.rawValue }
    }
  }
}

extension PlanTranscriptEntry: @retroactive Inspectable {
  /// The steps of the plan, each with its status, and its times.
  public static var inspection: Inspection<PlanTranscriptEntry> {
    let title = String(localized: "Plan", bundle: .module)
    return Inspection(title: title) {
      FieldGroup(FieldLabel(localized: "Plan", bundle: .module)) {
        Field(FieldLabel(localized: "Steps", bundle: .module)) { entry in
          entry.entries.map(InspectionText.step).joined(separator: "\n")
        }
        .multiline()
      }
      timeGroup
    }
  }
}

extension CompactionEntry: @retroactive Inspectable {
  /// The status, the summary and the error of the compaction, and its times.
  public static var inspection: Inspection<CompactionEntry> {
    let title = String(localized: "Compaction", bundle: .module)
    return Inspection(title: title) {
      FieldGroup(FieldLabel(localized: "Compaction", bundle: .module)) {
        Field(InspectionLabel.status) { CompactionEntryView.statusLabel(for: $0.status) }
        Field(FieldLabel(localized: "Summary", bundle: .module)) { InspectionText.text(of: $0.summary) }
          .multiline()
        Field(FieldLabel(localized: "Error", bundle: .module)) { $0.error }
      }
      timeGroup
    }
  }
}

extension ErrorEntry: @retroactive Inspectable {
  /// The code and the message of the error, and its times.
  public static var inspection: Inspection<ErrorEntry> {
    let title = String(localized: "Error", bundle: .module)
    return Inspection(title: title) {
      FieldGroup(FieldLabel(localized: "Error", bundle: .module)) {
        Field(FieldLabel(localized: "Code", bundle: .module)) { $0.code.wireValue }
        Field(InspectionLabel.message) { $0.message }
          .multiline()
      }
      timeGroup
    }
  }
}

extension UnknownEntry: @retroactive Inspectable {
  /// The type of the update that the client does not know, and its times.
  public static var inspection: Inspection<UnknownEntry> {
    Inspection(title: String(localized: "Unknown Update", bundle: .module)) {
      FieldGroup(FieldLabel(localized: "Update", bundle: .module)) {
        Field(FieldLabel(localized: "Type", bundle: .module)) { $0.type }
      }
      timeGroup
    }
  }
}
