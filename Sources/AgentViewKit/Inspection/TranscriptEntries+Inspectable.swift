import EditorInspector
import EditorSwiftUI
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
// goes inside an inspector. A status is EditorKit's status token
// (`EditorStatus`), which the inspector shows as a read-only `.status` row.
// The working directory of a terminal is EditorKit's path kind
// (``InspectionPath``). The locations of a tool call are not here yet: they
// are a list of paths, which EditorKit's inspector has no kind for
// (^b9xgnm7).

extension ObservableTranscriptEntry {
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
  static var timeGroup: FieldGroup<Self> {
    FieldGroup(InspectionLabel.time) {
      Field(InspectionLabel.started) { $0.timing.startedAt }
      Field(InspectionLabel.ended) { $0.timing.endedAt }
      Field(InspectionLabel.duration) { Duration.seconds($0.timing.duration ?? .zero) }
        .durationFormat(durationRowFormat)
        .visible { EntryTimingView.shownDuration($0.timing.duration) != nil }
    }
  }
}

extension ToolCallEntry: @retroactive Inspectable {
  /// The title, the status, the kind and the tool name of the call, and its
  /// times.
  public static var inspection: Inspection<ToolCallEntry> {
    .named(FieldLabel(localized: "Tool Call", bundle: .module), name: { $0.shownTitle }) {
      Field(InspectionLabel.title) { $0.shownTitle }
      Field(InspectionLabel.status) { EditorStatus($0.shownStatus) }
      Field(FieldLabel(localized: "Kind", bundle: .module)) { $0.shownKind.wireValue }
      Field(FieldLabel(localized: "Tool", bundle: .module)) { $0.name }
    } more: {
      timeGroup
    }
  }
}

extension TerminalEntry: @retroactive Inspectable {
  /// The command, the exit, the output and the working directory of the
  /// terminal, and its times.
  public static var inspection: Inspection<TerminalEntry> {
    .named(FieldLabel(localized: "Terminal", bundle: .module), name: { $0.command }) {
      Field(FieldLabel(localized: "Command", bundle: .module)) { $0.command }
      Field(FieldLabel(localized: "Exit Status", bundle: .module)) { entry in
        entry.exitStatus.map { TerminalView.ExitSummary(code: $0.exitCode, signal: $0.signal).label }
      }
      Field(FieldLabel(localized: "Output", bundle: .module)) { $0.text }
        .multiline()
      InspectionPath.workingDirectory { $0.cwd }
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
      Field(FieldLabel(localized: "Send State", bundle: .module)) { EditorStatus($0.sendState) }
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
    .named(FieldLabel(localized: "Plan", bundle: .module)) {
      Field(FieldLabel(localized: "Steps", bundle: .module)) { entry in
        entry.entries.map(InspectionText.step).joined(separator: "\n")
      }
      .multiline()
    } more: {
      timeGroup
    }
  }
}

extension CompactionEntry: @retroactive Inspectable {
  /// The status, the summary and the error of the compaction, and its times.
  public static var inspection: Inspection<CompactionEntry> {
    .named(FieldLabel(localized: "Compaction", bundle: .module)) {
      Field(InspectionLabel.status) { EditorStatus($0.status) }
      Field(FieldLabel(localized: "Summary", bundle: .module)) { InspectionText.text(of: $0.summary) }
        .multiline()
      Field(FieldLabel(localized: "Error", bundle: .module)) { $0.error }
    } more: {
      timeGroup
    }
  }
}

extension ErrorEntry: @retroactive Inspectable {
  /// The code and the message of the error, and its times.
  public static var inspection: Inspection<ErrorEntry> {
    .named(FieldLabel(localized: "Error", bundle: .module)) {
      Field(FieldLabel(localized: "Code", bundle: .module)) { $0.code.wireValue }
      Field(InspectionLabel.message) { $0.message }
        .multiline()
    } more: {
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
