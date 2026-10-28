import Foundation
import PackageFileSupport

/// The paths and the search texts that the scans of the kit views share.
///
/// The symbol name scan, the rendering mode scan, the shared symbol scan and
/// the fixed color scan read the same directories, the same files and the
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
  /// support targets and the examples.
  static let viewPaths = ["Sources", "Examples"]

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

  /// Runs a scan over each directory of ``viewPaths``.
  ///
  /// Each view scan walks the same directories. The walk is here, so a scan
  /// gives only its own scanner call.
  ///
  /// - Parameter scan: The scan of one directory. It gets the URL of the
  ///   directory and gives the results that it finds there.
  /// - Returns: The results of each directory, in the order of ``viewPaths``.
  /// - Throws: The error of `PackageFiles.file(_:)` when a view path is not
  ///   in the package, or the error of `scan`.
  static func scanViewFiles<Match>(_ scan: (URL) throws -> [Match]) throws -> [Match] {
    try viewPaths.flatMap { path in try scan(PackageFiles.file(path)) }
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
    try libraryPaths.flatMap { path in try scan(PackageFiles.file(path)) }
  }
}
