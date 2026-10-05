import Foundation
import FoundationModelsACP
import OSLog

/// The files of a structured ACP diff (update.md §9.4).
///
/// An ACP `Diff` has a list of structured changes, and it can have patch text.
/// When it has no `git_patch` text, ``DiffView`` shows the file of each
/// change from these summaries. A summary of a structured change has no
/// hunks, so its counts are zero, and ``FileSummary/changeAccessibilityLabel``
/// tells the change in place of the counts.
nonisolated extension DiffSummary {
  /// The key of the path in the members of a change that the kit does not
  /// know.
  static let unknownChangePathKey = "path"

  /// The log of the structured changes that the kit cannot show.
  private static let logger = Logger(subsystem: "AgentViewKit", category: "DiffSummary")

  /// The files of the structured changes of an ACP diff.
  ///
  /// - Parameter changes: The `changes` of an ACP `Diff`.
  /// - Returns: One summary with no hunks for each change, in change order.
  ///   A change that the kit does not know gives the operation
  ///   ``Operation/unknown(_:)`` and the `path` member of the change. A
  ///   change that the kit does not know and that has no `path` member gives
  ///   no summary, and the log records it.
  public static func files(of changes: [DiffChange]) -> [FileSummary] {
    changes.compactMap { change in
      guard let file = file(of: change.operation) else {
        logger.error("A structured diff change has no path. The diff view does not show it.")
        return nil
      }
      return file
    }
  }

  /// The summary of one structured change, with no hunks.
  ///
  /// - Parameter payload: The operation of the change, with its paths.
  /// - Returns: The summary with the path after the change, or `nil` for a
  ///   change that the kit does not know and that has no `path` member.
  private static func file(of payload: DiffChange.Payload) -> FileSummary? {
    switch payload {
    case .add(let change): file(change.path.rawValue, .added)
    case .delete(let change): file(change.path.rawValue, .deleted)
    case .modify(let change): file(change.path.rawValue, .modified)
    case .move(let change): file(change.path.rawValue, .renamed(from: change.oldPath.rawValue))
    case .copy(let change): file(change.path.rawValue, .copied(from: change.oldPath.rawValue))
    case .unknown(let name, let members): unknownChangePath(in: members).map { file($0, .unknown(name)) }
    }
  }

  /// The summary of a file with no hunks.
  ///
  /// - Parameters:
  ///   - path: The path of the file after the change.
  ///   - operation: The change to the file.
  /// - Returns: The summary.
  private static func file(_ path: String, _ operation: Operation) -> FileSummary {
    FileSummary(path: path, operation: operation, hunks: [])
  }

  /// The `path` member of a change that the kit does not know.
  ///
  /// - Parameter members: The other members of the change object.
  /// - Returns: The path text, or `nil` when the change has no string `path`.
  private static func unknownChangePath(in members: FoundationModelsACP.JSONValue) -> String? {
    guard case .object(let fields) = members, case .string(let path)? = fields[unknownChangePathKey]
    else { return nil }
    return path
  }
}

nonisolated extension DiffSummary.Operation {
  /// The word that tells the operation, such as "Added".
  ///
  /// An operation that the kit does not know gives "Changed".
  public var label: String {
    switch self {
    case .added: String(localized: "Added")
    case .deleted: String(localized: "Deleted")
    case .modified: String(localized: "Modified")
    case .renamed: String(localized: "Renamed")
    case .copied: String(localized: "Copied")
    case .unknown: String(localized: "Changed")
    }
  }
}

nonisolated extension DiffSummary.FileSummary {
  /// The label that VoiceOver reads for a file of a diff with no patch text.
  ///
  /// The label is "<operation> <language> file", such as "Added Swift file".
  public var changeAccessibilityLabel: String {
    String(localized: "\(operation.label) \(language) file")
  }
}
