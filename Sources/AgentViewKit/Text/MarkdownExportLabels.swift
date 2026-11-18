import ACPMarkdown
import Foundation

/// The fixed words of a Markdown export of a thread, from the string catalog
/// of the kit (D202).
///
/// `SessionMarkdown` of ACPMarkdown writes the headings, the summaries and
/// the status words of a document in English. The kit gives its own words
/// from its catalog, so a host app shows the words of the language of the
/// user. Each entry names one field of `SessionMarkdown.Labels` and the
/// catalog key of its text. The turns of the user and of the agent use the
/// sender names of the copy text of the kit ("User" and "Assistant").
enum MarkdownExportLabels {
  /// One field of the labels and the catalog key of its text.
  struct Entry {
    /// The field of `SessionMarkdown.Labels` that the text goes to.
    let field: WritableKeyPath<SessionMarkdown.Labels, String>

    /// The key of the text in the string catalog of the kit.
    let key: String
  }

  /// The table of the string catalog of the kit.
  private static let table = "Localizable"

  /// The entry of each field of `SessionMarkdown.Labels`, one time each.
  static let entries: [Entry] = [
    Entry(field: \.user, key: "User"),
    Entry(field: \.agent, key: "Assistant"),
    Entry(field: \.thought, key: "markdown-export.thought"),
    Entry(field: \.from, key: "markdown-export.from"),
    Entry(field: \.fromUserIn, key: "markdown-export.from-user-in"),
    Entry(field: \.to, key: "markdown-export.to"),
    Entry(field: \.unknownSession, key: "markdown-export.unknown-session"),
    Entry(field: \.plan, key: "markdown-export.plan"),
    Entry(field: \.exitStatus, key: "markdown-export.exit-status"),
    Entry(field: \.compacted, key: "markdown-export.compacted"),
    Entry(field: \.toolCall, key: "markdown-export.tool-call"),
    Entry(field: \.terminal, key: "markdown-export.terminal"),
    Entry(field: \.image, key: "markdown-export.image"),
    Entry(field: \.audio, key: "markdown-export.audio"),
    Entry(field: \.resource, key: "markdown-export.resource"),
    Entry(field: \.toolCallStatus.pending, key: "markdown-export.tool-call-status.pending"),
    Entry(field: \.toolCallStatus.inProgress, key: "markdown-export.tool-call-status.in-progress"),
    Entry(field: \.toolCallStatus.paused, key: "markdown-export.tool-call-status.paused"),
    Entry(field: \.toolCallStatus.completed, key: "markdown-export.tool-call-status.completed"),
    Entry(field: \.toolCallStatus.failed, key: "markdown-export.tool-call-status.failed"),
    Entry(field: \.toolCallStatus.cancelled, key: "markdown-export.tool-call-status.cancelled"),
    Entry(field: \.toolKind.read, key: "markdown-export.tool-kind.read"),
    Entry(field: \.toolKind.edit, key: "markdown-export.tool-kind.edit"),
    Entry(field: \.toolKind.delete, key: "markdown-export.tool-kind.delete"),
    Entry(field: \.toolKind.move, key: "markdown-export.tool-kind.move"),
    Entry(field: \.toolKind.search, key: "markdown-export.tool-kind.search"),
    Entry(field: \.toolKind.execute, key: "markdown-export.tool-kind.execute"),
    Entry(field: \.toolKind.think, key: "markdown-export.tool-kind.think"),
    Entry(field: \.toolKind.fetch, key: "markdown-export.tool-kind.fetch"),
    Entry(field: \.toolKind.switchMode, key: "markdown-export.tool-kind.switch-mode"),
    Entry(field: \.toolKind.other, key: "markdown-export.tool-kind.other"),
    Entry(field: \.planItemStatus.inProgress, key: "markdown-export.plan-item-status.in-progress"),
    Entry(field: \.planItemStatus.cancelled, key: "markdown-export.plan-item-status.cancelled"),
    Entry(field: \.diffOperation.add, key: "markdown-export.diff-operation.add"),
    Entry(field: \.diffOperation.delete, key: "markdown-export.diff-operation.delete"),
    Entry(field: \.diffOperation.modify, key: "markdown-export.diff-operation.modify"),
    Entry(field: \.diffOperation.move, key: "markdown-export.diff-operation.move"),
    Entry(field: \.diffOperation.copy, key: "markdown-export.diff-operation.copy"),
  ]

  /// The labels with the text of each entry from the catalog, in the
  /// language of the user.
  ///
  /// The start value of each field is the English word of
  /// `SessionMarkdown.Labels()`. A key that the catalog does not have keeps
  /// that word.
  static var catalog: SessionMarkdown.Labels {
    entries.reduce(into: SessionMarkdown.Labels()) { labels, entry in
      labels[keyPath: entry.field] = Bundle.module.localizedString(
        forKey: entry.key, value: labels[keyPath: entry.field], table: table)
    }
  }
}
