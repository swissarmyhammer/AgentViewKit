import AppKit
import EditorCommandsUI
import EditorStyle
import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import SwiftUI

/// The collapsible "Sources" footer of a response (plan.md §9 C).
///
/// The view shows one row for each ``CitationSource`` of a
/// ``CitationPayload``, in payload order. A row has the number of the source,
/// the link of the source, and the snippet of the source. The link is a
/// ``LinkView`` card that opens the source in the browser, after the link
/// mark (``SharedSymbol/link``).
///
/// The footer is open by default. When an ``InlineCitation`` of the same
/// ``SwiftUI/View/citationScope()`` selects a source, the footer opens, the
/// row of the source is the current source, and the row scrolls into view.
///
/// The accent is only for the selection and the focus (card ^y2mrfxt). A row
/// is neither, so the link has no accent text color, and the current source
/// has no accent and no fill: it looks the same as each other row.
///
/// The footer is an accessibility container with the identifier `sources`.
/// Each row is a container with the identifier `sources-row-<index>`. The
/// number of a row is an element with the label "Source <index>" and the
/// identifier `sources-number-<index>`. The number of the current source has
/// the value ``highlightedValue`` and the selected trait. The link mark of a
/// row is an element with the label "Link" and the identifier
/// `sources-link-mark-<index>`.
public struct SourcesView: View {
  /// The accessibility identifier of the footer.
  public static let identifier = "sources"

  /// The start of the accessibility identifier of each row.
  public static let rowIdentifierPrefix = "sources-row-"

  /// The start of the accessibility identifier of the number of each row.
  public static let numberIdentifierPrefix = "sources-number-"

  /// The start of the accessibility identifier of the link mark of each row.
  public static let linkMarkIdentifierPrefix = "sources-link-mark-"

  /// The accessibility value of the number of the current source.
  public static let highlightedValue = "Highlighted"

  /// The payload to show.
  let payload: CitationPayload

  /// Whether the footer shows its rows.
  @State private var isExpanded: Bool

  @Environment(\.citationSelection) private var selection
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

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

  /// The accessibility identifier of the link mark in the row of a source.
  ///
  /// - Parameter index: The one-based number of the source.
  /// - Returns: `sources-link-mark-<index>`.
  public static func linkMarkIdentifier(index: Int) -> String {
    AccessibilityIdentifier.make(prefix: linkMarkIdentifierPrefix, value: String(index))
  }

  public var body: some View {
    let highlighted = selection?.index
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
        ForEach(Array(payload.sources.enumerated()), id: \.offset) { position, source in
          let index = position + 1
          SourceRow(
            index: index,
            source: source,
            scrollRequest: highlighted == index ? selection?.revision : nil
          )
        }
      }
      .padding(.top, editorStyle.spacing.xs)
    } label: {
      Label {
        Text("Sources (\(payload.sources.count))", bundle: .module)
      } icon: {
        Image(systemName: SharedSymbol.sources)
      }
      .font(editorTheme.font(for: .ui, style: .subheadline))
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
///
/// The row is not the selection and has no focus, so it draws no accent and
/// no fill, also while it is the current source (card ^y2mrfxt). The current
/// source differs only in its accessibility value, its selected trait and the
/// scroll that brings it into view.
private struct SourceRow: View {
  /// The largest count of snippet lines.
  static let snippetLineLimit = 3

  /// The one-based number of the source.
  let index: Int

  /// The source to show.
  let source: CitationSource

  /// The selection revision that makes this row the current source, or `nil`
  /// when the row is not the current source. A new value scrolls the row into
  /// view.
  let scrollRequest: Int?

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    let isCurrent = scrollRequest != nil
    HStack(alignment: .firstTextBaseline, spacing: editorStyle.spacing.s) {
      InlineCitationPill(index: index)
        .accessibilityElement()
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(Text("Source \(index)", bundle: .module))
        .accessibilityValue(isCurrent ? Text(SourcesView.highlightedValue) : Text(verbatim: ""))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityIdentifier(SourcesView.numberIdentifier(index: index))
      VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
        SourceLink(index: index, source: source)
        if !source.snippet.isEmpty {
          Text(source.snippet)
            .font(editorTheme.font(for: .ui, style: .caption))
            .foregroundStyle(.secondary)
            .lineLimit(Self.snippetLineLimit)
        }
      }
    }
    .padding(editorStyle.spacing.xs)
    .background(ScrollIntoView(request: scrollRequest))
    .contentContainer(identifier: SourcesView.rowIdentifier(index: index))
  }
}

/// The link of one source: the link mark, then a ``LinkView`` card that opens
/// the source in the browser.
///
/// A link does not use the accent as its text color: the accent is only for
/// the selection and the focus (card ^y2mrfxt). The link mark
/// (``SharedSymbol/link``) marks the link in its place, with the `.secondary`
/// style and the symbol weight of the shared style. Unlike a
/// `DecorativeSymbolImage`, the mark is an accessibility element with the
/// label "Link", because it tells what the card after it is.
private struct SourceLink: View {
  /// The one-based number of the source.
  let index: Int

  /// The source to link to.
  let source: CitationSource

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    HStack(spacing: editorStyle.spacing.xs) {
      Image(systemName: SharedSymbol.link)
        .foregroundStyle(.secondary)
        .fontWeight(editorStyle.symbolWeight)
        .accessibilityLabel(Text("Link", bundle: .module))
        .accessibilityIdentifier(SourcesView.linkMarkIdentifier(index: index))
      LinkView(link: link)
    }
  }

  /// The ACP resource link of the source, for the ``LinkView`` card.
  private var link: ResourceLink {
    ResourceLink(
      name: source.title,
      uri: source.url.absoluteString,
      icons: source.iconURL.map { [Icon(src: $0.absoluteString)] }
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
    let reportScroll = context.environment.citationScrollReport
    // The layout of this update is not done yet. Scroll after it.
    Task { @MainActor in
      view.scrollToVisible(view.bounds)
      reportScroll?(request)
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

extension EnvironmentValues {
  /// The ``ObservationReport`` that gets the selection revision of each scroll
  /// that a row of a ``SourcesView`` did, or `nil`.
  ///
  /// The row scrolls in a task after the update, and calls the report in the
  /// same step as the scroll. Thus a test waits for the report before it reads
  /// the scroll position.
  @Entry var citationScrollReport: ObservationReport<Int>? = nil
}

#Preview("Sources") {
  SourcesView(payload: PreviewFixtures.citations)
}
