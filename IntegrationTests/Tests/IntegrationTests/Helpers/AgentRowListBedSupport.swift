import CoreGraphics
import EditorCommands

@testable import AgentViewKit

/// The values that the windows of the ``AgentRowList`` tests share.
enum AgentRowListBedSupport {
  /// The size of the window of a list bed.
  static let windowSize = CGSize(width: 300, height: 300)
}

extension AgentRowListScope {
  /// The path of the scope of the row with `id`, with the list at the root of
  /// the window.
  ///
  /// - Parameter id: The id of the row.
  /// - Returns: The path of the row.
  func path(ofRow id: String) -> FocusPath {
    FocusPath.root(list).appending(rowSegment(for: id))
  }
}
