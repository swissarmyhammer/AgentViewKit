import Foundation

/// The sources of a response and the places in the response that cite them
/// (plan.md §3.3, §9 C).
///
/// The schema name is `AgentViewKit.CitationPayload`. `SourcesView` shows the
/// sources. `InlineCitation` shows each marker.
public nonisolated struct CitationPayload: StructuredPayload, Hashable {
  /// The cited sources, in display order.
  public var sources: [CitationSource]

  /// The places in the response that cite a source.
  public var markers: [CitationMarker]

  /// Makes a citation payload.
  ///
  /// - Parameters:
  ///   - sources: The cited sources, in display order.
  ///   - markers: The places in the response that cite a source.
  public init(sources: [CitationSource], markers: [CitationMarker]) {
    self.sources = sources
    self.markers = markers
  }
}

/// One source that a response cites.
public nonisolated struct CitationSource: Codable, Sendable, Hashable, Identifiable {
  /// The identifier of the source. A ``CitationMarker`` refers to it.
  public var id: String

  /// The title of the source.
  public var title: String

  /// The location of the source.
  public var url: URL

  /// A short part of the source text. It is empty when the source gives none.
  public var snippet: String

  /// The location of the icon of the source, or `nil` when it has none.
  public var iconURL: URL?

  /// Makes a citation source.
  ///
  /// - Parameters:
  ///   - id: The identifier of the source.
  ///   - title: The title of the source.
  ///   - url: The location of the source.
  ///   - snippet: A short part of the source text.
  ///   - iconURL: The location of the icon of the source, or `nil`.
  public init(id: String, title: String, url: URL, snippet: String, iconURL: URL? = nil) {
    self.id = id
    self.title = title
    self.url = url
    self.snippet = snippet
    self.iconURL = iconURL
  }
}

/// One place in a response that cites a source.
public nonisolated struct CitationMarker: Codable, Sendable, Hashable {
  /// The ``CitationSource/id`` of the cited source.
  public var sourceID: String

  /// The zero-based index of the paragraph that holds the marker.
  public var paragraphIndex: Int

  /// The zero-based character offset of the marker in its paragraph.
  public var offset: Int

  /// Makes a citation marker.
  ///
  /// - Parameters:
  ///   - sourceID: The identifier of the cited source.
  ///   - paragraphIndex: The zero-based index of the paragraph.
  ///   - offset: The zero-based character offset in the paragraph.
  public init(sourceID: String, paragraphIndex: Int, offset: Int) {
    self.sourceID = sourceID
    self.paragraphIndex = paragraphIndex
    self.offset = offset
  }
}
