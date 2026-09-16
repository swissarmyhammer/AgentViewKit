import Foundation
import UniformTypeIdentifiers

/// The identifier of an ``Attachment``.
public typealias AttachmentID = Identifier<Attachment>

/// A file that a prompt, a message, or an artifact holds (plan.md §3.6).
///
/// The ``type`` selects the view of the file. See ``AttachmentView``.
public nonisolated struct Attachment: Identifiable, Hashable, Sendable {
  /// The resource values that ``init(url:)`` reads.
  private static let resourceKeys: Set<URLResourceKey> = [.contentTypeKey, .fileSizeKey]

  /// The identifier of the attachment.
  public var id: AttachmentID

  /// The location of the file.
  public var url: URL

  /// The uniform type of the file.
  public var type: UTType

  /// The file name to show, with its extension.
  public var name: String

  /// The size of the file in bytes, or `nil` when the size is not known.
  public var size: Int?

  /// Makes an attachment from known values.
  ///
  /// - Parameters:
  ///   - id: The identifier of the attachment.
  ///   - url: The location of the file.
  ///   - type: The uniform type of the file.
  ///   - name: The file name to show.
  ///   - size: The size of the file in bytes, or `nil`.
  public init(id: AttachmentID, url: URL, type: UTType, name: String, size: Int? = nil) {
    self.id = id
    self.url = url
    self.type = type
    self.name = name
    self.size = size
  }

  /// Makes an attachment for the file at `url`.
  ///
  /// The identifier is the absolute URL string. The name is the last path
  /// component. The type comes from the file name extension. When the
  /// extension has no declared type, the type comes from the content type
  /// resource value of the file. When both are missing, the type is
  /// `public.data`. The size comes from the file size resource value. A URL
  /// that is not a local file has no resource values, so its size is `nil`.
  ///
  /// - Parameter url: The location of the file.
  public init(url: URL) {
    let values = try? url.resourceValues(forKeys: Self.resourceKeys)
    self.init(
      id: AttachmentID(url.absoluteString),
      url: url,
      type: Self.type(ofExtension: url.pathExtension, contentType: values?.contentType),
      name: url.lastPathComponent,
      size: values?.fileSize
    )
  }

  /// The type of a file.
  ///
  /// - Parameters:
  ///   - pathExtension: The file name extension, which can be empty.
  ///   - contentType: The content type resource value, or `nil`.
  /// - Returns: The declared type of the extension, else `contentType`,
  ///   else `public.data`.
  private static func type(ofExtension pathExtension: String, contentType: UTType?) -> UTType {
    if let declared = UTType(filenameExtension: pathExtension), declared.isDeclared {
      return declared
    }
    return contentType ?? .data
  }
}
