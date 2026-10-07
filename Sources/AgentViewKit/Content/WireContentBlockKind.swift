import FoundationModelsACP

nonisolated extension FoundationModelsACP.ContentBlock {
  /// The type of an ACP content block, with no values (plan.md §3.6).
  ///
  /// The ``ContentBlockRegistry`` uses this type as its key. Register a view
  /// for a kind with ``SwiftUI/View/contentBlockView(for:_:)``.
  public enum Kind: Sendable, Hashable, CaseIterable {
    /// A `text` block.
    case text

    /// An `image` block.
    case image

    /// An `audio` block.
    case audio

    /// A `resource_link` block.
    case resourceLink

    /// A `resource` block, with embedded contents.
    case resource

    /// A block with a `type` that the ACP revision of the kit does not know.
    case unknown
  }

  /// The kind of the block.
  public var kind: Kind {
    switch self {
    case .text: .text
    case .image: .image
    case .audio: .audio
    case .resourceLink: .resourceLink
    case .resource: .resource
    case .unknown: .unknown
    }
  }
}
