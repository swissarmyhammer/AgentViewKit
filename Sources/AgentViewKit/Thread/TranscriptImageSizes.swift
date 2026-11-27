import CoreGraphics
import EditorSwiftUI
import Foundation

/// The natural size of each image file that a Markdown text shows, for the
/// height measure of the text (``EditorLayoutTranscriptTextMeasure``, card
/// ^9ync5h3).
///
/// `RenderedMarkdownView` loads each image of its text with EditorKit's
/// `FileImageSource` from the image folder of the session. EditorKit
/// measures an image when the host gives its natural size by its
/// destination (`EditorLayoutMeasure.measure(markdown:width:style:imageSizes:)`),
/// so the sizes here go to the measure.
///
/// The sizes find each destination that the text can name: the destination
/// of an inline image (`![alt](destination "title")`) and the destination
/// of a link reference definition (`[label]: destination`). A destination
/// that EditorKit does not ask for has no effect on the height. A
/// destination that has no size here makes the measure not exact, so the
/// row shows its real form. Thus a destination that the sizes do not find
/// costs only the static form, never a wrong height.
///
/// The sizes read only a file that `FileImageSource` also reads: a regular
/// file in the folder, with no symbolic link in its path below the folder,
/// of at most `FileImageSource.defaultMaximumByteCount` bytes. The size
/// comes from the header of the file (`EditorImage.naturalSize(ofImageData:)`),
/// with no decode.
nonisolated enum TranscriptImageSizes {
  /// The start of a destination that is a file URL.
  static let fileScheme = "file:"

  /// The text that a URL with a scheme has after its scheme.
  static let schemeSeparator = "://"

  /// The natural size of each image file of `folder` that `markdown` names.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text.
  ///   - folder: The image folder of the view.
  /// - Returns: The natural size in points of each image, by its
  ///   destination.
  static func sizes(in markdown: String, folder: URL) -> [String: CGSize] {
    guard let rootPath = canonicalPath(of: folder.path) else { return [:] }
    let root = URL(filePath: rootPath, directoryHint: .isDirectory)
    var sizes: [String: CGSize] = [:]
    for destination in destinations(in: markdown) {
      sizes[destination] = fileURL(of: destination, in: root).flatMap(naturalSize(ofFileAt:))
    }
    return sizes
  }

  /// The destinations that a Markdown text can name for an image: each
  /// inline image destination and each link reference definition
  /// destination, with no angle brackets.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The destinations.
  static func destinations(in markdown: String) -> Set<String> {
    let inline = markdown.matches(of: #/!\[[^\]]*\]\(\s*(?<destination><[^>\n]*>|[^)\s]+)/#)
      .map { String($0.output.destination) }
    let definitions = markdown.matches(of: #/(?m)^ {0,3}\[[^\]\n]+\]:[ \t]*(?<destination><[^>\n]*>|\S+)/#)
      .map { String($0.output.destination) }
    return Set((inline + definitions).map(withoutAngleBrackets))
  }

  /// A destination with no angle brackets around it.
  ///
  /// - Parameter destination: The destination as the text writes it.
  /// - Returns: The destination.
  static func withoutAngleBrackets(_ destination: String) -> String {
    guard destination.hasPrefix("<"), destination.hasSuffix(">") else { return destination }
    return String(destination.dropFirst().dropLast())
  }

  /// The URL of the regular file in `root` that `destination` names, or
  /// `nil` when the destination names no such file.
  ///
  /// The destination is a path relative to `root`, an absolute path, or a
  /// `file:` URL. The file must be in `root` after the resolve of `..`, and
  /// no symbolic link can be in its path below `root`.
  ///
  /// - Parameters:
  ///   - destination: The destination.
  ///   - root: The resolved image folder.
  /// - Returns: The URL, or `nil`.
  static func fileURL(of destination: String, in root: URL) -> URL? {
    let candidate: URL
    if destination.hasPrefix(fileScheme) {
      guard let url = URL(string: destination), url.isFileURL else { return nil }
      candidate = url
    } else if destination.contains(schemeSeparator) {
      return nil
    } else if destination.hasPrefix("/") {
      candidate = URL(filePath: destination)
    } else {
      candidate = root.appending(path: destination)
    }
    let path = lexicalPath(of: candidate.path)
    guard path.hasPrefix(root.path + "/"), canonicalPath(of: path) == path else { return nil }
    return URL(filePath: path)
  }

  /// A path with each `.` and `..` component resolved from the text of the
  /// path alone, with no read of the file system.
  ///
  /// `URL.standardizedFileURL` takes `/private` off a path, so the sizes
  /// resolve the components themselves.
  ///
  /// - Parameter path: An absolute path.
  /// - Returns: The path.
  static func lexicalPath(of path: String) -> String {
    var components: [Substring] = []
    for component in path.split(separator: "/") where component != "." {
      if component == ".." {
        _ = components.popLast()
      } else {
        components.append(component)
      }
    }
    return "/" + components.joined(separator: "/")
  }

  /// The canonical path of an existing file: the path with each symbolic
  /// link, `.` and `..` resolved (`realpath`).
  ///
  /// `URL.resolvingSymlinksInPath()` takes `/private` off a path, so the
  /// sizes use `realpath`, which keeps it.
  ///
  /// - Parameter path: The path.
  /// - Returns: The canonical path, or `nil` when no file is at the path.
  static func canonicalPath(of path: String) -> String? {
    guard let resolved = realpath(path, nil) else { return nil }
    defer { free(resolved) }
    return String(cString: resolved)
  }

  /// The natural size of the image in a regular file of at most
  /// `FileImageSource.defaultMaximumByteCount` bytes.
  ///
  /// - Parameter url: The URL of the file.
  /// - Returns: The size in points, or `nil` when the file is not such a
  ///   file or its header names no size.
  static func naturalSize(ofFileAt url: URL) -> CGSize? {
    guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
      values.isRegularFile == true, let size = values.fileSize, size <= FileImageSource.defaultMaximumByteCount,
      let data = try? Data(contentsOf: url)
    else { return nil }
    return EditorImage.naturalSize(ofImageData: data)
  }
}
