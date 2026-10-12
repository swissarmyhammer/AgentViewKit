/// The paths and the search texts that the scans of the kit views share.
///
/// The symbol name scan, the rendering mode scan, the shared symbol scan and
/// the fixed color scan read the same directories, the same files and the
/// same texts. Each scan reads them here, so one change to a path or to a
/// text reaches each scan.
enum KitSourceFiles {
  /// The directory of the Swift files of the kit library, relative to the
  /// package root.
  static let kitPath = "Sources/AgentViewKit"

  /// The directories of the Swift files that a view scan reads: the kit, its
  /// support targets and the examples.
  static let viewPaths = ["Sources", "Examples"]

  /// The text that starts a symbol image.
  static let symbolImageCall = "Image(systemName:"

  /// The file of the status bar, which draws the symbol of a banner.
  static let statusBarFile = kitFile("Status/StatusBar.swift")

  /// The file of the plan view, which draws the status and the priority
  /// symbol of each plan entry.
  static let taskListFile = kitFile("Status/TaskListView.swift")

  /// Gives the path of a file of the kit library.
  ///
  /// - Parameter path: The path of the file below ``kitPath``.
  /// - Returns: The path of the file, relative to the package root.
  static func kitFile(_ path: String) -> String {
    "\(kitPath)/\(path)"
  }
}
