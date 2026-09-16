import Foundation

/// A file or document that the agent made (plan.md §3.3).
///
/// The schema name is `AgentViewKit.ArtifactPayload`. The payload has a
/// ``url``, an ``inlineText``, or both.
public nonisolated struct ArtifactPayload: StructuredPayload, Hashable, Identifiable {
  /// The identifier of the artifact.
  public var id: String

  /// The title of the artifact.
  public var title: String

  /// The uniform type identifier of the artifact, such as
  /// `public.plain-text`. The attachment registry uses it to find a view.
  public var type: String

  /// The location of the artifact, or `nil` when the payload holds only
  /// ``inlineText``.
  public var url: URL?

  /// The text of the artifact, or `nil` when the payload holds only ``url``.
  public var inlineText: String?

  /// Makes an artifact payload.
  ///
  /// - Parameters:
  ///   - id: The identifier of the artifact.
  ///   - title: The title of the artifact.
  ///   - type: The uniform type identifier of the artifact.
  ///   - url: The location of the artifact, or `nil`.
  ///   - inlineText: The text of the artifact, or `nil`.
  public init(id: String, title: String, type: String, url: URL? = nil, inlineText: String? = nil) {
    self.id = id
    self.title = title
    self.type = type
    self.url = url
    self.inlineText = inlineText
  }
}
