import EditorInspector
import Foundation
import FoundationModelsACP

/// The path rows of the inspectors of the client models, and the URL that
/// each row shows.
///
/// EditorKit's inspector shows a `URL` field as a `PathChip`, and a `[URL]`
/// or a `[PathLocation]` field as a `PathChip` for each path, with the folder
/// symbol for a URL with a directory path and the document symbol otherwise
/// (`EditorSymbol.FileKind(location:)`), and the line of a `PathLocation`
/// after its name. The client models hold their paths
/// as ACP `AbsolutePath`s, so each path row makes its URLs here.
enum InspectionPath {
  /// The root folder, `/`: the stand-in URL of a path row whose model has no
  /// path. The row shows only when the model has a path, so no row shows it.
  static let rootFolder = URL(filePath: "/", directoryHint: .isDirectory)

  /// The URL of a folder, such as the working directory of a session: a
  /// file URL with a directory path, so its chip shows the folder symbol.
  ///
  /// - Parameter path: The path of the folder, or `nil` when the model does
  ///   not know it.
  /// - Returns: The URL of the folder, or ``rootFolder`` for `nil`.
  static func folder(_ path: AbsolutePath?) -> URL {
    guard let path else { return rootFolder }
    return url(path, directoryHint: .isDirectory)
  }

  /// The URL of a file, such as a location of a tool call: a file URL with
  /// no directory path, so its chip shows the document symbol.
  ///
  /// - Parameter path: The path of the file.
  /// - Returns: The URL of the file.
  static func file(_ path: AbsolutePath) -> URL {
    url(path, directoryHint: .notDirectory)
  }

  /// The file URL of a path, with the hint that picks the symbol of its chip.
  ///
  /// - Parameters:
  ///   - path: The path.
  ///   - directoryHint: Whether the path names a folder.
  /// - Returns: The URL of the path.
  private static func url(_ path: AbsolutePath, directoryHint: URL.DirectoryHint) -> URL {
    URL(filePath: path.rawValue, directoryHint: directoryHint)
  }

  /// The location of a tool call as its chip of a paths row shows it: the
  /// ``file(_:)`` URL of its path, with its line when the agent gave one, in
  /// the `name:line` form.
  ///
  /// - Parameter location: The location of a tool call.
  /// - Returns: The location of the chip.
  static func location(_ location: ToolCallLocation) -> PathLocation {
    PathLocation(file(location.path), line: location.line.map { Int($0.rawValue) })
  }

  /// The Working Directory row of a model: the path chip of its folder,
  /// shown only while the model knows the folder.
  ///
  /// - Parameter directory: The working directory of a model, or `nil`.
  /// - Returns: The read-only path field.
  static func workingDirectory<Object: AnyObject>(
    _ directory: @escaping @MainActor (Object) -> AbsolutePath?
  ) -> Field<Object, URL> {
    Field(InspectionLabel.workingDirectory) { folder(directory($0)) }
      .visible { directory($0) != nil }
  }
}
