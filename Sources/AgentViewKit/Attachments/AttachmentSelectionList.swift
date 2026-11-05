import Foundation

/// How a press on a file view changes the files that an inspector shows
/// (card ^4138tmp).
///
/// The kinds follow the selection model of EditorKit's lists, as a Finder
/// list does: a click selects, a Command-click adds or takes out, and a
/// Shift-click extends. Each kind has a named accessibility action on each
/// file view (``InspectorSelectable``), so VoiceOver and a test do what a
/// Command-click and a Shift-click do.
nonisolated enum AttachmentSelectionChange: Sendable, Hashable, CaseIterable {
  /// A click: the file is the whole selection.
  case select

  /// A Command-click, or the action Add to Selection: a file out of the
  /// selection joins its end, and a selected file leaves it.
  case toggle

  /// A Shift-click, or the action Extend Selection: each file from the
  /// anchor to the file, in transcript order, joins the end of the
  /// selection.
  case extend

  /// The name of the accessibility action of the change on a file view:
  /// Select, Add to Selection or Extend Selection.
  var actionName: String {
    switch self {
    case .select: String(localized: "Select", bundle: .module)
    case .toggle: String(localized: "Add to Selection", bundle: .module)
    case .extend: String(localized: "Extend Selection", bundle: .module)
    }
  }
}

/// The files that an inspector shows, in selection order, with the anchor
/// of the next extend (card ^4138tmp).
///
/// The list compares files by URL, as ``AttachmentSelectAction/isSelected(_:)``
/// does: two attachments of one file are one file. It holds each file one
/// time.
///
/// The anchor is the file of the last select or toggle. An extend keeps it,
/// so each extend reaches from the same file, and it adds the files of the
/// range that the selection does not hold yet, in transcript order. An
/// extend that has no anchor, or whose anchor or file the order does not
/// hold, adds only the file, and makes it the anchor when there was none.
nonisolated struct AttachmentSelectionList: Hashable, Sendable {
  /// The selected files, in selection order.
  private(set) var files: [Attachment]

  /// The URL of the file that an extend reaches from, or `nil`.
  private(set) var anchor: URL?

  /// Makes a selection of files, anchored at the last one.
  ///
  /// - Parameter files: The selected files, in selection order.
  init(files: [Attachment] = []) {
    self.init(files: files, anchor: files.last?.url)
  }

  /// Makes a selection of files with an anchor of its own.
  ///
  /// - Parameters:
  ///   - files: The selected files, in selection order.
  ///   - anchor: The URL of the file that an extend reaches from, or `nil`.
  init(files: [Attachment], anchor: URL?) {
    self.files = files
    self.anchor = anchor
  }

  /// Whether the selection holds a file with the URL of `file`.
  ///
  /// - Parameter file: A file.
  /// - Returns: `true` when a selected file has the URL of `file`.
  func contains(_ file: Attachment) -> Bool {
    files.contains { $0.url == file.url }
  }

  /// Applies one change to the selection.
  ///
  /// - Parameters:
  ///   - change: The kind of the change.
  ///   - file: The file of the press.
  ///   - order: The files of the thread in transcript order. Only an extend
  ///     reads it.
  mutating func apply(_ change: AttachmentSelectionChange, to file: Attachment, order: () -> [Attachment]) {
    switch change {
    case .select:
      files = [file]
      anchor = file.url
    case .toggle:
      toggle(file)
    case .extend:
      extend(to: file, range: range(to: file, in: order()))
    }
  }

  /// Adds `file` to the end of the selection, or takes it out when it is
  /// selected, and anchors the selection at it.
  ///
  /// - Parameter file: The file of the press.
  private mutating func toggle(_ file: Attachment) {
    if contains(file) {
      files.removeAll { $0.url == file.url }
    } else {
      files.append(file)
    }
    anchor = file.url
  }

  /// Adds each file of `range` that the selection does not hold, in its
  /// order. A selection with no anchor gets `file` as its anchor.
  ///
  /// - Parameters:
  ///   - file: The file of the press.
  ///   - range: The files from the anchor to `file`, in transcript order.
  private mutating func extend(to file: Attachment, range: [Attachment]) {
    for member in range where !contains(member) {
      files.append(member)
    }
    anchor = anchor ?? file.url
  }

  /// The files from the anchor to `file` in `order`, in transcript order:
  /// only `file` when the selection has no anchor, or when `order` does not
  /// hold the anchor or `file`.
  ///
  /// - Parameters:
  ///   - file: The file of the press.
  ///   - order: The files of the thread in transcript order.
  /// - Returns: The files of the range.
  private func range(to file: Attachment, in order: [Attachment]) -> [Attachment] {
    guard let anchor,
      let start = order.firstIndex(where: { $0.url == anchor }),
      let end = order.firstIndex(where: { $0.url == file.url })
    else { return [file] }
    return Array(order[min(start, end)...max(start, end)])
  }
}

/// The anchor of the selection of one thread view in the host mode
/// (card ^4138tmp).
///
/// The binding of a host holds the selected files and no anchor, so each
/// thread view keeps the anchor of its own presses here.
@MainActor final class AttachmentSelectionAnchor {
  /// The URL of the file that an extend reaches from, or `nil`.
  var url: URL?
}
