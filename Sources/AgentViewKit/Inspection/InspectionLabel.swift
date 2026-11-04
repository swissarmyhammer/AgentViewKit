import EditorInspector

/// The titles, the group names and the field labels that more than one
/// inspection of a client model uses.
///
/// EditorKit makes the accessibility identifier of each row from the key of
/// its title, its group name and its label, such as
/// `tool-call.tool-call.title`.
enum InspectionLabel {
  /// The group of the content of a message.
  static var message: FieldLabel { FieldLabel(localized: "Message", bundle: .module) }

  /// The text of a message.
  static var text: FieldLabel { FieldLabel(localized: "Text", bundle: .module) }

  /// The id of a message.
  static var messageID: FieldLabel { FieldLabel(localized: "Message Id", bundle: .module) }

  /// The group of the times of an entry.
  static var time: FieldLabel { FieldLabel(localized: "Time", bundle: .module) }

  /// The time an entry started.
  static var started: FieldLabel { FieldLabel(localized: "Started", bundle: .module) }

  /// The time an entry ended.
  static var ended: FieldLabel { FieldLabel(localized: "Ended", bundle: .module) }

  /// The title of a session or of a tool call.
  static var title: FieldLabel { FieldLabel(localized: "Title", bundle: .module) }

  /// The status of a session or of a compaction.
  static var status: FieldLabel { FieldLabel(localized: "Status", bundle: .module) }

  /// The name of a server or of an agent.
  static var name: FieldLabel { FieldLabel(localized: "Name", bundle: .module) }
}
