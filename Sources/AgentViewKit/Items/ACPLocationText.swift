import FoundationModelsACP

nonisolated extension FoundationModelsACP.ToolCallLocation {
  /// The text of a location: the path, and `:<line>` when there is a line.
  ///
  /// The tool call view and the Markdown export show a location with this
  /// text. The view gives the full path or only the file name, and the export
  /// gives the path of a kit record, so the function takes the path text and
  /// not a location.
  ///
  /// - Parameters:
  ///   - path: The path text to show.
  ///   - line: The line in the file, if the source gave one.
  /// - Returns: `<path>`, or `<path>:<line>` when there is a line.
  static func text(path: String, line: Int?) -> String {
    guard let line else { return path }
    return "\(path):\(line)"
  }
}
