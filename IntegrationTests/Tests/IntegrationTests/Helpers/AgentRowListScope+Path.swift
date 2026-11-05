import EditorCommands

@testable import AgentViewKit

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
