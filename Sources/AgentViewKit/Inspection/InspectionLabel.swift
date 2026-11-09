import EditorInspector
import Foundation

/// The titles, the group names and the field labels that more than one
/// inspection of a client model uses.
///
/// Each label is a `FieldLabel` of the string catalog of the kit
/// (`FieldLabel(localized:bundle:)`), so EditorKit keys the scheme id of its
/// row by the source key, the same in each language, such as
/// `field:tool-call.title`.
enum InspectionLabel {
  /// The group of the content of a message.
  static var message: FieldLabel { FieldLabel(localized: "Message", bundle: .module) }

  /// The text of a message.
  static var text: FieldLabel { FieldLabel(localized: "Text", bundle: .module) }

  /// The id of a message.
  static var messageID: FieldLabel { FieldLabel(localized: "Message Id", bundle: .module) }

  /// The working directory of a session or a terminal.
  static var workingDirectory: FieldLabel { FieldLabel(localized: "Working Directory", bundle: .module) }

  /// The group of the times of an entry.
  static var time: FieldLabel { FieldLabel(localized: "Time", bundle: .module) }

  /// The time an entry started.
  static var started: FieldLabel { FieldLabel(localized: "Started", bundle: .module) }

  /// The time an entry ended.
  static var ended: FieldLabel { FieldLabel(localized: "Ended", bundle: .module) }

  /// The time from the start of an entry to its end.
  static var duration: FieldLabel { FieldLabel(localized: "Duration", bundle: .module) }

  /// The title of a session or of a tool call.
  static var title: FieldLabel { FieldLabel(localized: "Title", bundle: .module) }

  /// The status of a session or of a compaction.
  static var status: FieldLabel { FieldLabel(localized: "Status", bundle: .module) }

  /// The name of a server or of an agent.
  static var name: FieldLabel { FieldLabel(localized: "Name", bundle: .module) }
}

extension Inspection {
  /// The inspection of a model whose first group is named as the inspection:
  /// `label` names both, so the name is written one time.
  ///
  /// The inspection takes the explicit `id`, so the view part of the scheme
  /// id of each row stays the same when the type of the model is renamed.
  ///
  /// - Parameters:
  ///   - label: The name of the first group; its text is the title of the
  ///     inspection.
  ///   - id: The id of the inspection: the view part of the scheme id of each
  ///     row, such as `tool-call`. It never follows the locale.
  ///   - name: The name of one object, or `nil` to name it by the title. A
  ///     block whose name gives `nil` takes the title too.
  ///   - fields: The fields of the first group.
  ///   - more: The groups after the first one.
  /// - Returns: The inspection.
  static func named(
    _ label: FieldLabel, id: String, name: (@MainActor (Object) -> String?)? = nil,
    @FieldBuilder<Object> fields: () -> [AnyField<Object>],
    @InspectionBuilder<Object> more: () -> [FieldGroup<Object>] = { [] }
  ) -> Inspection<Object> {
    let built = fields()
    // A closure with a `return` takes no builder: the fields are built.
    let first = FieldGroup(label) { return built }
    let rest = more()
    let title = label.text
    return Inspection(id: id, title: title, name: objectName(name, title: title)) {
      first
      for group in rest { group }
    }
  }

  /// The name of one object for an inspection, with the title in the place
  /// of a name of `nil`.
  ///
  /// - Parameters:
  ///   - name: The name of one object, or `nil` to name it by the title.
  ///   - title: The title of the inspection.
  /// - Returns: The name that EditorKit shows in the name row of a block,
  ///   or `nil` when `name` is `nil`.
  static func objectName(
    _ name: (@MainActor (Object) -> String?)?, title: String
  ) -> (@MainActor (Object) -> String)? {
    name.map { name in { @MainActor (object: Object) -> String in name(object) ?? title } }
  }
}
