import AppKit
import Observation
import SwiftUI

// MARK: - Selection

/// The source that the user selected with an ``InlineCitation``
/// (plan.md §9 C).
///
/// ``SwiftUI/View/citationScope()`` makes one selection for its subtree. An
/// ``InlineCitation`` sets the selection, and the ``SourcesView`` of the same
/// scope highlights the selected row and scrolls it into view.
@Observable
public final class CitationSelection {
  /// The one-based number of the selected source, or `nil` when the user
  /// selected no source.
  public private(set) var index: Int?

  /// The count of selections. Each selection adds one, also a selection of the
  /// same source again, so that the row scrolls into view each time.
  public private(set) var revision = 0

  /// Makes an empty selection.
  public init() {}

  /// Selects a source.
  ///
  /// - Parameter index: The one-based number of the source.
  public func select(_ index: Int) {
    self.index = index
    revision += 1
  }

  /// Removes the selection.
  public func clear() {
    index = nil
  }
}

extension EnvironmentValues {
  /// The citation selection of this subtree, or `nil` when no
  /// ``SwiftUI/View/citationScope()`` is above the view.
  @Entry public var citationSelection: CitationSelection? = nil
}

extension View {
  /// Gives this view one ``CitationSelection``, and sends each citation link
  /// to it.
  ///
  /// The modifier replaces the `openURL` action of the subtree. A citation
  /// link (``InlineCitation/url(index:)``) selects its source. Each other
  /// link goes to the `openURL` action of the environment of the modifier.
  /// ``AssistantMessageView`` and ``UserMessageView`` apply this modifier, so
  /// each message has its own selection.
  ///
  /// - Returns: A view with a citation selection.
  public func citationScope() -> some View {
    modifier(CitationScope())
  }
}

/// The modifier of ``SwiftUI/View/citationScope()``.
private struct CitationScope: ViewModifier {
  /// The selection of the scope.
  @State private var selection = CitationSelection()

  @Environment(\.openURL) private var openURL

  func body(content: Content) -> some View {
    let selection = selection
    let outer = openURL
    content
      .environment(\.citationSelection, selection)
      .environment(
        \.openURL,
        OpenURLAction { url in
          if let index = InlineCitation.index(of: url) {
            selection.select(index)
          } else {
            outer(url)
          }
          return .handled
        })
  }
}

// MARK: - Inline citation

/// A small numbered pill that cites one source of a response
/// (plan.md §9 C).
///
/// A press on the pill selects its source in the ``CitationSelection`` of the
/// environment. The ``SourcesView`` of the same scope then highlights the row
/// of the source and scrolls it into view.
///
/// ``ResponseView`` puts a pill in the prose at each ``CitationMarker`` of the
/// ``CitationPayload`` of the message. There, Textual draws the pill, the pill
/// opens ``url(index:)``, and ``SwiftUI/View/citationScope()`` gets the link.
///
/// The pill is an accessibility button with the label "Source <index>" and
/// the identifier `inline-citation-<index>`.
public struct InlineCitation: View {
  /// The start of the accessibility identifier of each pill.
  public static let identifierPrefix = "inline-citation-"

  /// The URL scheme of a citation link.
  public nonisolated static let urlScheme = "agentviewkit-citation"

  /// The one-based number of the cited source.
  let index: Int

  @Environment(\.citationSelection) private var selection

  /// Makes the pill of one source.
  ///
  /// - Parameter index: The one-based number of the source: its position in
  ///   ``CitationPayload/sources`` plus one.
  public init(index: Int) {
    self.index = index
  }

  /// The accessibility identifier of the pill of a source.
  ///
  /// - Parameter index: The one-based number of the source.
  /// - Returns: `inline-citation-<index>`.
  public static func identifier(index: Int) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: String(index))
  }

  /// The citation link of a source.
  ///
  /// - Parameter index: The one-based number of the source.
  /// - Returns: `agentviewkit-citation:<index>`, or `nil` when Foundation
  ///   cannot make the URL.
  public nonisolated static func url(index: Int) -> URL? {
    URL(string: "\(urlScheme):\(index)")
  }

  /// The source number of a citation link.
  ///
  /// - Parameter url: A URL.
  /// - Returns: The one-based number of the source, or `nil` when `url` is not
  ///   a citation link.
  public nonisolated static func index(of url: URL) -> Int? {
    guard url.scheme == urlScheme else { return nil }
    return URLComponents(url: url, resolvingAgainstBaseURL: false).flatMap { Int($0.path) }
  }

  public var body: some View {
    Button {
      selection?.select(index)
    } label: {
      InlineCitationPill(index: index)
    }
    .buttonStyle(.plain)
    .inlineCitationAccessibility(index: index)
  }
}

extension View {
  /// Gives this view the accessibility label, hint, and identifier of the
  /// pill of a source.
  ///
  /// Apply the modifier to a button, or to an element with the button trait
  /// and a press action.
  ///
  /// - Parameter index: The one-based number of the source.
  /// - Returns: A view with the label "Source <index>".
  func inlineCitationAccessibility(index: Int) -> some View {
    accessibilityLabel(Text("Source \(index)"))
      .accessibilityHint(Text("Shows the source in the list of sources."))
      .accessibilityIdentifier(InlineCitation.identifier(index: index))
  }
}

// MARK: - Pill

/// The sizes of a citation pill for one font size.
///
/// ``InlineCitationPill`` and the Textual attachment of a pill use the same
/// sizes, so that the pill fits the space that the text layout gives it.
nonisolated struct InlineCitationMetrics: Equatable, Sendable {
  /// The size of the pill digits, as a part of the text font size.
  static let fontScale: CGFloat = 0.75

  /// The space at the left and at the right of the digits, as a part of the
  /// digit font size.
  static let horizontalPaddingScale: CGFloat = 0.45

  /// The space above and below the digits, as a part of the digit font size.
  static let verticalPaddingScale: CGFloat = 0.1

  /// The weight of the digits.
  static let weight = NSFont.Weight.semibold

  /// The size of the digits, in points.
  let digitFontSize: CGFloat

  /// The size of the pill, in points.
  let size: CGSize

  /// The distance from the text baseline to the bottom of the pill, in
  /// points. The value is negative, because the pill goes below the
  /// baseline.
  let baselineOffset: CGFloat

  /// Makes the sizes of the pill of a source.
  ///
  /// - Parameters:
  ///   - index: The one-based number of the source.
  ///   - textFontSize: The size of the text around the pill, in points.
  init(index: Int, textFontSize: CGFloat) {
    let digitFontSize = textFontSize * Self.fontScale
    let font = NSFont.monospacedDigitSystemFont(ofSize: digitFontSize, weight: Self.weight)
    let digitsWidth = (String(index) as NSString).size(withAttributes: [.font: font]).width
    let verticalPadding = digitFontSize * Self.verticalPaddingScale
    let height = (font.ascender - font.descender + verticalPadding * 2).rounded(.up)
    let width = (digitsWidth + digitFontSize * Self.horizontalPaddingScale * 2).rounded(.up)
    self.digitFontSize = digitFontSize
    self.size = CGSize(width: max(width, height), height: height)
    self.baselineOffset = font.descender - verticalPadding
  }
}

/// The look of a citation pill: the number of the source in a capsule.
///
/// The pill takes its size from the font of the environment. The view has no
/// accessibility element, because Textual draws it in a canvas. The caller
/// adds the element.
struct InlineCitationPill: View {
  /// The opacity of the accent color in the capsule.
  static let fillOpacity = 0.18

  /// The one-based number of the source.
  let index: Int

  @Environment(\.font) private var font
  @Environment(\.fontResolutionContext) private var fontResolutionContext
  @Environment(\.agentTheme) private var theme

  var body: some View {
    let textFontSize = (font ?? .body).resolve(in: fontResolutionContext).pointSize
    let metrics = InlineCitationMetrics(index: index, textFontSize: textFontSize)
    Text(verbatim: String(index))
      .font(.system(size: metrics.digitFontSize, weight: .semibold).monospacedDigit())
      .foregroundStyle(theme.accent)
      .lineLimit(1)
      .fixedSize()
      .frame(width: metrics.size.width, height: metrics.size.height)
      .background(Capsule().fill(theme.accent.opacity(Self.fillOpacity)))
  }
}
