import EditorDiff
import Foundation

/// The failure of a patch that EditorKit cannot read: the 1-based line of
/// the patch where the parse stopped.
///
/// Its description is the message that the EditorKit preview of a
/// ``DiffView`` shows as its failure, such as "Cannot read the patch at
/// line 3".
nonisolated struct UnreadablePatch: LocalizedError, Hashable, Sendable {
  /// The 1-based line of the patch where the parse stopped.
  let line: Int

  /// Makes the failure of a parse error.
  ///
  /// - Parameter error: The parse error of EditorKit.
  init(_ error: UnifiedDiffError) {
    switch error {
    case .malformedHunkHeader(let line), .hunkLineCountMismatch(let line), .unexpectedLine(let line):
      self.line = line
    }
  }

  /// "Cannot read the patch at line <line>".
  var errorDescription: String? {
    String(localized: "Cannot read the patch at line \(line)", bundle: .module)
  }
}
