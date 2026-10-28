import Foundation
import FoundationModelsACP
import OSLog

/// The files of a structured ACP diff (plan.md §3.8 "Tool call view").
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

  /// The `git_patch` text of an ACP diff.
  ///
  /// - Parameter diff: The ACP diff.
  /// - Returns: The patch text, or `nil` when the diff has no patch text in
  ///   the `git_patch` format.
  static func gitPatchText(of diff: FoundationModelsACP.Diff) -> String? {
    guard let patch = diff.patch, patch.format == .gitPatch else { return nil }
    return patch.text
  }

  /// The files that ``DiffView`` shows for an ACP diff, one file chip each.
  ///
  /// - Parameter diff: The ACP diff.
  /// - Returns: The files of the `git_patch` text (``parse(gitPatch:)``), or
  ///   the files of the structured changes when the diff has no `git_patch`
  ///   text.
  static func files(of diff: FoundationModelsACP.Diff) -> [FileSummary] {
    guard let patch = gitPatchText(of: diff) else { return files(of: diff.changes) }
    return parse(gitPatch: patch)
  }

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

nonisolated extension DiffSummary.FileSummary {
  /// The separator of the components of a path.
  static let pathSeparator = "/"

  /// Tells whether `location` is the path of this file, so that a tool call
  /// shows the file once: as its ``DiffView`` file chip, with no location
  /// chip of its own.
  ///
  /// An ACP location is an absolute path. The path of a file of a git patch
  /// is relative to the root of the repository, and the path of a structured
  /// change is absolute. The agent writes the location and the diff of one
  /// call, so the paths match as written, with no change of case.
  ///
  /// - Parameter location: The path of a location of the tool call.
  /// - Returns: `true` when `location` is ``path``, or when ``path`` is
  ///   relative and `location` ends with it after a path separator.
  func hasPath(_ location: String) -> Bool {
    guard location != path else { return true }
    return !path.hasPrefix(Self.pathSeparator) && location.hasSuffix(Self.pathSeparator + path)
  }
}
