import AppKit
import SwiftUI

/// The collapsible "Sources" footer of a response (plan.md §9 C).
///
/// The view shows one row for each ``CitationSource`` of a
/// ``CitationPayload``, in payload order. A row has the number of the source,
/// a ``LinkView`` card that opens the source in the browser, and the snippet
/// of the source.
///
/// The footer is open by default. When an ``InlineCitation`` of the same
/// ``SwiftUI/View/citationScope()`` selects a source, the footer opens, the
/// row of the source shows the highlight, and the row scrolls into view.
///
/// The ``StructuredItemRegistry/standard`` registry shows each structured
/// value with the schema name `AgentViewKit.CitationPayload` in this view.
/// The footer is an accessibility container with the identifier `sources`.
/// Each row is a container with the identifier `sources-row-<index>`. The
/// number of a row is an element with the label "Source <index>" and the
/// identifier `sources-number-<index>`. The number of the highlighted row has
/// the value ``highlightedValue`` and the selected trait.
public struct SourcesView: View {
  /// The accessibility identifier of the footer.
  public static let identifier = "sources"

  /// The start of the accessibility identifier of each row.
  public static let rowIdentifierPrefix = "sources-row-"

  /// The start of the accessibility identifier of the number of each row.
  public static let numberIdentifierPrefix = "sources-number-"

  /// The accessibility value of the number of the highlighted row.
  public static let highlightedValue = "Highlighted"

  /// The payload to show.
  let payload: CitationPayload

  /// Whether the footer shows its rows.
  @State private var isExpanded: Bool

  @Environment(\.citationSelection) private var selection
  @Environment(\.agentTheme) private var theme

  /// Makes the footer of a citation payload.
  ///
  /// - Parameters:
  ///   - payload: The payload to show.
  ///   - isExpanded: Whether the footer shows its rows at the start. The
  ///     default is open.
  public init(payload: CitationPayload, isExpanded: Bool = true) {
    self.payload = payload
    _isExpanded = State(initialValue: isExpanded)
  }

  /// The accessibility identifier of the row of a source.
  ///
  /// - Parameter index: The one-based number of the source.
  /// - Returns: `sources-row-<index>`.
  public static func rowIdentifier(index: Int) -> String {
    AccessibilityIdentifier.make(prefix: rowIdentifierPrefix, value: String(index))
  }

  /// The accessibility identifier of the number in the row of a source.
  ///
  /// - Parameter index: The one-based number of the source.
  /// - Returns: `sources-number-<index>`.
  public static func numberIdentifier(index: Int) -> String {
    AccessibilityIdentifier.make(prefix: numberIdentifierPrefix, value: String(index))
  }

  public var body: some View {
    let highlighted = selection?.index
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: theme.spacing.s) {
        ForEach(Array(payload.sources.enumerated()), id: \.offset) { position, source in
          let index = position + 1
          SourceRow(
            index: index,
            source: source,
            scrollRequest: highlighted == index ? selection?.revision : nil
          )
        }
      }
      .padding(.top, theme.spacing.xs)
    } label: {
      Label {
        Text("Sources (\(payload.sources.count))")
      } icon: {
        Image(systemName: "books.vertical")
      }
      .font(.subheadline)
      .foregroundStyle(.secondary)
    }
    .onChange(of: selection?.revision) {
      guard let index = selection?.index, payload.sources.indices.contains(index - 1) else { return }
      isExpanded = true
    }
    .contentContainer(identifier: Self.identifier)
  }
}

/// One row of a ``SourcesView``.
private struct SourceRow: View {
  /// The opacity of the accent color behind the highlighted row.
  static let highlightOpacity = 0.14

  /// The largest count of snippet lines.
  static let snippetLineLimit = 3

  /// The one-based number of the source.
  let index: Int

  /// The source to show.
  let source: CitationSource

  /// The selection revision that highlights this row, or `nil` when the row
  /// has no highlight. A new value scrolls the row into view.
  let scrollRequest: Int?

  @Environment(\.agentTheme) private var theme

  var body: some View {
    let isHighlighted = scrollRequest != nil
    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
      InlineCitationPill(index: index)
        .accessibilityElement()
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text("Source \(index)"))
        .accessibilityValue(isHighlighted ? Text(SourcesView.highlightedValue) : Text(""))
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
        .accessibilityIdentifier(SourcesView.numberIdentifier(index: index))
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        LinkView(link: link)
        if !source.snippet.isEmpty {
          Text(source.snippet)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(Self.snippetLineLimit)
        }
      }
    }
    .padding(theme.spacing.xs)
    .background(
      RoundedRectangle(cornerRadius: theme.radii.s)
        .fill(isHighlighted ? AnyShapeStyle(theme.accent.opacity(Self.highlightOpacity)) : AnyShapeStyle(.clear))
    )
    .background(ScrollIntoView(request: scrollRequest))
    .contentContainer(identifier: SourcesView.rowIdentifier(index: index))
  }

  /// The resource link of the source, for the ``LinkView`` card.
  private var link: ResourceLink {
    ResourceLink(
      name: source.title,
      uri: source.url.absoluteString,
      icons: source.iconURL.map { [ResourceIcon(src: $0.absoluteString)] } ?? []
    )
  }
}

/// Scrolls the enclosing AppKit scroll view to show this view, one time for
/// each new request.
///
/// SwiftUI has no scroll action that a row can use on a scroll view that is
/// not in its subtree. The AppKit `scrollToVisible(_:)` action goes up to the
/// enclosing `NSScrollView`. Put this view in the background of the row, so
/// that it has the frame of the row.
private struct ScrollIntoView: NSViewRepresentable {
  /// The request to do, or `nil` for no request.
  let request: Int?

  func makeNSView(context: Context) -> NSView {
    NSView()
  }

  func updateNSView(_ view: NSView, context: Context) {
    guard let request, request != context.coordinator.lastRequest else { return }
    context.coordinator.lastRequest = request
    // The layout of this update is not done yet. Scroll after it.
    Task { @MainActor in
      view.scrollToVisible(view.bounds)
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  /// Keeps the last request that the view did.
  final class Coordinator {
    /// The last request that the view did, or `nil`.
    var lastRequest: Int?
  }
}

// MARK: - Registry

extension KeyedViewRegistry where Key == String, Value == StructuredItemContent {
  /// The default structured item registry of the kit (plan.md §9 C).
  ///
  /// The registry shows each `AgentViewKit.CitationPayload` value in a
  /// ``SourcesView``. A value that does not decode shows in a
  /// ``StructuredItemView``. The environment starts with this registry, and a
  /// ``SwiftUI/View/structuredItem(_:_:)`` registration for the same name
  /// replaces it.
  public static var standard: StructuredItemRegistry {
    var registry = StructuredItemRegistry()
    registry.register(CitationPayload.schemaName) { content in
      AnyView(CitationContentView(content: content))
    }
    return registry
  }
}

/// The view of a structured citation value: a ``SourcesView``, or a
/// ``StructuredItemView`` when the value does not decode.
private struct CitationContentView: View {
  /// The structured value.
  let content: StructuredItemContent

  var body: some View {
    if let payload = try? CitationPayload(content: content.payload) {
      SourcesView(payload: payload)
    } else {
      StructuredItemView(
        content: content, id: content.schemaName + ":" + content.payload.jsonString)
    }
  }
}
