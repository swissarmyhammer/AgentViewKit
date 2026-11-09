import EditorInspector
import EditorSwiftUI
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

// The inspections of the transcript entries of FoundationModelsACPClient, so
// a host shows any entry in an EditorKit `InspectorView`
// (`InspectorView(entry)`, or `InspectorView([any Inspectable])` with
// `InspectedClientModel(entry)` for a selection of several entries, which
// shows one block for each entry). The name row of each block tells its
// entry (``InspectionName``), so two blocks of one type have two names. The
// host applies `.inspectorFieldLabels(.visible)` to the inspector of a tool
// call and of a terminal, and keeps the default (`.placeholder`) for the other
// entries. Each entry is an ``InspectableClientModel``: the inspector shows
// it through an ``InspectedClientModel``, whose id is the readable object id
// of the entry, such as `tool-call-call_1`
// (``InspectableClientModel/inspectorObjectID``).
//
// Each row is read-only: the agent owns each entry. Each get block reads the
// entry when the row draws, so an update of the agent redraws the row. The
// rows use the kinds of EditorKit's inspector only; no AgentViewKit view
// goes inside an inspector. A status is EditorKit's status token
// (`EditorStatus`), which the inspector shows as a read-only `.status` row.
// The working directory of a terminal is EditorKit's path kind, and the
// locations of a tool call are its paths kind, a path chip for each file
// (``InspectionPath``). A press on a chip opens its file or its folder.

extension ObservableTranscriptEntry where Self: InspectableClientModel {
  /// The group of the start and end times of the entry, as the client saw
  /// them, and the duration between them, in the styles of the time line of
  /// a transcript row.
  ///
  /// Each row is EditorKit's read-only `DisplayField`. The Started and Ended
  /// rows show the time of day of ``EntryTimingView/startStyle``, such as
  /// "6:13 AM", in the locale and the time zone of the inspector, and a dash
  /// while the entry has no such time. The Duration row shows the narrow
  /// units of ``EntryTimingView/lineDurationStyle``, such as "1m 15s", in the
  /// locale of the inspector. It shows where the transcript row shows a
  /// duration (``EntryTimingView/shownDuration(_:)``): for an entry that has
  /// ended, after at least ``EntryTimingView/shortestShownDuration`` (half a
  /// second). A shorter duration rounds to zero seconds and shows no row.
  static var timeGroup: FieldGroup<InspectedClientModel<Self>> {
    FieldGroup(InspectionLabel.time) {
      DisplayField(InspectionLabel.started, format: EntryTimingView.startStyle) { $0.model.timing.startedAt }
      DisplayField(InspectionLabel.ended, format: EntryTimingView.startStyle) { $0.model.timing.endedAt }
      DisplayField(InspectionLabel.duration, format: EntryTimingView.lineDurationStyle) { entry in
        entry.model.timing.duration.map(Duration.seconds)
      }
      .visible { EntryTimingView.shownDuration($0.model.timing.duration) != nil }
    }
  }
}

extension ToolCallEntry: InspectableClientModel {
  /// The title, the status, the kind, the tool name and the locations of the
  /// call, and its times.
  ///
  /// The Locations row shows a path chip for the file of each location, in
  /// the order of the agent, with the line in the `name:line` form when the
  /// agent gave one, and a dash for a call with no location. A press on a
  /// chip opens its file.
  ///
  /// The status, the kind and the tool name of a call are read-only values
  /// that are not clear without their names, so the inspector shows the
  /// name of each row, as a row of System Settings does. The host makes the
  /// `InspectorView`, so the host applies the modifier:
  ///
  /// ```swift
  /// InspectorView(toolCall)
  ///   .inspectorFieldLabels(.visible)
  /// ```
  public static var inspection: Inspection<InspectedClientModel<ToolCallEntry>> {
    .named(
      FieldLabel(localized: "Tool Call", bundle: .module), id: ClientInspectionID.toolCall,
      name: { $0.model.shownTitle }
    ) {
      Field(InspectionLabel.title) { $0.model.shownTitle }
      Field(InspectionLabel.status) { EditorStatus($0.model.shownStatus) }
      Field(FieldLabel(localized: "Kind", bundle: .module)) { $0.model.shownKind.wireValue }
      Field(FieldLabel(localized: "Tool", bundle: .module)) { $0.model.name }
      Field(FieldLabel(localized: "Locations", bundle: .module)) { entry in
        entry.model.locations.map(InspectionPath.location)
      }
      .opening { $0.openPath($1) }
    } more: {
      timeGroup
    }
  }
}

extension TerminalEntry: InspectableClientModel {
  /// The command, the exit, the output and the working directory of the
  /// terminal, and its times.
  ///
  /// The command and the exit status of a terminal are read-only values
  /// that are not clear without their names, so the inspector shows the
  /// name of each row, as a row of System Settings does. The host makes the
  /// `InspectorView`, so the host applies the modifier:
  ///
  /// ```swift
  /// InspectorView(terminal)
  ///   .inspectorFieldLabels(.visible)
  /// ```
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
  /// The name of the block of an entry is its author and its start time,
  /// or the first words of its text (``InspectionName/message(author:startedAt:text:locale:timeZone:)``),
  /// so two blocks of one type have two names.
  ///
  /// - Parameters:
  ///   - id: The id of the inspection: the view part of the scheme id of each
  ///     row, such as `user-message`. It never follows the locale.
  ///   - title: The title of a block of the entry type.
  ///   - content: The content blocks of an entry.
  ///   - author: The author of an entry, or `nil` for an entry with no
  ///     author.
  ///   - messageID: The id of the message of an entry, or `nil` while no
  ///     agent gave one.
  ///   - extra: The fields that follow the text, before the id.
  /// - Returns: The inspection.
  static func inspection<Entry: ObservableTranscriptEntry & InspectableClientModel>(
    id: String, title: String, content: @escaping @MainActor (Entry) -> [FoundationModelsACP.ContentBlock],
    author: @escaping @MainActor (Entry) -> String? = { _ in nil },
    messageID: @escaping @MainActor (Entry) -> String?,
    @FieldBuilder<InspectedClientModel<Entry>> extra: () -> [AnyField<InspectedClientModel<Entry>>] = { [] }
  ) -> Inspection<InspectedClientModel<Entry>> {
    let fields = textField(content) + extra() + idField(messageID)
    let name = Inspection<InspectedClientModel<Entry>>.objectName(
      { entry in
        InspectionName.message(
          author: author(entry.model), startedAt: entry.model.timing.startedAt,
          text: InspectionText.text(of: content(entry.model)))
      }, title: title)
    return Inspection(id: id, title: title, name: name) {
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
      author: { $0.senderSessionId?.rawValue },
      messageID: { $0.messageId.rawValue }
    ) {
      Field(FieldLabel(localized: "From Session", bundle: .module)) { $0.model.senderSessionId?.rawValue }
      Field(FieldLabel(localized: "To Session", bundle: .module)) { $0.model.recipientSessionId?.rawValue }
    }
  }
}

extension PlanTranscriptEntry: InspectableClientModel {
  /// The steps of the plan, each with its status, and its times.
  ///
  /// The name of the block of a plan is the first words of its current
  /// step (``InspectionName/plan(_:)``).
  public static var inspection: Inspection<InspectedClientModel<PlanTranscriptEntry>> {
    .named(
      FieldLabel(localized: "Plan", bundle: .module), id: ClientInspectionID.plan,
      name: { InspectionName.plan($0.model.entries) }
    ) {
      Field(FieldLabel(localized: "Steps", bundle: .module)) { entry in InspectionText.steps(of: entry.model.entries) }
      .multiline()
    } more: {
      timeGroup
    }
  }
}

extension CompactionEntry: InspectableClientModel {
  /// The status, the summary and the error of the compaction, and its times.
  ///
  /// The name of the block of a compaction is the first words of its
  /// summary, or its status while it has no summary.
  public static var inspection: Inspection<InspectedClientModel<CompactionEntry>> {
    .named(
      FieldLabel(localized: "Compaction", bundle: .module), id: ClientInspectionID.compaction,
      name: { entry in
        InspectionName.firstWords(of: InspectionText.text(of: entry.model.summary))
          ?? EditorStatus(entry.model.status).summary
      }
    ) {
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
  ///
  /// The name of the block of an error is the first words of its message,
  /// or its code while it has no message.
  public static var inspection: Inspection<InspectedClientModel<ErrorEntry>> {
    .named(
      FieldLabel(localized: "Error", bundle: .module), id: ClientInspectionID.error,
      name: { InspectionName.firstWords(of: $0.model.message) ?? String($0.model.code.wireValue) }
    ) {
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
  ///
  /// The name of the block of an update is its type, such as
  /// `x_board_update`.
  public static var inspection: Inspection<InspectedClientModel<UnknownEntry>> {
    let title = String(localized: "Unknown Update", bundle: .module)
    let name = Inspection<InspectedClientModel<UnknownEntry>>.objectName(
      { $0.model.type.isEmpty ? nil : $0.model.type }, title: title)
    return Inspection(id: ClientInspectionID.unknownUpdate, title: title, name: name) {
      FieldGroup(FieldLabel(localized: "Update", bundle: .module)) {
        Field(FieldLabel(localized: "Type", bundle: .module)) { $0.model.type }
      }
      timeGroup
    }
  }
}
