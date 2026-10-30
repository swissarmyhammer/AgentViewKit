import EditorTestSupport
import Foundation

/// The paths and the search texts that the scans of the kit views share.
///
/// The engine scans of ``StyleRuleEngineTests``, the rendering mode scan and
/// the shared symbol scan read the same directories, the same files and the
/// same texts. Each scan reads them here, so one change to a path or to a
/// text reaches each scan.
///
/// The package has two libraries: the kit, and its style, the shared look of
/// the view kits. A rule of the views of the kit is a rule of the style views
/// too, so a scan of the library sources reads both directories
/// (``scanLibraryFiles(_:)``).
enum KitSourceFiles {
  /// The directory of the Swift files of the kit library, relative to the
  /// package root.
  static let kitPath = "Sources/AgentViewKit"

  /// The directory of the Swift files of the style library, relative to the
  /// package root.
  static let stylePath = "Sources/AgentViewKitStyle"

  /// The directories of the Swift files of the two libraries.
  static let libraryPaths = [kitPath, stylePath]

  /// The directories of the Swift files that a view scan reads: the kit, its
  /// style, the demo support target and the examples.
  ///
  /// The test code is not a view of the kit, so no view scan reads it: not
  /// the test targets of either package, and not `AgentViewKitTestSupport`,
  /// which holds the fixtures that both test packages share, such as the
  /// test themes with fixed colors and faces (plan.md §11 decision 21). The
  /// scans of the test code read it (the `offscreenRenderers` engine of
  /// ``StyleRuleEngineTests``, ``HiddenTestWindowTests``,
  /// ``LightAndDarkOnlyTests``).
  static let viewPaths = [kitPath, stylePath, "Sources/DemoSupport", "Examples"]

  /// The text that starts a symbol image.
  static let symbolImageCall = "Image(systemName:"

  /// The file of the status bar, which draws the symbol of a banner.
  static let statusBarFile = styleFile("Status/StatusBar.swift")

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

  /// Gives the path of a file of the style library.
  ///
  /// - Parameter path: The path of the file below ``stylePath``.
  /// - Returns: The path of the file, relative to the package root.
  static func styleFile(_ path: String) -> String {
    "\(stylePath)/\(path)"
  }

  /// Runs a scan over the directory of each library, ``libraryPaths``.
  ///
  /// - Parameter scan: The scan of one directory. It gets the URL of the
  ///   directory and gives the results that it finds there.
  /// - Returns: The results of each directory, in the order of
  ///   ``libraryPaths``.
  /// - Throws: The error of `PackageFiles.file(_:)` when a library path is
  ///   not in the package, or the error of `scan`.
  static func scanLibraryFiles<Match>(_ scan: (URL) throws -> [Match]) throws -> [Match] {
    try libraryPaths.flatMap { path in try scan(PackageFiles().file(path)) }
  }
}
