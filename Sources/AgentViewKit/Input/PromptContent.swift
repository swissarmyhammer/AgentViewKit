import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import UniformTypeIdentifiers

extension ConnectionModel {
  /// The prompt capabilities that the agent advertised in its `initialize`
  /// answer, or `nil` when it advertised none.
  ///
  /// The value reads `agentCapabilities` at each call, so a view that reads it
  /// observes the model and keeps no copy.
  var promptCapabilities: PromptCapabilities? {
    agentCapabilities?.session?.prompt
  }
}

/// The prompt content of a user input for the prompt capabilities of an agent
/// (update.md §9.4).
///
/// The caller reads the capabilities from the connection model
/// (`ConnectionModel.promptCapabilities`) at the time of use, and keeps no
/// copy of them. The functions keep no state: the result comes only from the
/// input, the capabilities, and the attached files.
///
/// ACP sends an image block only to an agent that advertises `image`, and an
/// embedded `resource` block only to an agent that advertises
/// `embeddedContext`. Text and `resource_link` blocks go to each agent.
enum PromptContent {
  /// The MIME type of an attachment with no known type.
  private static let defaultMimeType = "application/octet-stream"

  /// The keys of the contents of an embedded resource. ACP gives the
  /// contents as a raw JSON value.
  private enum ResourceKey {
    /// The location of the resource.
    static let uri = "uri"
    /// The MIME type of the resource.
    static let mimeType = "mimeType"
    /// The text of a text resource.
    static let text = "text"
    /// The base64 data of a binary resource.
    static let blob = "blob"
  }

  /// Tells whether the agent accepts an attached file.
  ///
  /// An image file needs the `image` capability. The agent accepts each other
  /// file, as an embedded resource or as a resource link.
  ///
  /// - Parameters:
  ///   - url: The location of the attached file.
  ///   - capabilities: The prompt capabilities of the agent, or `nil` when
  ///     the agent advertises none.
  /// - Returns: `false` for an image file when the agent does not advertise
  ///   `image`, else `true`.
  static func isAccepted(attachmentAt url: URL, by capabilities: PromptCapabilities?) -> Bool {
    !isImage(at: url) || capabilities?.image != nil
  }

  /// Makes the prompt blocks of a user input.
  ///
  /// - Parameters:
  ///   - input: The text and the attachments.
  ///   - capabilities: The prompt capabilities of the agent, or `nil` when
  ///     the agent advertises none.
  /// - Returns: A `text` block, then one block for each attachment that the
  ///   agent accepts (``isAccepted(attachmentAt:by:)``), in order.
  static func makeBlocks(
    for input: UserInput, accepting capabilities: PromptCapabilities?
  ) -> [FoundationModelsACP.ContentBlock] {
    let embedsFiles = capabilities?.embeddedContext != nil
    let attachmentBlocks = input.attachments
      .filter { isAccepted(attachmentAt: $0, by: capabilities) }
      .map { makeBlock(forAttachmentAt: $0, embeddingFiles: embedsFiles) }
    return [.text(FoundationModelsACP.TextContent(text: input.text))] + attachmentBlocks
  }

  /// Tells whether an attached file is an image, from its file name
  /// extension.
  ///
  /// - Parameter url: The location of the attached file.
  /// - Returns: `true` when the type of the extension conforms to `public.image`.
  private static func isImage(at url: URL) -> Bool {
    UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) == true
  }

  /// Makes the prompt block of one accepted attachment.
  ///
  /// - Parameters:
  ///   - url: The location of the attached file.
  ///   - embeddingFiles: Whether the agent advertises `embeddedContext`.
  /// - Returns: An `image` block with base64 data for an image file that can
  ///   be read. Else an embedded `resource` block when `embeddingFiles` is
  ///   `true` and the file can be read. Else a `resource_link` block.
  private static func makeBlock(
    forAttachmentAt url: URL, embeddingFiles: Bool
  ) -> FoundationModelsACP.ContentBlock {
    let type = UTType(filenameExtension: url.pathExtension)
    let mimeType = type?.preferredMIMEType ?? defaultMimeType
    if isImage(at: url), let data = try? Data(contentsOf: url) {
      return .image(
        FoundationModelsACP.ImageContent(
          data: data.base64EncodedString(), mimeType: MediaType(rawValue: mimeType), uri: url.absoluteString))
    }
    if embeddingFiles, let data = try? Data(contentsOf: url) {
      let resource = makeResourceContents(
        of: data, at: url, isText: type?.conforms(to: .text) == true, mimeType: mimeType)
      return .resource(FoundationModelsACP.EmbeddedResource(resource: resource))
    }
    return .resourceLink(
      FoundationModelsACP.ResourceLink(
        name: url.lastPathComponent, uri: url.absoluteString, mimeType: MediaType(rawValue: mimeType)))
  }

  /// Makes the contents of an embedded resource.
  ///
  /// - Parameters:
  ///   - data: The bytes of the file.
  ///   - url: The location of the file.
  ///   - isText: Whether the type of the file is a text type.
  ///   - mimeType: The MIME type of the file.
  /// - Returns: A text resource for a text file with UTF-8 bytes, else a blob
  ///   resource with base64 data.
  private static func makeResourceContents(
    of data: Data, at url: URL, isText: Bool, mimeType: String
  ) -> FoundationModelsACP.JSONValue {
    var members: [String: FoundationModelsACP.JSONValue] = [
      ResourceKey.uri: .string(url.absoluteString), ResourceKey.mimeType: .string(mimeType),
    ]
    if isText, let text = String(data: data, encoding: .utf8) {
      members[ResourceKey.text] = .string(text)
    } else {
      members[ResourceKey.blob] = .string(data.base64EncodedString())
    }
    return .object(members)
  }
}
