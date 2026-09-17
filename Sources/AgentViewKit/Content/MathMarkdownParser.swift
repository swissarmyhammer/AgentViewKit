import SwiftUI
import Textual
@_spi(Textual) import SwiftUIMath

/// The Markdown parser of the kit prose: Textual Markdown with each `$…$`
/// and `$$…$$` math span routed to ``MathView`` (plan.md §4.2, §11
/// decision 7).
///
/// The Textual `.math` syntax extension finds the spans after the Markdown
/// parse. At that time the parse has already removed the backslash of an
/// escape such as `\,` or `\\`, so the LaTeX source is wrong. Thus this
/// parser does these steps:
///
/// 1. ``MathSpanScanner`` finds the spans in the raw text.
/// 2. The parser puts a marker in place of each span, and Textual parses the
///    Markdown.
/// 3. The parser replaces each marker:
///    - When the engine can typeset the source, the marker becomes an
///      attachment that shows a ``MathView``.
///    - When the engine cannot typeset the source, the marker becomes the
///      source text, as inline code. Thus the paragraph shows the source and
///      never a blank.
///    - When the marker is in code, it becomes the span text with its
///      delimiters.
///
/// Docs/decisions/math-engine.md records this.
public struct MathMarkdownParser: MarkupParser {
  /// One math span of a Markdown text.
  public nonisolated struct Span: Hashable, Sendable {
    /// The LaTeX source, with no `$` delimiters.
    public let latex: String

    /// Whether the span is block math (`$$…$$`).
    public let display: Bool

    /// Makes a span.
    ///
    /// - Parameters:
    ///   - latex: The LaTeX source, with no `$` delimiters.
    ///   - display: Whether the span is block math.
    public init(latex: String, display: Bool) {
      self.latex = latex
      self.display = display
    }

    /// The delimiter of inline math.
    static let inlineDelimiter = "$"

    /// The delimiter of block math.
    static let blockDelimiter = "$$"

    /// The span with its delimiters.
    var delimitedSource: String {
      let delimiter = display ? Self.blockDelimiter : Self.inlineDelimiter
      return delimiter + latex + delimiter
    }
  }

  /// The character that starts a span marker. It is in the Unicode private
  /// use area, so Markdown text does not have it and the parse keeps it.
  nonisolated static let markerStart: Character = "\u{E000}"

  /// The character that ends a span marker.
  nonisolated static let markerEnd: Character = "\u{E001}"

  /// The span markers.
  nonisolated static let spanMarker = TextMarker(start: markerStart, end: markerEnd)

  /// The text that Textual shows in place of an attachment.
  static let attachmentCharacter = "\u{FFFC}"

  /// The Textual Markdown parser.
  private let base: AttributedStringMarkdownParser

  /// Makes the parser.
  ///
  /// - Parameter baseURL: The URL that resolves relative links and images.
  public init(baseURL: URL? = nil) {
    base = .markdown(baseURL: baseURL)
  }

  /// The marker of the span at `index`.
  ///
  /// - Parameter index: The position of the span in the list of spans.
  /// - Returns: The marker text.
  nonisolated static func marker(index: Int) -> String {
    spanMarker.marker(index)
  }

  public func attributedString(for input: String) throws -> AttributedString {
    try parse(input) { span, source, run in
      Self.replacement(for: span, source: source, isCode: run.isCode, attributes: run.attributes)
    }
  }

  /// The text that VoiceOver reads for a Markdown text with math
  /// (plan.md §6).
  ///
  /// Textual draws each math span in a canvas, so the text element of the
  /// paragraph does not read the math. This text has each span at its place
  /// in the text, as its LaTeX source.
  ///
  /// - Parameter input: The Markdown text.
  /// - Returns: The plain text with the LaTeX source of each span, or `nil`
  ///   when the text has no span that the engine can typeset or the parse
  ///   fails.
  public func spokenText(for input: String) -> String? {
    guard !mathSpans(in: input).isEmpty else { return nil }
    let spoken = try? parse(input) { span, source, run in
      AttributedString(run.isCode ? source : span.latex, attributes: run.attributes)
    }
    return spoken.map { String($0.characters) }
  }

  /// Parses `input` with a marker in place of each math span, then replaces
  /// each marker.
  ///
  /// - Parameters:
  ///   - input: The Markdown text.
  ///   - replace: The function that makes the text of one span from the
  ///     span, its source with delimiters, and the run of the marker.
  /// - Returns: The parsed text.
  private func parse(
    _ input: String,
    replacingSpansWith replace: (Span, String, MarkedRun) -> AttributedString
  ) throws -> AttributedString {
    let pieces = MathSpanScanner.pieces(in: input)
    var sources: [(span: Span, source: String)] = []
    var masked = ""
    for piece in pieces {
      switch piece {
      case .text(let text):
        masked += text
      case .math(let span, let source):
        masked += Self.marker(index: sources.count)
        sources.append((span, source))
      }
    }
    let parsed = try base.attributedString(for: masked)
    guard !sources.isEmpty else { return parsed }

    return Self.spanMarker.replacingMarkers(in: parsed) { index, run in
      guard sources.indices.contains(index) else {
        return AttributedString(Self.marker(index: index), attributes: run.attributes)
      }
      let (span, source) = sources[index]
      return replace(span, source, run)
    }
  }

  /// The math spans that the parser routes to ``MathView``, in text order.
  ///
  /// - Parameter input: The Markdown text.
  /// - Returns: One span for each expression that the engine can typeset.
  ///   The list has no span that is in code.
  public func mathSpans(in input: String) -> [Span] {
    MathSpanScanner.spans(in: input).filter {
      MathView.canTypeset($0.latex, display: $0.display)
    }
  }

  /// The attributed text that takes the place of one span marker.
  ///
  /// - Parameters:
  ///   - span: The span of the marker.
  ///   - source: The span as it is in the input, with its delimiters.
  ///   - isCode: Whether the marker is in code.
  ///   - attributes: The attributes of the run that holds the marker.
  /// - Returns: The replacement text.
  private static func replacement(
    for span: Span, source: String, isCode: Bool, attributes: AttributeContainer
  ) -> AttributedString {
    if isCode {
      return AttributedString(source, attributes: attributes)
    }
    var attributes = attributes
    if MathView.canTypeset(span.latex, display: span.display) {
      attributes.textual.attachment = AnyAttachment(MathSpanAttachment(span: span))
      return AttributedString(attachmentCharacter, attributes: attributes)
    }
    var intent = attributes.inlinePresentationIntent ?? []
    intent.insert(.code)
    attributes.inlinePresentationIntent = intent
    return AttributedString(span.latex, attributes: attributes)
  }
}

/// A Textual attachment that shows one math span in a ``MathView``.
///
/// Textual draws an attachment in a canvas. A canvas has no accessibility
/// children, so ``ParagraphView`` and the streaming tail add one element for
/// each span with ``MathSpanAccessibility``.
nonisolated struct MathSpanAttachment: Textual.Attachment {
  /// The span to show.
  let span: MathMarkdownParser.Span

  /// The span with its delimiters. Copy and selection use it.
  var description: String { span.delimitedSource }

  /// A selection of the span selects its source text.
  var selectionStyle: AttachmentSelectionStyle { .text }

  @MainActor var body: some View {
    MathView(latex: span.latex, display: span.display)
  }

  func baselineOffset(in environment: TextEnvironmentValues) -> CGFloat {
    -bounds(in: environment).descent
  }

  func sizeThatFits(_ proposal: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
    bounds(fitting: proposal, in: environment).size
  }

  /// The typographic bounds of the span at the font size of `environment`.
  ///
  /// - Parameters:
  ///   - proposal: The size that the layout proposes.
  ///   - environment: The text environment of the run.
  /// - Returns: The bounds.
  private func bounds(
    fitting proposal: ProposedViewSize = .unspecified,
    in environment: TextEnvironmentValues
  ) -> Math.TypographicBounds {
    MathView.bounds(
      of: span.latex,
      display: span.display,
      fontSize: FontScaled(MathView.fontScale).resolve(in: environment),
      fitting: proposal
    )
  }
}

/// One accessibility element for each math span of a text.
///
/// Textual draws the math of a paragraph in a canvas, which has no
/// accessibility children. Put this view in an overlay of the paragraph, so
/// that each span has an element with the ``MathView`` identifier and the
/// LaTeX source as its label. The view draws nothing.
struct MathSpanAccessibility: View {
  /// The spans of the text, in text order.
  let spans: [MathMarkdownParser.Span]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(spans.enumerated()), id: \.offset) { _, span in
        Color.clear
          .frame(width: 1, height: 1)
          .mathAccessibility(latex: span.latex, display: span.display)
      }
    }
  }
}
