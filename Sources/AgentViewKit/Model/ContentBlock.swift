import Foundation

/// One part of the content of a message (plan.md §3.2).
///
/// A block has content and optional annotations. The renderer hides a block
/// that is not for the user. When the renderer must show fewer blocks, it
/// shows the blocks with the highest priority first.
public nonisolated struct ContentBlock: Sendable, Hashable {
  /// The content of the block.
  public var content: Content

  /// The audience and the priority of the block, if the source gave them.
  public var annotations: Annotations?

  /// Makes a content block.
  ///
  /// - Parameters:
  ///   - content: The content of the block.
  ///   - annotations: The audience and the priority of the block.
  public init(content: Content, annotations: Annotations? = nil) {
    self.content = content
    self.annotations = annotations
  }

  /// Makes a text block with no annotations.
  ///
  /// - Parameter text: The text of the block.
  public init(text: String) {
    self.init(content: .text(text))
  }

  /// The type of the content, with no values.
  public var kind: Kind {
    switch content {
    case .text: .text
    case .image: .image
    case .audio: .audio
    case .resourceLink: .resourceLink
    case .resource: .resource
    case .attachment: .attachment
    case .structured: .structured
    case .unknown: .unknown
    }
  }

  /// Tells if the block is for an audience.
  ///
  /// A block with no audience is for each audience. A block with an audience
  /// list is only for the audiences in the list. An empty list is for no
  /// audience.
  ///
  /// - Parameter audience: The audience to examine.
  /// - Returns: `true` when the block is for `audience`.
  public func isVisible(to audience: Audience) -> Bool {
    guard let audiences = annotations?.audience else { return true }
    return audiences.contains(audience)
  }

  /// The content of a block.
  public enum Content: Sendable, Hashable {
    /// Text, as Markdown.
    case text(String)

    /// An image.
    case image(ImageContent)

    /// A sound.
    case audio(AudioContent)

    /// A link to a resource that the client can get.
    case resourceLink(ResourceLink)

    /// A resource with its contents.
    case resource(EmbeddedResource)

    /// A local file.
    case attachment(URL)

    /// A structured value, keyed by its schema name.
    ///
    /// - Parameters:
    ///   - schemaName: The schema name of the value.
    ///   - payload: The value.
    case structured(schemaName: String, payload: JSONValue)

    /// Content that the kit does not know.
    ///
    /// - Parameters:
    ///   - kind: The type name that the source gave.
    ///   - raw: The content as the source gave it.
    case unknown(kind: String, raw: JSONValue)
  }

  /// The type of a block, with no values.
  ///
  /// The view registry uses this type as a key (plan.md §3.6).
  public enum Kind: Sendable, Hashable, CaseIterable {
    /// A ``Content/text(_:)`` block.
    case text

    /// A ``Content/image(_:)`` block.
    case image

    /// A ``Content/audio(_:)`` block.
    case audio

    /// A ``Content/resourceLink(_:)`` block.
    case resourceLink

    /// A ``Content/resource(_:)`` block.
    case resource

    /// A ``Content/attachment(_:)`` block.
    case attachment

    /// A ``Content/structured(schemaName:payload:)`` block.
    case structured

    /// A ``Content/unknown(kind:raw:)`` block.
    case unknown
  }
}

/// The audience and the priority of a content block (plan.md §3.2).
///
/// The fields are the fields of an ACP `Annotations` value.
public nonisolated struct Annotations: Sendable, Hashable {
  /// The audiences that the block is for, or `nil` for each audience.
  public var audience: [Audience]?

  /// The importance of the block, from 0 to 1, or `nil` if not known.
  public var priority: Double?

  /// Makes annotations.
  ///
  /// - Parameters:
  ///   - audience: The audiences that the block is for.
  ///   - priority: The importance of the block.
  public init(audience: [Audience]? = nil, priority: Double? = nil) {
    self.audience = audience
    self.priority = priority
  }
}

/// An audience of a content block (plan.md §3.2).
///
/// The wire values are the ACP `Role` strings.
public nonisolated enum Audience: WireValueEnum, Codable {
  /// The user.
  case user

  /// The model.
  case assistant

  /// An audience that the kit does not know, with its wire string.
  case unknown(String)

  /// Each case of the enum, but not ``unknown(_:)``.
  public static let knownCases: [Audience] = [.user, .assistant]

  /// The ACP wire string of the case.
  public var wireValue: String {
    switch self {
    case .user: "user"
    case .assistant: "assistant"
    case .unknown(let wireValue): wireValue
    }
  }
}

/// An image in a content block.
public nonisolated struct ImageContent: Sendable, Hashable {
  /// The bytes of the image.
  public var data: Data

  /// The MIME type of the image, such as `image/png`.
  public var mimeType: String

  /// The URI of the image, if the source gave one.
  public var uri: String?

  /// Makes image content.
  ///
  /// - Parameters:
  ///   - data: The bytes of the image.
  ///   - mimeType: The MIME type of the image.
  ///   - uri: The URI of the image.
  public init(data: Data, mimeType: String, uri: String? = nil) {
    self.data = data
    self.mimeType = mimeType
    self.uri = uri
  }
}

/// A sound in a content block.
public nonisolated struct AudioContent: Sendable, Hashable {
  /// The bytes of the sound.
  public var data: Data

  /// The MIME type of the sound, such as `audio/wav`.
  public var mimeType: String

  /// Makes audio content.
  ///
  /// - Parameters:
  ///   - data: The bytes of the sound.
  ///   - mimeType: The MIME type of the sound.
  public init(data: Data, mimeType: String) {
    self.data = data
    self.mimeType = mimeType
  }
}

/// A link to a resource that the client can get.
///
/// The fields are the fields of an ACP `ResourceLink` value that the kit
/// shows.
public nonisolated struct ResourceLink: Sendable, Hashable {
  /// The name of the resource.
  public var name: String

  /// The URI of the resource.
  public var uri: String

  /// The icons of the resource.
  public var icons: [ResourceIcon]

  /// The MIME type of the resource, if the source gave one.
  public var mimeType: String?

  /// Makes a resource link.
  ///
  /// - Parameters:
  ///   - name: The name of the resource.
  ///   - uri: The URI of the resource.
  ///   - icons: The icons of the resource.
  ///   - mimeType: The MIME type of the resource.
  public init(name: String, uri: String, icons: [ResourceIcon] = [], mimeType: String? = nil) {
    self.name = name
    self.uri = uri
    self.icons = icons
    self.mimeType = mimeType
  }
}

/// An icon of a resource link.
///
/// The fields are the fields of an ACP `Icon` value that the kit uses.
public nonisolated struct ResourceIcon: Sendable, Hashable {
  /// The URI of the icon.
  public var src: String

  /// The MIME type of the icon, if the source gave one.
  public var mimeType: String?

  /// The sizes of the icon, such as `48x48` or `any`. An empty list means
  /// each size.
  public var sizes: [String]

  /// Makes a resource icon.
  ///
  /// - Parameters:
  ///   - src: The URI of the icon.
  ///   - mimeType: The MIME type of the icon.
  ///   - sizes: The sizes of the icon.
  public init(src: String, mimeType: String? = nil, sizes: [String] = []) {
    self.src = src
    self.mimeType = mimeType
    self.sizes = sizes
  }
}

/// A resource with its contents.
public nonisolated struct EmbeddedResource: Sendable, Hashable {
  /// The URI of the resource.
  public var uri: String

  /// The MIME type of the resource, if the source gave one.
  public var mimeType: String?

  /// The contents of the resource.
  public var contents: Contents

  /// Makes an embedded resource.
  ///
  /// - Parameters:
  ///   - uri: The URI of the resource.
  ///   - mimeType: The MIME type of the resource.
  ///   - contents: The contents of the resource.
  public init(uri: String, mimeType: String? = nil, contents: Contents) {
    self.uri = uri
    self.mimeType = mimeType
    self.contents = contents
  }

  /// The contents of an embedded resource.
  public enum Contents: Sendable, Hashable {
    /// Text contents.
    case text(String)

    /// Binary contents.
    case blob(Data)
  }
}

nonisolated extension Sequence where Element == ContentBlock {
  /// The blocks that are for an audience, in the same order.
  ///
  /// - Parameter audience: The audience to examine.
  /// - Returns: Each block where ``ContentBlock/isVisible(to:)`` is `true`.
  public func visible(to audience: Audience) -> [ContentBlock] {
    filter { $0.isVisible(to: audience) }
  }

  /// The blocks, with the highest priority first.
  ///
  /// A block with no priority goes after each block with a priority. Blocks
  /// with the same priority keep their order.
  ///
  /// - Returns: The sorted blocks.
  public func sortedByPriority() -> [ContentBlock] {
    enumerated()
      .sorted { lhs, rhs in
        let lhsPriority = lhs.element.annotations?.priority
        let rhsPriority = rhs.element.annotations?.priority
        if lhsPriority == rhsPriority { return lhs.offset < rhs.offset }
        guard let lhsPriority else { return false }
        guard let rhsPriority else { return true }
        return lhsPriority > rhsPriority
      }
      .map(\.element)
  }
}
