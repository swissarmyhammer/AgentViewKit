import AppKit
import EditorStyle
import EditorSwiftUI
import EditorTheme
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
/// ``CitationPayload`` that it gets. There, Textual draws the pill, the pill
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
    accessibilityLabel(Text("Source \(index)", bundle: .module))
      .accessibilityHint(Text("Shows the source in the list of sources.", bundle: .module))
      .accessibilityIdentifier(InlineCitation.identifier(index: index))
  }
}

// MARK: - Pill

/// The padding of a citation pill, from the tokens of `\.editorStyle`.
///
/// Textual sizes an attachment outside the SwiftUI environment, so the pill
/// and the attachment carry this value. `EditorStyle` is not `Hashable`, and a
/// Textual attachment must be.
nonisolated struct InlineCitationPadding: Hashable, Sendable {
  /// The padding above and below the digits, as a part of their cap height:
  /// the ``ChipMetrics`` rule of a chip.
  let chipRatio: CGFloat

  /// The space at the left and at the right of the digits, in points. The
  /// chip tokens have no ratio for it, so it is a step of the spacing scale.
  let horizontal: CGFloat

  /// Reads the padding of a pill from a style.
  ///
  /// - Parameter style: The style of the text.
  init(style: EditorStyle) {
    chipRatio = style.chip.paddingRatio
    horizontal = style.spacing.xs
  }
}

/// The font and the sizes of a citation pill for one font size.
///
/// ``InlineCitationPill`` and the Textual attachment of a pill use the same
/// font and sizes, so that the pill fits the space that the text layout gives
/// it. The digits are chrome, so they draw in the `ui` face of the theme, and
/// the sizes come from that face. The height is the one chip rule
/// (``ChipMetrics``): the line height of the digits and the chip padding above
/// and below them.
nonisolated struct InlineCitationMetrics: Equatable, Sendable {
  /// The size of the pill digits, as a part of the text font size.
  static let fontScale: CGFloat = 0.75

  /// The weight of the digits.
  static let weight = Font.Weight.semibold

  /// The count of sides that get the horizontal padding: left and right.
  static let paddedSides: CGFloat = 2

  /// The font of the digits: the face of the pill at the digit size, at
  /// ``weight``, with digits of one width.
  let digitFont: Font

  /// The size of the pill, in points.
  let size: CGSize

  /// The distance from the text baseline to the bottom of the pill, in
  /// points. The value is negative, because the pill goes below the
  /// baseline.
  let baselineOffset: CGFloat

  /// Makes the font and the sizes of the pill of a source.
  ///
  /// - Parameters:
  ///   - index: The one-based number of the source.
  ///   - textFontSize: The size of the text around the pill, in points.
  ///   - face: The face of the digits: the `ui` face of the theme. The metrics
  ///     set its size.
  ///   - padding: The padding of the pill, from the style of the text.
  init(index: Int, textFontSize: CGFloat, face: FontFace, padding: InlineCitationPadding) {
    let digitFontSize = textFontSize * Self.fontScale
    var digitFace = face
    digitFace.size = digitFontSize
    let digitFont = digitFace.font().weight(Self.weight).monospacedDigit()
    // The face has a fixed size, so the font resolves to the same size in
    // each context, and the default context stands for the one of the text.
    let font = digitFont.resolve(in: EnvironmentValues().fontResolutionContext).ctFont as NSFont
    let digitsWidth = (String(index) as NSString).size(withAttributes: [.font: font]).width
    let chip = ChipMetrics(font: font, paddingRatio: padding.chipRatio)
    let height = chip.height.rounded(.up)
    let width = (digitsWidth + padding.horizontal * Self.paddedSides).rounded(.up)
    self.digitFont = digitFont
    self.size = CGSize(width: max(width, height), height: height)
    self.baselineOffset = font.descender - chip.padding
  }
}

/// The look of a citation pill: the number of the source in a capsule.
///
/// The capsule has a translucent fill of the theme accent, and the number has
/// the text color of the environment: the accent is not a text color.
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
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeAccent) private var themeAccent

  var body: some View {
    let textFontSize = (font ?? .body).resolve(in: fontResolutionContext).pointSize
    let metrics = InlineCitationMetrics(
      index: index, textFontSize: textFontSize, face: editorTheme.face(for: .ui),
      padding: InlineCitationPadding(style: editorStyle))
    return Text(verbatim: String(index))
      .font(metrics.digitFont)
      .lineLimit(1)
      .fixedSize()
      .frame(width: metrics.size.width, height: metrics.size.height)
      // The accent is only for the selection and the focus, so the digits keep
      // the text color of the environment. The accent fill of the citation chip
      // is the one exception (shared style rule 1, card ^y2mrfxt).
      .background(Capsule().fill(themeAccent.opacity(Self.fillOpacity)))
  }
}

#Preview("Inline citation") {
  HStack {
    Text(verbatim: PreviewFixtures.citedFirstSentence)
    InlineCitation(index: 1)
  }
}
