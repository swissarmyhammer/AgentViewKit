import EditorDiff
import Foundation

/// The failure of a patch that EditorKit cannot read: the 1-based line of
/// the patch where the parse stopped.
///
/// Its description is the one message of the view kits for such a patch,
/// "Cannot read the patch at line 3", which the EditorKit preview of a diff
/// shows as its failure.
public nonisolated struct UnreadablePatch: LocalizedError, Hashable, Sendable {
  /// The 1-based line of the patch where the parse stopped.
  public let line: Int

  /// Makes the failure of a parse error.
  ///
  /// - Parameter error: The parse error of EditorKit.
  public init(_ error: UnifiedDiffError) {
    switch error {
    case .malformedHunkHeader(let line), .hunkLineCountMismatch(let line), .unexpectedLine(let line):
      self.line = line
    }
  }

  /// "Cannot read the patch at line <line>".
  public var errorDescription: String? {
    String(localized: "Cannot read the patch at line \(line)", bundle: .module)
  }
}
