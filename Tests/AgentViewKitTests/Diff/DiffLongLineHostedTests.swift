#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import SwiftUI
  import Testing

  /// Tests that a diff line longer than the view stays on one text row, so the
  /// text, the gutter and the line colors of the EditorKit renderer stand on
  /// the same rows (finding of ^8q34yt8).
  ///
  /// The gutter and the line colors of the EditorKit `DiffView` stand on one
  /// row for each line of the patch, one row height apart. So the text is
  /// aligned with them when each line lays out on exactly one line fragment,
  /// and line `n` starts `n` row heights below the first line.
  @Suite(.serialized, .hostedSerially) @MainActor struct DiffLongLineHostedTests {
    /// A size narrower than the long lines of ``PreviewFixtures/smallPatch``.
    static let size = CGSize(width: 480, height: 400)

    /// The largest difference that layout rounding makes between two edges, in
    /// points.
    static let layoutTolerance: CGFloat = 1

    /// The start of the long removed line of ``PreviewFixtures/smallPatch``.
    static let longLineStart = "func find("

    /// The text and the line fragment frames of one line of the diff text.
    struct LaidOutLine {
      /// The text of the line, with no line break.
      let text: String

      /// The frame of each line fragment of the line, in the coordinates of
      /// the text view.
      let fragments: [CGRect]
    }

    /// Makes a harness that shows the diff of ``PreviewFixtures/smallPatch``,
    /// after one render pass.
    ///
    /// - Returns: The harness.
    static func mountSmallPatch() -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: size) {
        DiffView(patch: PreviewFixtures.smallPatch)
          .transaction { $0.disablesAnimations = true }
      }
      harness.render()
      return harness
    }

    /// The root view of the EditorKit diff, and the text view under it.
    ///
    /// - Parameter harness: The harness that shows the diff.
    /// - Returns: The root view and its text view.
    static func diffViews(in harness: HostedViewHarness<some View>) throws -> (
      root: NSView, text: NSTextView
    ) {
      let root = try #require(
        harness.views(withAccessibilityIdentifier: EditorDiffIdentifier.root).first)
      let text = try #require(root.descendants.lazy.compactMap { $0 as? NSTextView }.first)
      return (root, text)
    }

    /// Each line of the text of `textView`, with the frames of its line
    /// fragments, in document order. The layout is made first, so the result
    /// needs no clock and no wait.
    ///
    /// - Parameter textView: A TextKit 2 text view.
    /// - Returns: The laid-out lines.
    static func laidOutLines(of textView: NSTextView) throws -> [LaidOutLine] {
      let manager = try #require(textView.textLayoutManager)
      manager.ensureLayout(for: manager.documentRange)
      var lines: [LaidOutLine] = []
      manager.enumerateTextLayoutFragments(
        from: manager.documentRange.location, options: [.ensuresLayout]
      ) { fragment in
        lines.append(laidOutLine(of: fragment, in: textView))
        return true
      }
      return lines
    }

    /// The text and the line fragment frames of `fragment`.
    ///
    /// - Parameters:
    ///   - fragment: A layout fragment of one line.
    ///   - textView: The text view that lays out `fragment`.
    /// - Returns: The laid-out line.
    static func laidOutLine(of fragment: NSTextLayoutFragment, in textView: NSTextView)
      -> LaidOutLine
    {
      let origin = fragment.layoutFragmentFrame.origin
      let containerOrigin = textView.textContainerOrigin
      let frames = fragment.textLineFragments.map {
        $0.typographicBounds.offsetBy(
          dx: origin.x + containerOrigin.x, dy: origin.y + containerOrigin.y)
      }
      let text = (fragment.textElement as? NSTextParagraph)?.attributedString.string ?? ""
      return LaidOutLine(text: text.trimmingCharacters(in: .newlines), fragments: frames)
    }

    // MARK: - One row for each line

    @Test func theLongLineLaysOutOnOneLineFragment() throws {
      let harness = Self.mountSmallPatch()
      defer { harness.close() }

      let views = try Self.diffViews(in: harness)
      let lines = try Self.laidOutLines(of: views.text)
      let longLine = try #require(lines.first { $0.text.contains(Self.longLineStart) })
      #expect(longLine.fragments.count == 1)
    }

    @Test func eachLineOfTheDiffLaysOutOnOneLineFragment() throws {
      let harness = Self.mountSmallPatch()
      defer { harness.close() }

      let views = try Self.diffViews(in: harness)
      let lines = try Self.laidOutLines(of: views.text)
      let hunkLineCount = 4
      #expect(lines.count >= hunkLineCount)
      for line in lines {
        #expect(line.fragments.count == 1, "\(line.text)")
      }
    }

    @Test func eachLineStartsOneRowBelowTheLineBeforeIt() throws {
      let harness = Self.mountSmallPatch()
      defer { harness.close() }

      let views = try Self.diffViews(in: harness)
      let fragments = try Self.laidOutLines(of: views.text).flatMap(\.fragments)
      let first = try #require(fragments.first)
      for (row, fragment) in fragments.enumerated() {
        let expectedTop = first.minY + CGFloat(row) * first.height
        #expect(abs(fragment.minY - expectedTop) <= Self.layoutTolerance, "row \(row)")
      }
    }

    @Test func theLastLineIsInsideTheVisibleBoundsOfTheDiff() throws {
      let harness = Self.mountSmallPatch()
      defer { harness.close() }

      let views = try Self.diffViews(in: harness)
      let lines = try Self.laidOutLines(of: views.text)
      let last = try #require(lines.last?.fragments.last)
      let lastInRoot = views.text.convert(last, to: views.root)
      let visible = views.root.visibleRect
      #expect(lastInRoot.minY >= visible.minY - Self.layoutTolerance)
      #expect(lastInRoot.maxY <= visible.maxY + Self.layoutTolerance)
    }
  }
#endif
