import EditorInspector
import EditorSwiftUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

// The inspections of the transcript entries of FoundationModelsACPClient, so
// a host shows any entry in an EditorKit `InspectorView`
// (`InspectorView(entry)`, or `InspectorView([any Inspectable])` with
// `InspectedClientModel(entry)` for a selection of several kinds). Each entry
// is an ``InspectableClientModel``: the inspector shows it through an
// ``InspectedClientModel``, whose id is the readable object id of the entry,
// such as `tool-call-call_1` (``InspectableClientModel/inspectorObjectID``).
//
// Each row is read-only: the agent owns each entry. Each get block reads the
// entry when the row draws, so an update of the agent redraws the row. The
// rows use the kinds of EditorKit's inspector only; no AgentViewKit view
// goes inside an inspector. A status is EditorKit's status token
// (`EditorStatus`), which the inspector shows as a read-only `.status` row.
// The working directory of a terminal is EditorKit's path kind
// (``InspectionPath``). The locations of a tool call are not here yet: they
// are a list of paths, which EditorKit's inspector has no kind for
// (^b9xgnm7).

extension ObservableTranscriptEntry where Self: InspectableClientModel {
  /// The format of the duration row of ``timeGroup``: minutes and seconds,
  /// such as "1:15".
  ///
  /// The row is EditorKit's `.duration` kind, which shows a `DurationText`
  /// in a `DurationFieldFormat`. That format is the positional time of a
  /// duration, not the abbreviated units of the time line of a transcript
  /// row (``EntryTimingView/lineDurationStyle(locale:)``).
  static var durationRowFormat: DurationFieldFormat { DurationFieldFormat(units: .minutesSeconds) }

  /// The group of the start and end times of the entry, as the client saw
  /// them, and the duration between them.
  ///
  /// The duration row is EditorKit's duration kind, in
  /// ``durationRowFormat``. It shows where the transcript row shows a
  /// duration (``EntryTimingView/shownDuration(_:)``): for an entry that has
  /// ended, after at least ``EntryTimingView/shortestShownDuration`` (half a
  /// second). A shorter duration rounds to zero seconds and shows no row.
  static var timeGroup: FieldGroup<InspectedClientModel<Self>> {
    FieldGroup(InspectionLabel.time) {
      Field(InspectionLabel.started) { $0.model.timing.startedAt }
      Field(InspectionLabel.ended) { $0.model.timing.endedAt }
      Field(InspectionLabel.duration) { Duration.seconds($0.model.timing.duration ?? .zero) }
        .durationFormat(durationRowFormat)
        .visible { EntryTimingView.shownDuration($0.model.timing.duration) != nil }
    }
  }
}

extension ToolCallEntry: InspectableClientModel {
  /// The title, the status, the kind and the tool name of the call, and its
  /// times.
  public static var inspection: Inspection<InspectedClientModel<ToolCallEntry>> {
    .named(
      FieldLabel(localized: "Tool Call", bundle: .module), id: ClientInspectionID.toolCall,
      name: { $0.model.shownTitle }
    ) {
      Field(InspectionLabel.title) { $0.model.shownTitle }
      Field(InspectionLabel.status) { EditorStatus($0.model.shownStatus) }
      Field(FieldLabel(localized: "Kind", bundle: .module)) { $0.model.shownKind.wireValue }
      Field(FieldLabel(localized: "Tool", bundle: .module)) { $0.model.name }
    } more: {
      timeGroup
    }
  }
}

extension TerminalEntry: InspectableClientModel {
  /// The command, the exit, the output and the working directory of the
  /// terminal, and its times.
  public static var inspection: Inspection<InspectedClientModel<TerminalEntry>> {
    .named(
      FieldLabel(localized: "Terminal", bundle: .module), id: ClientInspectionID.terminal,
      name: { $0.model.command }
    ) {
      Field(FieldLabel(localized: "Command", bundle: .module)) { $0.model.command }
      Field(FieldLabel(localized: "Exit Status", bundle: .module)) { entry in
        entry.model.exitStatus.map { TerminalView.ExitSummary(code: $0.exitCode, signal: $0.signal).label }
      }
      Field(FieldLabel(localized: "Output", bundle: .module)) { $0.model.text }
        .multiline()
      InspectionPath.workingDirectory { $0.model.cwd }
    } more: {
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
  ///   - id: The id of the inspection: the view part of the scheme id of each
  ///     row, such as `user-message`. It never follows the locale.
  ///   - title: The title of a block of the entry type.
  ///   - content: The content blocks of an entry.
  ///   - messageID: The id of the message of an entry, or `nil` while no
  ///     agent gave one.
  ///   - extra: The fields that follow the text, before the id.
  /// - Returns: The inspection.
  static func inspection<Entry: ObservableTranscriptEntry & InspectableClientModel>(
    id: String, title: String, content: @escaping @MainActor (Entry) -> [FoundationModelsACP.ContentBlock],
    messageID: @escaping @MainActor (Entry) -> String?,
    @FieldBuilder<InspectedClientModel<Entry>> extra: () -> [AnyField<InspectedClientModel<Entry>>] = { [] }
  ) -> Inspection<InspectedClientModel<Entry>> {
    let fields = textField(content) + extra() + idField(messageID)
    return Inspection(id: id, title: title) {
      // A closure with a `return` takes no builder: the fields are built.
      FieldGroup(InspectionLabel.message) { return fields }
      Entry.timeGroup
    }
  }

  /// The text row of a message entry.
  ///
  /// - Parameter content: The content blocks of an entry.
  /// - Returns: The row.
  @FieldBuilder<InspectedClientModel<Entry>>
  private static func textField<Entry: InspectableClientModel>(
    _ content: @escaping @MainActor (Entry) -> [FoundationModelsACP.ContentBlock]
  ) -> [AnyField<InspectedClientModel<Entry>>] {
    Field(InspectionLabel.text) { InspectionText.text(of: content($0.model)) }
      .multiline()
  }

  /// The id row of a message entry.
  ///
  /// - Parameter messageID: The id of the message of an entry, or `nil`.
  /// - Returns: The row.
  @FieldBuilder<InspectedClientModel<Entry>>
  private static func idField<Entry: InspectableClientModel>(
    _ messageID: @escaping @MainActor (Entry) -> String?
  ) -> [AnyField<InspectedClientModel<Entry>>] {
    Field(InspectionLabel.messageID) { messageID($0.model) }
  }
}

extension UserMessageEntry: InspectableClientModel {
  /// The text, the send state and the id of the message, and its times.
  public static var inspection: Inspection<InspectedClientModel<UserMessageEntry>> {
    MessageInspection.inspection(
      id: ClientInspectionID.userMessage, title: String(localized: "User Message", bundle: .module),
      content: { $0.content },
      messageID: { $0.messageId?.rawValue }
    ) {
      Field(FieldLabel(localized: "Send State", bundle: .module)) { EditorStatus($0.model.sendState) }
    }
  }
}

extension AgentMessageEntry: InspectableClientModel {
  /// The text and the id of the message, and its times.
  public static var inspection: Inspection<InspectedClientModel<AgentMessageEntry>> {
    MessageInspection.inspection(
      id: ClientInspectionID.agentMessage, title: String(localized: "Agent Message", bundle: .module),
      content: { $0.content },
      messageID: { $0.messageId?.rawValue })
  }
}

extension ThoughtEntry: InspectableClientModel {
  /// The text and the id of the thought, and its times.
  public static var inspection: Inspection<InspectedClientModel<ThoughtEntry>> {
    MessageInspection.inspection(
      id: ClientInspectionID.thought, title: String(localized: "Thought", bundle: .module), content: { $0.content },
      messageID: { $0.messageId?.rawValue })
  }
}

extension SessionMessageEntry: InspectableClientModel {
  /// The text of the message between two sessions, its sender and its
  /// recipient, its id, and its times.
  public static var inspection: Inspection<InspectedClientModel<SessionMessageEntry>> {
    MessageInspection.inspection(
      id: ClientInspectionID.sessionMessage, title: String(localized: "Session Message", bundle: .module),
      content: { $0.content },
      messageID: { $0.messageId.rawValue }
    ) {
      Field(FieldLabel(localized: "From Session", bundle: .module)) { $0.model.senderSessionId?.rawValue }
      Field(FieldLabel(localized: "To Session", bundle: .module)) { $0.model.recipientSessionId?.rawValue }
    }
  }
}

extension PlanTranscriptEntry: InspectableClientModel {
  /// The steps of the plan, each with its status, and its times.
  public static var inspection: Inspection<InspectedClientModel<PlanTranscriptEntry>> {
    .named(FieldLabel(localized: "Plan", bundle: .module), id: ClientInspectionID.plan) {
      Field(FieldLabel(localized: "Steps", bundle: .module)) { entry in InspectionText.steps(of: entry.model.entries) }
      .multiline()
    } more: {
      timeGroup
    }
  }
}

extension CompactionEntry: InspectableClientModel {
  /// The status, the summary and the error of the compaction, and its times.
  public static var inspection: Inspection<InspectedClientModel<CompactionEntry>> {
    .named(FieldLabel(localized: "Compaction", bundle: .module), id: ClientInspectionID.compaction) {
      Field(InspectionLabel.status) { EditorStatus($0.model.status) }
      Field(FieldLabel(localized: "Summary", bundle: .module)) { InspectionText.text(of: $0.model.summary) }
        .multiline()
      Field(FieldLabel(localized: "Error", bundle: .module)) { $0.model.error }
    } more: {
      timeGroup
    }
  }
}

extension ErrorEntry: InspectableClientModel {
  /// The code and the message of the error, and its times.
  public static var inspection: Inspection<InspectedClientModel<ErrorEntry>> {
    .named(FieldLabel(localized: "Error", bundle: .module), id: ClientInspectionID.error) {
      Field(FieldLabel(localized: "Code", bundle: .module)) { $0.model.code.wireValue }
      Field(InspectionLabel.message) { $0.model.message }
        .multiline()
    } more: {
      timeGroup
    }
  }
}

extension UnknownEntry: InspectableClientModel {
  /// The type of the update that the client does not know, and its times.
  public static var inspection: Inspection<InspectedClientModel<UnknownEntry>> {
    Inspection(id: ClientInspectionID.unknownUpdate, title: String(localized: "Unknown Update", bundle: .module)) {
      FieldGroup(FieldLabel(localized: "Update", bundle: .module)) {
        Field(FieldLabel(localized: "Type", bundle: .module)) { $0.model.type }
      }
      timeGroup
    }
  }
}
