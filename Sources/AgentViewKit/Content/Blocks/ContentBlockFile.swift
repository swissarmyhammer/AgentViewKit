import CryptoKit
import Foundation
import UniformTypeIdentifiers

/// Writes the bytes of a content block to a local file.
///
/// An image or a sound block holds its bytes, but QuickLook and AVKit need a
/// file URL. The file is in the temporary directory, in a folder named by the
/// SHA-256 digest of the bytes. Thus the same bytes always give the same URL,
/// and a second write does not write again.
nonisolated enum ContentBlockFile {
  /// The folder that holds the block files.
  static let directory = URL.temporaryDirectory
    .appending(path: "AgentViewKit-ContentBlocks", directoryHint: .isDirectory)

  /// The uniform type of a MIME type.
  ///
  /// - Parameters:
  ///   - mimeType: The MIME type, or `nil`.
  ///   - fallback: The type to use when the MIME type has no uniform type.
  /// - Returns: The type of `mimeType`, or `fallback`.
  static func type(mimeType: String?, fallback: UTType) -> UTType {
    mimeType.flatMap { UTType(mimeType: $0) } ?? fallback
  }

  /// The file name of a block.
  ///
  /// - Parameters:
  ///   - uri: The URI of the block, or `nil`.
  ///   - mimeType: The MIME type of the block.
  ///   - stem: The name to use when the URI has no file name.
  /// - Returns: The last path part of `uri`. When `uri` has no file name,
  ///   `stem` with the preferred extension of `mimeType`, or `stem` alone
  ///   when the MIME type has no extension.
  static func fileName(uri: String?, mimeType: String?, stem: String) -> String {
    if let name = uri.flatMap({ URL(string: $0) })?.lastPathComponent,
      !["", "/", ".", ".."].contains(name)
    {
      return name
    }
    guard let pathExtension = mimeType.flatMap({ UTType(mimeType: $0) })?.preferredFilenameExtension
    else { return stem }
    return "\(stem).\(pathExtension)"
  }

  /// Writes bytes to a block file, or finds the file of an earlier write.
  ///
  /// The write occurs off the main actor.
  ///
  /// - Parameters:
  ///   - data: The bytes of the block.
  ///   - name: The file name.
  /// - Returns: The URL of the file, or `nil` when the write fails.
  @concurrent
  static func write(_ data: Data, named name: String) async -> URL? {
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    let folder = directory.appending(path: digest, directoryHint: .isDirectory)
    let file = folder.appending(path: name, directoryHint: .notDirectory)
    let manager = FileManager.default
    if manager.fileExists(atPath: file.path(percentEncoded: false)) {
      return file
    }
    do {
      try manager.createDirectory(at: folder, withIntermediateDirectories: true)
      try data.write(to: file, options: .atomic)
      return file
    } catch {
      return nil
    }
  }
}
