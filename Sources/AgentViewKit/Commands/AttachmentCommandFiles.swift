import Foundation

/// The files that a command at the scope of a file view acts on through the
/// file selection (card ^zsr2pbf).
///
/// A command on a selected file acts on every selected file, in transcript
/// order. A command on a file that the selection does not hold acts on that
/// file alone, as in the Finder. The scope of the file
/// (``AgentAttachmentScope``) gives these files to the context of its
/// commands (``AgentAttachmentTarget/contributeSelection(to:)``), and each
/// command reads them with `@FromSelection`.
nonisolated enum AttachmentCommandFiles {
  /// The files of the selection that a command at the scope of `file` acts
  /// on.
  ///
  /// The selection names a file by its URL, as the selected state of a file
  /// view does (``AttachmentSelectAction/isSelected(_:)``). So `file` stands
  /// in the result with its own fields, and the context of the command
  /// holds the segment of the scope: an ``ImageView`` names its block file
  /// with an id of its own.
  ///
  /// - Parameters:
  ///   - file: The file of the scope.
  ///   - selection: The selected files, in selection order.
  ///   - order: The files of the thread, in transcript order.
  /// - Returns: The selected files in transcript order, then each selected
  ///   file that `order` does not hold, in selection order. Empty when the
  ///   selection does not hold `file`, so the command acts on `file` alone.
  static func files(at file: Attachment, selection: [Attachment], order: [Attachment]) -> [Attachment] {
    guard selection.contains(where: { $0.url == file.url }) else { return [] }
    let ranks = Dictionary(order.enumerated().map { ($1.url, $0) }) { first, _ in first }
    let ranked = selection.enumerated().map { (rank: ranks[$1.url] ?? order.count, place: $0, file: $1) }
    let sorted = ranked.sorted { ($0.rank, $0.place) < ($1.rank, $1.place) }.map(\.file)
    return sorted.map { $0.url == file.url ? file : $0 }
  }
}
